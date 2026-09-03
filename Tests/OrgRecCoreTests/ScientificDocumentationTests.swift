import Foundation
import XCTest

final class ScientificDocumentationTests: XCTestCase {
    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func read(_ relativePath: String) throws -> String {
        try String(
            contentsOf: repositoryRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    func testScientificMethodRegisterCoversPersistedAnalysisContracts() throws {
        let register = try read("Docs/SCIENTIFIC_METHODS.md")
        let requiredMethodIdentifiers = [
            "orgrec-analysis/4",
            "orgrec-pyin/1",
            "orgrec-autocorrelation/2",
            "orgrec-organ-long-take/3",
            "orgrec-perceptual-spectral-summary/1",
            "orgrec-harmonic-ltas/1",
            "orgrec-empirical-hierarchical-timbre-model/1",
            "orgrec-multivariate-segmented-rank-trajectory/1",
            "orgrec-acoustic-response-analysis/1",
            "orgrec.effect-analysis/v1",
            "orgrec.spatial-acoustic-observation/v1",
            "orgrec-collection-analysis/2",
            "orgrec.temperament-analysis/v1",
            "orgrec-loop-detector/1",
            "orgrec.signal-path-rehearsal/v1",
            "orgrec.interaction-sensor-calibration/v1-experimental",
            "orgrec.actuator-response-function/v1",
            "orgrec.tremulant-response-analysis/v1",
            "orgrec.operational-baseline-analysis/v1",
            "orgrec.documented-pitch/v1",
            "orgrec.tuning-calibration/v1",
            "orgrec.live-pitch-evidence/v1",
        ]

        for identifier in requiredMethodIdentifiers {
            XCTAssertTrue(
                register.contains("`\(identifier)`"),
                "Scientific method register is missing \(identifier)"
            )
        }
    }

    func testScientificMethodRegisterRetainsPrimarySourceIdentifiersAndBoundaries() throws {
        let register = try read("Docs/SCIENTIFIC_METHODS.md")
        let requiredSourceIdentifiers = [
            "10.1109/ICASSP.2018.8461329",
            "10.1121/1.1458024",
            "10.1109/ICASSP.2014.6853678",
            "10.1121/1.3642604",
            "10.1121/10.0005058",
            "10.1121/2.0001673",
            "10.61782/fa.2023.0327",
            "10.1121/2.0001671",
            "10.1121/2.0001672",
            "10.1051/aacus/2024020",
            "10.1214/aos/1176344136",
            "proceedings.mlr.press/v70/guo17a.html",
            "10.1121/1.1909343",
            "publications.rwth-aachen.de/record/192049",
            "10.1121/1.3518773",
            "10.1093/biomet/69.1.242",
            "10.1002/j.1538-7305.1948.tb01338.x",
            "iso.org/standard/40979.html",
            "iso.org/standard/36201.html",
            "webstore.iec.ch/en/publication/5063",
            "iso.org/standard/59766.html",
            "tech.ebu.ch/publications/tech3285",
            "aes.org/publications/standards/preview.cfm?ID=99",
            "midi.org/midi-1-0-detailed-specification",
        ]

        for identifier in requiredSourceIdentifiers {
            XCTAssertTrue(
                register.contains(identifier),
                "Scientific method register is missing source \(identifier)"
            )
        }

        XCTAssertTrue(register.contains("OrgRec synthesis"))
        XCTAssertTrue(register.contains("does not mean"))
        XCTAssertTrue(register.contains("conformal prediction coverage guarantee"))
        XCTAssertTrue(register.contains("not the exact Westfall–Young step-down algorithm"))
        XCTAssertFalse(register.contains("10.1121/10.0005549"), "Stale Kazazis DOI must not return")
        XCTAssertFalse(register.contains("10.1121/1.3531920"), "Stale Xiang DOI must not return")
    }

    func testMethodologyGuidesLinkToAuthoritativeRegister() throws {
        let guides = [
            "Docs/AUDIO_AND_SPECTRAL_ANALYSIS.md",
            "Docs/ADVANCED_ACOUSTIC_ANALYSIS.md",
            "Docs/LONG_TAKE_RECORDING.md",
            "Docs/TIMBRE_ANALYSIS.md",
            "Docs/COLLECTION_ACOUSTIC_DIAGNOSTICS.md",
            "Docs/TEMPERAMENT_INFERENCE.md",
            "Docs/LOOP_ANALYSIS_AND_SUSTAINED_PLAYBACK.md",
            "Docs/INTERACTION_SENSOR_EXPERIMENTAL.md",
            "Docs/SPATIAL_ACOUSTIC_P2.md",
            "Docs/COMPLEX_INSTRUMENT_CAPTURE_P1.md",
            "Docs/SIGNAL_PATH_REHEARSAL.md",
            "Docs/PROJECT_INITIALIZATION_AND_TUNING.md",
        ]

        for guide in guides {
            XCTAssertTrue(
                try read(guide).contains("SCIENTIFIC_METHODS.md"),
                "\(guide) does not link to the scientific method register"
            )
        }
    }
}
