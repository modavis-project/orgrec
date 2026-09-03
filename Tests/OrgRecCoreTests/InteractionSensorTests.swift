import XCTest
@testable import OrgRecCore

final class InteractionSensorTests: XCTestCase {
    func testPacketDecoderResynchronizesValidatesCRCAndHandlesSplitInput() {
        let sample = MPU6050RawSample(
            sequence: 42,
            timestampMicroseconds: 123_456,
            accelerometerX: 10,
            accelerometerY: -20,
            accelerometerZ: 8_192,
            temperatureRaw: 340,
            gyroscopeX: -123,
            gyroscopeY: 456,
            gyroscopeZ: -789,
            status: 0x13
        )
        let encoded = MPU6050PacketDecoder.encode(sample)
        XCTAssertEqual(encoded.count, MPU6050PacketDecoder.packetSize)

        var decoder = MPU6050PacketDecoder()
        var first = Data([0x00, 0xFE, 0xA5])
        first.append(encoded.prefix(8))
        XCTAssertTrue(decoder.feed(first).isEmpty)
        let decoded = decoder.feed(encoded.dropFirst(8))
        XCTAssertEqual(decoded, [sample])
        XCTAssertEqual(decoder.discardedByteCount, 3)

        var corrupted = encoded
        corrupted[18] ^= 0x40
        XCTAssertTrue(decoder.feed(corrupted).isEmpty)
        XCTAssertEqual(decoder.crcErrorCount, 1)
    }

    func testHingeCalibrationRecoversAxisBiasTravelAndGravityAngle() throws {
        let rate = 200.0
        let dt = 1 / rate
        let bias = SensorVector3(x: 0.55, y: -0.25, z: 0.12)
        let stationary = (0..<400).map { index in
            sample(
                index: index,
                timestamp: UInt64(index * 5_000),
                acceleration: SensorVector3(x: 0, y: 0, z: 1),
                gyro: bias + SensorVector3(x: sin(Double(index)) * 0.01, y: 0, z: 0)
            )
        }
        var movement: [InteractionSensorSample] = []
        for index in 0..<1_200 {
            let time = Double(index) * dt
            let phase = time.truncatingRemainder(dividingBy: 1.5) / 1.5
            let angle = 6 - 6 * cos(phase * 2 * .pi)
            let velocity = 6 * 2 * .pi / 1.5 * sin(phase * 2 * .pi)
            let radians = angle * .pi / 180
            movement.append(sample(
                index: index,
                timestamp: UInt64(index * 5_000),
                acceleration: SensorVector3(x: 0, y: sin(radians), z: cos(radians)),
                gyro: bias + SensorVector3(x: velocity, y: velocity * 0.01, z: 0)
            ))
        }

        let calibration = try XCTUnwrap(InteractionSensorProcessing.calibration(
            configurationID: UUID(), stationarySamples: stationary, movementSamples: movement
        ))
        XCTAssertEqual(calibration.gyroBiasDPS.x, bias.x, accuracy: 0.02)
        XCTAssertGreaterThan(abs(calibration.hingeAxisUnit.x), 0.99)
        XCTAssertGreaterThan(calibration.axisExplainedVariance ?? 0, 0.99)
        XCTAssertEqual(calibration.estimatedTravelDegrees ?? 0, 12, accuracy: 0.25)
        XCTAssertTrue(calibration.gravityIsObservable)
        let angle = InteractionSensorProcessing.signedGravityAngleDegrees(
            current: SensorVector3(x: 0, y: sin(10 * .pi / 180), z: cos(10 * .pi / 180)),
            neutral: calibration.neutralGravityUnit,
            axis: calibration.hingeAxisUnit
        )
        XCTAssertEqual(angle ?? 0, 10, accuracy: 0.1)
    }

    func testClockFitPreservesOffsetAndReportsIndependentClockDrift() throws {
        let audioStart: UInt64 = 8_000_000_000
        let firstDevice: UInt64 = 1_000_000
        let observations = (0..<10).map { index -> SensorClockObservation in
            let device = firstDevice + UInt64(index) * 1_000_000
            let elapsed = Double(index) * 1.000_1
            let host = audioStart + 250_000_000 + UInt64((elapsed * 1_000_000_000).rounded())
            return SensorClockObservation(deviceMicroseconds: device, hostNanoseconds: host)
        }
        let alignment = InteractionSensorProcessing.fitClock(
            observations: observations,
            audioStartHostNanoseconds: audioStart,
            nominalSampleRateHz: 200,
            serialBaudRate: 230_400
        )
        XCTAssertEqual(alignment.status, .fittedHostReceipts)
        let segment = try XCTUnwrap(alignment.segments.first)
        XCTAssertEqual(segment.driftPPM, 100, accuracy: 0.1)
        XCTAssertEqual(segment.audioSeconds(for: firstDevice), 0.25, accuracy: 0.000_001)
        XCTAssertGreaterThanOrEqual(alignment.baseUncertaintySeconds, 0.0025)
    }

    func testMIDIVelocityIsAcceptedOnlyAsASetupSpecificComparativePredictor() {
        let velocities = [20, 35, 50, 70, 90, 110]
        let trials = velocities.map { velocity in
            MIDIVelocityMotionTrial(
                midiNote: 60,
                midiVelocity: velocity,
                motionEventID: UUID(),
                motionStartToMIDISeconds: 0.025,
                peakAngularVelocityDPS: 2.5 * Double(velocity) + 12,
                travelDegrees: 10,
                durationSeconds: 0.2
            )
        }
        let evaluation = InteractionSensorProcessing.evaluateMIDIVelocity(trials)
        XCTAssertTrue(evaluation.suitableAsComparativePredictor)
        XCTAssertEqual(evaluation.rSquared ?? 0, 1, accuracy: 0.000_001)
        XCTAssertTrue(evaluation.conclusion.contains("does not establish absolute physical velocity"))

        let fixed = trials.map {
            MIDIVelocityMotionTrial(midiNote: 60, midiVelocity: 100, motionEventID: $0.motionEventID, motionStartToMIDISeconds: 0, peakAngularVelocityDPS: $0.peakAngularVelocityDPS, travelDegrees: 10, durationSeconds: 0.2)
        }
        XCTAssertFalse(InteractionSensorProcessing.evaluateMIDIVelocity(fixed).suitableAsComparativePredictor)
    }

    func testValidationRequiresIndependentPhysicalTrialsAndMeetsProvisionalGate() {
        let midiOnly = InteractionValidationTrial(
            motionEventID: UUID(), reference: .midiTimingOnly,
            measuredTravelDegrees: 10, referenceTravelDegrees: nil,
            measuredDurationSeconds: 0.2, referenceDurationSeconds: 0.2
        )
        XCTAssertFalse(InteractionSensorProcessing.summarizeValidation([midiOnly]).passedExperimentalGate)

        let trials = (0..<10).map { index in
            InteractionValidationTrial(
                motionEventID: UUID(), reference: .encoder,
                measuredTravelDegrees: 10 + (index.isMultiple(of: 2) ? 0.1 : -0.1),
                referenceTravelDegrees: 10,
                measuredDurationSeconds: 0.200 + (index.isMultiple(of: 2) ? 0.002 : -0.002),
                referenceDurationSeconds: 0.2
            )
        }
        let summary = InteractionSensorProcessing.summarizeValidation(trials)
        XCTAssertTrue(summary.passedExperimentalGate)
        XCTAssertEqual(summary.travelRMSEDegrees ?? 0, 0.1, accuracy: 0.000_001)
        XCTAssertEqual(summary.durationRMSESeconds ?? 0, 0.002, accuracy: 0.000_001)
    }

    func testPipeActionCouplingPreservesSignedOnsetAndReleaseTiming() throws {
        let activationID = UUID()
        let releaseID = UUID()
        let events = [
            InteractionMotionEvent(
                id: activationID,
                deviceStartMicroseconds: 1_000_000,
                deviceEndMicroseconds: 1_240_000,
                hostStartNanoseconds: 0,
                hostEndNanoseconds: 0,
                travelDegrees: 11.8,
                peakAngularVelocityDPS: 92,
                durationSeconds: 0.24,
                direction: 1,
                audioStartSeconds: 1.0,
                audioEndSeconds: 1.24
            ),
            InteractionMotionEvent(
                id: releaseID,
                deviceStartMicroseconds: 5_000_000,
                deviceEndMicroseconds: 5_190_000,
                hostStartNanoseconds: 0,
                hostEndNanoseconds: 0,
                travelDegrees: 11.7,
                peakAngularVelocityDPS: 105,
                durationSeconds: 0.19,
                direction: -1,
                audioStartSeconds: 5.0,
                audioEndSeconds: 5.19
            ),
        ]
        let coupling = try XCTUnwrap(InteractionSensorProcessing.coupleMotionToAudio(
            events: events,
            acousticOnsetSeconds: 1.18,
            acousticSoundOffsetSeconds: 7.6,
            operatorKeyUpSeconds: 5.02,
            timingUncertaintySeconds: 0.006
        ))
        XCTAssertEqual(coupling.activationMotionEventID, activationID)
        XCTAssertEqual(coupling.releaseMotionEventID, releaseID)
        XCTAssertEqual(coupling.onsetAfterMotionStartSeconds ?? 0, 0.18, accuracy: 0.000_001)
        XCTAssertEqual(coupling.onsetAfterMotionEndSeconds ?? 0, -0.06, accuracy: 0.000_001)
        XCTAssertEqual(coupling.heldIntervalSeconds ?? 0, 3.76, accuracy: 0.000_001)
        XCTAssertEqual(coupling.soundOffsetAfterReleaseStartSeconds ?? 0, 2.6, accuracy: 0.000_001)
        XCTAssertEqual(coupling.timingUncertaintySeconds, 0.006, accuracy: 0.000_001)
    }

    func testExperimentalConfigurationAndCalibrationRoundTrip() throws {
        var configuration = InteractionSensorConfiguration(
            name: "Swell shoe IMU",
            capturePolicy: .required,
            transport: .serial,
            portPath: "/dev/cu.usbmodem-test",
            targetComponentID: "swell",
            targetComponentLabel: "Swell shoe",
            useCase: .pedalOrContinuousControl,
            movementModel: .hinge
        )
        let calibration = InteractionSensorCalibration(
            configurationID: configuration.id,
            stationarySampleCount: 400,
            movementSampleCount: 800,
            gyroBiasDPS: .zero,
            gyroNoiseRMSDPS: 0.1,
            neutralGravityUnit: SensorVector3(x: 0, y: 0, z: 1),
            hingeAxisUnit: .unitX,
            estimatedTravelDegrees: 18,
            axisExplainedVariance: 0.99,
            gravityIsObservable: true,
            qualityScore: 0.95
        )
        configuration.currentCalibrationID = calibration.id
        let payload = try OrgRecCoding.encoder.encode([configuration])
        XCTAssertEqual(try OrgRecCoding.decoder.decode([InteractionSensorConfiguration].self, from: payload), [configuration])
        XCTAssertEqual(configuration.resolvedUseCase, .pedalOrContinuousControl)
        let decodedCalibration = try OrgRecCoding.decoder.decode(InteractionSensorCalibration.self, from: OrgRecCoding.encoder.encode(calibration))
        XCTAssertEqual(decodedCalibration.id, calibration.id)
        XCTAssertEqual(decodedCalibration.configurationID, calibration.configurationID)
        XCTAssertEqual(decodedCalibration.hingeAxisUnit, calibration.hingeAxisUnit)
        XCTAssertEqual(decodedCalibration.estimatedTravelDegrees, calibration.estimatedTravelDegrees)
        XCTAssertEqual(decodedCalibration.qualityScore, calibration.qualityScore)
    }

    private func sample(index: Int, timestamp: UInt64, acceleration: SensorVector3, gyro: SensorVector3) -> InteractionSensorSample {
        func raw(_ value: Double, scale: Double) -> Int16 {
            Int16(max(-32_000, min(32_000, (value * scale).rounded())))
        }
        let packet = MPU6050RawSample(
            sequence: UInt16(truncatingIfNeeded: index),
            timestampMicroseconds: UInt32(truncatingIfNeeded: timestamp),
            accelerometerX: raw(acceleration.x, scale: 8_192),
            accelerometerY: raw(acceleration.y, scale: 8_192),
            accelerometerZ: raw(acceleration.z, scale: 8_192),
            temperatureRaw: 0,
            gyroscopeX: raw(gyro.x, scale: 65.5),
            gyroscopeY: raw(gyro.y, scale: 65.5),
            gyroscopeZ: raw(gyro.z, scale: 65.5),
            status: 0x13
        )
        return InteractionSensorSample(raw: packet, unwrappedDeviceMicroseconds: timestamp, hostReceiptNanoseconds: 1_000_000_000 + timestamp * 1_000)
    }
}
