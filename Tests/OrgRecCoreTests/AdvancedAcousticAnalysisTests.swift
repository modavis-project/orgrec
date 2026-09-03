import Foundation
import XCTest
@testable import OrgRecCore

final class AdvancedAcousticAnalysisTests: XCTestCase {
    func testSchroederDecayRecoversKnownExponentialTime() throws {
        let sampleRate = 8_000.0
        let expectedRT = 1.8
        let samples = exponentialImpulseResponse(sampleRate: sampleRate, duration: 5, rt60: expectedRT)

        let result = try XCTUnwrap(AcousticResponseAnalyzer.analyze(
            samples: samples,
            sampleRate: sampleRate,
            qualification: .impulsiveSourceResponse,
            originSample: 0
        ))
        let t20 = try XCTUnwrap(result.broadband.t20)
        let t30 = try XCTUnwrap(result.broadband.t30)
        XCTAssertEqual(t20.extrapolatedDecayTimeSeconds, expectedRT, accuracy: 0.08)
        XCTAssertEqual(t30.extrapolatedDecayTimeSeconds, expectedRT, accuracy: 0.08)
        XCTAssertGreaterThan(t20.coefficientOfDetermination, 0.995)
        XCTAssertLessThan(t20.standardUncertaintySeconds ?? 1, 0.03)
        XCTAssertNotNil(result.broadband.clarity80DB)
        XCTAssertNotNil(result.standardReference)
        XCTAssertTrue(result.validationErrors.isEmpty)
    }

    func testObservedPipeReleaseCannotMasqueradeAsISOReverberationTime() throws {
        let samples = exponentialImpulseResponse(sampleRate: 8_000, duration: 4, rt60: 2.2)
        let result = try XCTUnwrap(AcousticResponseAnalyzer.analyze(
            samples: samples,
            sampleRate: 8_000,
            qualification: .observedInstrumentRelease,
            originSample: 0
        ))
        XCTAssertNil(result.standardReference)
        XCTAssertNil(result.broadband.clarity50DB)
        XCTAssertNil(result.broadband.clarity80DB)
        XCTAssertNil(result.broadband.definition50)
        XCTAssertNil(result.broadband.directToReverberantRatioDB)
        XCTAssertTrue(result.conformanceStatement.contains("no ISO 3382"))
        XCTAssertTrue(result.validationErrors.isEmpty)
    }

    func testBICDetectsCoupledVolumeMultiSlopeDecay() throws {
        let sampleRate = 4_000.0
        let samples = multiSlopeImpulseResponse(
            sampleRate: sampleRate,
            duration: 8,
            earlyRT60: 0.75,
            lateRT60: 3.4,
            lateEnergyFraction: 0.035
        )
        let result = try XCTUnwrap(AcousticResponseAnalyzer.analyze(
            samples: samples,
            sampleRate: sampleRate,
            qualification: .deconvolvedImpulseResponse,
            originSample: 0
        ))
        let multi = try XCTUnwrap(result.broadband.multiSlope)
        XCTAssertGreaterThan(multi.deltaBIC, 10)
        XCTAssertGreaterThan(multi.lateDecayTimeSeconds, multi.earlyDecayTimeSeconds * 1.5)
        XCTAssertGreaterThan(multi.transitionTimeSeconds, 0)
        XCTAssertTrue(result.warnings.contains { $0.contains("multiple decay slopes") })
    }

    func testInsufficientDynamicRangeDoesNotInventT30() throws {
        let sampleRate = 8_000.0
        var samples = exponentialImpulseResponse(sampleRate: sampleRate, duration: 1, rt60: 4)
        for index in samples.indices {
            let noise = Float(((index * 7_919) % 997) - 498) / 498 * 0.02
            samples[index] += noise
        }
        let result = try XCTUnwrap(AcousticResponseAnalyzer.analyze(
            samples: samples,
            sampleRate: sampleRate,
            qualification: .impulsiveSourceResponse,
            originSample: 0
        ))
        XCTAssertLessThan(result.broadband.usableDecayRangeDB, 35)
        XCTAssertNil(result.broadband.t30)
    }

    func testHarmonicSpectrumProducesTonalAndTristimulusEvidence() throws {
        let rate = 24_000.0
        let samples = harmonicTone(sampleRate: rate, duration: 4, fundamental: 220, harmonicCount: 12)
        let result = try XCTUnwrap(PerceptualSpectralAnalyzer.analyze(
            samples: samples,
            sampleRate: rate,
            fundamentalFrequency: 220
        ))
        XCTAssertGreaterThan(result.harmonicEnergyRatio ?? 0, 0.75)
        XCTAssertLessThan(result.spectralFlatness ?? 1, 0.15)
        XCTAssertLessThan(result.auditoryFlatness ?? 1, 0.65)
        let sum = try XCTUnwrap(result.tristimulus1) + (result.tristimulus2 ?? 0) + (result.tristimulus3 ?? 0)
        XCTAssertEqual(sum, 1, accuracy: 0.000_001)
        XCTAssertLessThan(result.harmonicSpectralSlopeDBPerOctave ?? 0, 0)
        XCTAssertTrue(result.validationErrors.isEmpty)
    }

    func testNoiseIsFlatterAndLessHarmonicThanPipeTone() throws {
        let rate = 24_000.0
        let tone = try XCTUnwrap(PerceptualSpectralAnalyzer.analyze(
            samples: harmonicTone(sampleRate: rate, duration: 3, fundamental: 220, harmonicCount: 10),
            sampleRate: rate,
            fundamentalFrequency: 220
        ))
        let noise = try XCTUnwrap(PerceptualSpectralAnalyzer.analyze(
            samples: deterministicNoise(count: Int(rate * 3)),
            sampleRate: rate,
            fundamentalFrequency: 220
        ))
        XCTAssertGreaterThan(noise.spectralFlatness ?? 0, tone.spectralFlatness ?? 1)
        XCTAssertGreaterThan(noise.spectralEntropy ?? 0, tone.spectralEntropy ?? 1)
        XCTAssertLessThan(noise.harmonicEnergyRatio ?? 1, tone.harmonicEnergyRatio ?? 0)
    }

    func testClosePairBeatRateIsRecovered() throws {
        let rate = 24_000.0
        let samples = (0..<Int(rate * 6)).map { index -> Float in
            let time = Double(index) / rate
            return Float(0.28 * sin(2 * .pi * 440 * time) + 0.28 * sin(2 * .pi * 442 * time))
        }
        let result = try XCTUnwrap(PerceptualSpectralAnalyzer.analyze(
            samples: samples,
            sampleRate: rate,
            fundamentalFrequency: 441
        ))
        XCTAssertEqual(try XCTUnwrap(result.amplitudeModulationRateHz), 2, accuracy: 0.15)
        XCTAssertGreaterThan(result.amplitudeModulationDepthDB ?? 0, 6)
        XCTAssertGreaterThan(result.amplitudeModulationConfidence ?? 0, 0.1)
    }

    func testPeriodicBrightnessChangeIsRecoveredSeparatelyFromAmplitude() throws {
        let rate = 24_000.0
        let samples = (0..<Int(rate * 7)).map { index -> Float in
            let time = Double(index) / rate
            let upperAmplitude = 0.16 + 0.12 * sin(2 * .pi * 3 * time)
            return Float(0.28 * sin(2 * .pi * 220 * time) + upperAmplitude * sin(2 * .pi * 1_760 * time))
        }
        let result = try XCTUnwrap(PerceptualSpectralAnalyzer.analyze(
            samples: samples,
            sampleRate: rate,
            fundamentalFrequency: 220
        ))
        XCTAssertEqual(try XCTUnwrap(result.spectralCentroidModulationRateHz), 3, accuracy: 0.18)
        XCTAssertGreaterThan(result.spectralCentroidModulationDepthERB ?? 0, 0.1)
        XCTAssertGreaterThan(result.spectralCentroidModulationConfidence ?? 0, 0.1)
    }

    func testLegacyAnalysisSummaryWithoutNewEvidenceStillDecodes() throws {
        let original = AnalysisSummary(method: "legacy", algorithmVersion: "orgrec-analysis/3")
        let encoded = try JSONEncoder().encode(original)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "perceptualSpectralSummary")
        object.removeValue(forKey: "acousticResponseAnalysis")
        let legacy = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(AnalysisSummary.self, from: legacy)
        XCTAssertNil(decoded.perceptualSpectralSummary)
        XCTAssertNil(decoded.acousticResponseAnalysis)
    }

    func testValidationRejectsFalseStandardClaimOnObservedRelease() throws {
        let samples = exponentialImpulseResponse(sampleRate: 8_000, duration: 3, rt60: 1.5)
        var result = try XCTUnwrap(AcousticResponseAnalyzer.analyze(
            samples: samples,
            sampleRate: 8_000,
            qualification: .observedInstrumentRelease,
            originSample: 0
        ))
        result.standardReference = "ISO 3382"
        XCTAssertTrue(result.validationErrors.contains { $0.contains("must not claim") })
    }

    private func exponentialImpulseResponse(sampleRate: Double, duration: Double, rt60: Double) -> [Float] {
        let amplitudeRate = 3 * log(10.0) / rt60
        return (0..<Int(sampleRate * duration)).map { index in
            let time = Double(index) / sampleRate
            return Float(exp(-amplitudeRate * time))
        }
    }

    /// Constructs samples whose backward-integrated squared values follow the
    /// requested sum of exponential energy decays exactly (apart from the last
    /// residual sample), avoiding stochastic fixture tolerance.
    private func multiSlopeImpulseResponse(
        sampleRate: Double,
        duration: Double,
        earlyRT60: Double,
        lateRT60: Double,
        lateEnergyFraction: Double
    ) -> [Float] {
        let count = Int(sampleRate * duration)
        func energy(_ index: Int) -> Double {
            let time = Double(index) / sampleRate
            let early = (1 - lateEnergyFraction) * exp(-6 * log(10.0) * time / earlyRT60)
            let late = lateEnergyFraction * exp(-6 * log(10.0) * time / lateRT60)
            return early + late
        }
        return (0..<count).map { index in
            let current = energy(index)
            let next = index + 1 < count ? energy(index + 1) : 0
            let amplitude = sqrt(max(0, current - next))
            return Float(index.isMultiple(of: 2) ? amplitude : -amplitude)
        }
    }

    private func harmonicTone(sampleRate: Double, duration: Double, fundamental: Double, harmonicCount: Int) -> [Float] {
        (0..<Int(sampleRate * duration)).map { index in
            let time = Double(index) / sampleRate
            let value = (1...harmonicCount).reduce(0.0) { result, harmonic in
                result + 0.22 / Double(harmonic) * sin(2 * .pi * fundamental * Double(harmonic) * time)
            }
            return Float(value)
        }
    }

    private func deterministicNoise(count: Int) -> [Float] {
        var state: UInt64 = 0x9E3779B97F4A7C15
        return (0..<count).map { _ in
            state = state &* 6_364_136_223_846_793_005 &+ 1
            let value = Double((state >> 33) & 0x7FFF_FFFF) / Double(0x7FFF_FFFF)
            return Float((value * 2 - 1) * 0.3)
        }
    }
}
