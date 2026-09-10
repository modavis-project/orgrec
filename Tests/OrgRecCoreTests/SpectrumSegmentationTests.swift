import AVFoundation
import Foundation
import XCTest
@testable import OrgRecCore

final class SpectrumSegmentationTests: XCTestCase {
    func testShortSustainNeverExpandsPastEarliestRelease() {
        let region = SpectrumSegmentation.steadyRegion(
            duration: 2, sustainStart: 0.3, soundOffset: 0.6, keyUp: 0.55
        )
        XCTAssertEqual(region.start, 0.3)
        XCTAssertEqual(region.end, 0.45, accuracy: 1e-12)
        XCTAssertTrue(region.limitations.contains { $0.contains("Less than two seconds") })
        let inconsistent = SpectrumSegmentation.steadyRegion(
            duration: 2, sustainStart: 0.5, soundOffset: 0.3, keyUp: nil
        )
        XCTAssertEqual(inconsistent.duration, 0)
    }

    func testMissingBoundariesAreProvisionalAndDurationIsCapped() {
        let missing = SpectrumSegmentation.steadyRegion(
            duration: 30, sustainStart: nil, soundOffset: nil, keyUp: nil
        )
        XCTAssertEqual(missing.duration, 10)
        XCTAssertEqual(missing.limitations.count, 2)
        let observed = SpectrumSegmentation.steadyRegion(
            duration: 30, sustainStart: 0.4, soundOffset: 25, keyUp: 24
        )
        XCTAssertEqual(observed.duration, 10)
        XCTAssertTrue(observed.limitations.isEmpty)
        let beyondSource = SpectrumSegmentation.steadyRegion(
            duration: 3, sustainStart: 0.4, soundOffset: 5, keyUp: nil
        )
        XCTAssertEqual(beyondSource.end, 3)
        XCTAssertFalse(beyondSource.limitations.isEmpty)
    }

    func testInvalidRegionInputsCannotProduceInvalidExtents() {
        for duration in [Double.nan, .infinity, -1, 0] {
            let region = SpectrumSegmentation.steadyRegion(
                duration: duration, sustainStart: nil, soundOffset: nil, keyUp: nil
            )
            XCTAssertEqual(region.duration, 0)
            XCTAssertFalse(region.limitations.isEmpty)
        }
    }

    func testHarmonicBinsHaveUniqueOwnershipEvenWithWideSearches() throws {
        for fundamental in [100.0, 103.7, 440.0] {
            var used = Set<Int>()
            for harmonic in 1...64 {
                let bins = try XCTUnwrap(SpectrumSegmentation.harmonicBins(
                    harmonic: harmonic, fundamental: fundamental, binWidth: 5,
                    toleranceHz: Double(harmonic) * fundamental * 0.1,
                    lowerBin: 1, upperBin: 10_000
                ))
                XCTAssertTrue(used.isDisjoint(with: bins), "Shared bins at harmonic \(harmonic)")
                used.formUnion(bins)
            }
        }
        // The exact midpoint belongs to the higher harmonic only.
        let first = SpectrumSegmentation.harmonicBins(harmonic: 1, fundamental: 100,
            binWidth: 10, toleranceHz: 100, lowerBin: 1, upperBin: 100)
        let second = SpectrumSegmentation.harmonicBins(harmonic: 2, fundamental: 100,
            binWidth: 10, toleranceHz: 100, lowerBin: 1, upperBin: 100)
        XCTAssertEqual(first, 5...14)
        XCTAssertEqual(second, 15...24)
        XCTAssertNil(SpectrumSegmentation.harmonicBins(harmonic: 1, fundamental: 15,
            binWidth: 10, toleranceHz: 20, lowerBin: 1, upperBin: 100))
        XCTAssertNil(SpectrumSegmentation.harmonicBins(harmonic: 64, fundamental: .greatestFiniteMagnitude,
            binWidth: 10, toleranceHz: 20, lowerBin: 1, upperBin: 100))
    }

    func testShortTimbreRegionExcludesDifferentReleaseTails() async throws {
        let rate = 48_000.0
        let base = tone(rate: rate, duration: 2, fundamental: 220, harmonics: 8)
        var changed = base
        for index in Int(0.55 * rate)..<changed.count {
            changed[index] = Float(0.8 * sin(2 * .pi * 3_700 * Double(index) / rate))
        }
        let firstURL = try write(base, rate: rate)
        let secondURL = try write(changed, rate: rate)
        defer { try? FileManager.default.removeItem(at: firstURL); try? FileManager.default.removeItem(at: secondURL) }
        let engine = TimbreAnalysisEngine()
        let first = try await engine.analyze(input: timbreInput(firstURL, frequency: 220, start: 0.3, release: 0.55), mode: .characterization)
        let second = try await engine.analyze(input: timbreInput(secondURL, frequency: 220, start: 0.3, release: 0.55), mode: .characterization)
        XCTAssertEqual(first.segmentEndSeconds, 0.45, accuracy: 1e-12)
        XCTAssertEqual(first.applicability, .limited)
        XCTAssertEqual(first.partials, second.partials)
        XCTAssertEqual(first.normalizedSpectralCentroid, second.normalizedSpectralCentroid)
    }

    func testIntegratedHarmonicPowerIsStableAcrossFFTBinPhases() async throws {
        let rate = 48_000.0
        // These frequencies span an FFT-bin center and offsets up to half a bin.
        for frequency in [220.0, 222.0, 222.65625, 224.0] {
            let url = try write(tone(rate: rate, duration: 3, fundamental: frequency, harmonics: 8), rate: rate)
            defer { try? FileManager.default.removeItem(at: url) }
            let result = try await TimbreAnalysisEngine().analyze(
                input: timbreInput(url, frequency: frequency, start: 0.2, release: 2.9), mode: .characterization
            )
            for harmonic in 1...8 {
                let partial = try XCTUnwrap(result.partials.first { $0.harmonicNumber == harmonic })
                XCTAssertEqual(partial.relativeLevelDB, -20 * log10(Double(harmonic)), accuracy: 0.12,
                    "Harmonic \(harmonic), f0=\(frequency)")
            }
        }
    }

    func testContinuousToneSurvivesWithoutQuietFramesAndDisplayDoesNotChangeEvidence() async throws {
        let rate = 8_000.0
        let url = try write(tone(rate: rate, duration: 3, fundamental: 440, harmonics: 4), rate: rate)
        defer { try? FileManager.default.removeItem(at: url) }
        let analyzer = AudioAnalyzer(crepe: CREPEPitchEstimator(modelURL: nil))
        var configuration = SpectrogramConfiguration(fftSize: 2_048, hopSize: 64,
            maximumFrequencyHz: 3_900, maximumTimeBins: 10, partialCount: 6)
        let sparse = try await analyzer.analyze(fileURL: url, expectedFrequency: 440, spectrogramConfiguration: configuration)
        configuration.maximumTimeBins = 1_200
        let dense = try await analyzer.analyze(fileURL: url, expectedFrequency: 440, spectrogramConfiguration: configuration)
        let fundamental = try XCTUnwrap(sparse.2.partialTracks?.first { $0.harmonicNumber == 1 })
        XCTAssertGreaterThan(fundamental.validPointRatio ?? 0, 0.95)
        XCTAssertEqual(try XCTUnwrap(fundamental.medianFrequencyHz), 440, accuracy: 1)
        XCTAssertNil(fundamental.noiseFloorDB)
        XCTAssertNil(fundamental.decayRateDBPerSecond)
        XCTAssertEqual(sparse.2.partialTracks, dense.2.partialTracks)
        XCTAssertEqual(sparse.0.spectralSummary, dense.0.spectralSummary)
        XCTAssertLessThanOrEqual(sparse.2.timeBins, 10)
        XCTAssertGreaterThan(dense.2.timeBins, sparse.2.timeBins)
        XCTAssertEqual(sparse.2.analysisRun?.parameterSHA256, dense.2.analysisRun?.parameterSHA256)
        XCTAssertEqual(sparse.2.analysisRun?.parameters["spectrumSegmentation"], SpectrumSegmentation.version)
    }

    func testLowSampleRateBoundariesUseActualHopAndSilenceHasNoPhases() async throws {
        let rate = 4_000.0
        var samples = tone(rate: rate, duration: 2, fundamental: 220, harmonics: 4)
        for index in samples.indices where index < 2_000 || index >= 5_000 { samples[index] = 0 }
        let signalURL = try write(samples, rate: rate)
        let silenceURL = try write([Float](repeating: 0, count: samples.count), rate: rate)
        defer { try? FileManager.default.removeItem(at: signalURL); try? FileManager.default.removeItem(at: silenceURL) }
        let analyzer = AudioAnalyzer(crepe: CREPEPitchEstimator(modelURL: nil))
        let configuration = SpectrogramConfiguration(fftSize: 1_024, partialCount: 4)
        let signal = try await analyzer.analyze(fileURL: signalURL, expectedFrequency: 220,
            spectrogramConfiguration: configuration, pitchApplicability: .polyphonic)
        XCTAssertEqual(try XCTUnwrap(signal.0.onsetSeconds), 0.5, accuracy: 0.04)
        let onset = try XCTUnwrap(signal.0.boundaries?.first { $0.marker == .onset })
        XCTAssertEqual(try XCTUnwrap(onset.timeResolutionSeconds), 64 / rate, accuracy: 1e-12)
        let silence = try await analyzer.analyze(fileURL: silenceURL, expectedFrequency: 220,
            spectrogramConfiguration: configuration, pitchApplicability: .polyphonic)
        XCTAssertNil(silence.0.onsetSeconds)
        XCTAssertNil(silence.0.soundOffsetSeconds)
        XCTAssertNil(silence.0.perceptualSpectralSummary)
        XCTAssertTrue(silence.2.partialTracks?.allSatisfy { ($0.validPointRatio ?? 0) == 0 } == true)
    }

    func testLongSourceUsesBoundedExtractionWithExplicitPointSpacing() async throws {
        let rate = 8_000.0
        let url = try write(tone(rate: rate, duration: 9, fundamental: 440, harmonics: 3), rate: rate)
        defer { try? FileManager.default.removeItem(at: url) }
        let configuration = SpectrogramConfiguration(fftSize: 1_024, hopSize: 32,
            maximumTimeBins: 10_000, partialCount: 3)
        let result = try await AudioAnalyzer(crepe: CREPEPitchEstimator(modelURL: nil)).analyze(
            fileURL: url, expectedFrequency: 440, spectrogramConfiguration: configuration, pitchApplicability: .polyphonic
        )
        let points = try XCTUnwrap(result.2.partialTracks?.first?.points)
        XCTAssertGreaterThan(points.count, 1_000)
        XCTAssertLessThanOrEqual(points.count, 2_048)
        for index in 1..<points.count {
            XCTAssertEqual(points[index].timeSeconds - points[index - 1].timeSeconds, 64 / rate, accuracy: 1e-12)
        }
        XCTAssertEqual(try XCTUnwrap(result.2.timeStepSeconds), 64 / rate, accuracy: 1e-12)
        XCTAssertGreaterThan(try XCTUnwrap(points.last?.timeSeconds), 8.8)
    }

    func testSilenceAndUnresolvableHarmonicsHaveNoInventedPartition() throws {
        XCTAssertNil(PerceptualSpectralAnalyzer.analyze(samples: [Float](repeating: 0, count: 8_192),
            sampleRate: 48_000, fundamentalFrequency: 220))
        let unresolved = try XCTUnwrap(PerceptualSpectralAnalyzer.analyze(
            samples: tone(rate: 48_000, duration: 0.025, fundamental: 30, harmonics: 8),
            sampleRate: 48_000, fundamentalFrequency: 30
        ))
        XCTAssertNil(unresolved.tristimulus1)
        XCTAssertNil(unresolved.tristimulus2)
        XCTAssertNil(unresolved.tristimulus3)
        XCTAssertNil(unresolved.harmonicEnergyRatio)
        XCTAssertTrue(unresolved.limitations.contains { $0.contains("frequency resolution") })
    }

    private func tone(rate: Double, duration: Double, fundamental: Double, harmonics: Int) -> [Float] {
        (0..<Int(rate * duration)).map { index in
            let phase = 2 * Double.pi * fundamental * Double(index) / rate
            return Float((1...harmonics).reduce(0.0) { $0 + 0.2 / Double($1) * sin(phase * Double($1)) })
        }
    }

    private func write(_ samples: [Float], rate: Double) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("orgrec-spectrum-\(UUID().uuidString).wav")
        // AVAudioFile's writer coerces rates below 8 kHz. Write IEEE-float WAVE
        // bytes directly so the fixture really exercises the declared clock.
        var data = Data()
        func ascii(_ value: String) { data.append(contentsOf: value.utf8) }
        func u16(_ value: UInt16) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }
        func u32(_ value: UInt32) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }
        ascii("RIFF"); u32(UInt32(36 + samples.count * 4)); ascii("WAVEfmt ")
        u32(16); u16(3); u16(1); u32(UInt32(rate)); u32(UInt32(rate) * 4); u16(4); u16(32)
        ascii("data"); u32(UInt32(samples.count * 4))
        for sample in samples { u32(sample.bitPattern) }
        try data.write(to: url)
        XCTAssertEqual(try AVAudioFile(forReading: url).processingFormat.sampleRate, rate)
        return url
    }

    private func timbreInput(_ url: URL, frequency: Double, start: Double, release: Double) -> TimbreAnalysisInput {
        TimbreAnalysisInput(fileURL: url, takeID: UUID(), roadmapItemID: UUID(), midiNote: 57, noteName: "A3",
            expectedFrequencyHz: frequency, measuredFrequencyHz: frequency, measuredConfidence: 0.99,
            sourceAudioSHA256: nil, sourceAnalysisRunID: nil, referenceChannel: 0,
            sustainStartSeconds: start, soundOffsetSeconds: release + 0.05, keyUpSeconds: release)
    }
}
