import Foundation

public enum AnalysisSoundPhase: String, CaseIterable, Sendable {
    case attack
    case sustain
    case release
    case tail
}

public struct AnalysisPhaseInterval: Hashable, Identifiable, Sendable {
    public var id: AnalysisSoundPhase { phase }
    public var phase: AnalysisSoundPhase
    public var startSeconds: Double
    public var endSeconds: Double
}

public enum AnalysisBoundarySequence {
    public static func isChronological(_ values: [AnalysisMarkerKind: Double]) -> Bool {
        let ordered = AnalysisMarkerKind.allCases.compactMap { values[$0] }
        return zip(ordered, ordered.dropFirst()).allSatisfy { $0 <= $1 }
    }

    public static func phases(_ values: [AnalysisMarkerKind: Double]) -> [AnalysisPhaseInterval] {
        func interval(_ phase: AnalysisSoundPhase, _ start: Double?, _ end: Double?) -> AnalysisPhaseInterval? {
            guard let start, let end, start >= 0, end > start else { return nil }
            return AnalysisPhaseInterval(phase: phase, startSeconds: start, endSeconds: end)
        }
        return [
            interval(.attack, values[.onset], values[.sustainStart]),
            interval(.sustain, values[.sustainStart], values[.keyUp] ?? values[.soundOffset]),
            interval(.release, values[.keyUp], values[.soundOffset]),
            interval(.tail, values[.soundOffset], values[.tailEnd]),
        ].compactMap { $0 }
    }
}

/// A bounded time window shared by analysis visualizations. The value is kept
/// independent of pixels so waveform, pitch, and spectral views cannot drift
/// onto subtly different time scales.
public struct AnalysisTimeViewport: Hashable, Sendable {
    public var startSeconds: Double
    public var endSeconds: Double

    public init(startSeconds: Double, endSeconds: Double) {
        let start = startSeconds.isFinite ? max(0, startSeconds) : 0
        let end = endSeconds.isFinite ? max(start, endSeconds) : start
        self.startSeconds = start
        self.endSeconds = end
    }

    public static func full(duration: Double) -> AnalysisTimeViewport {
        AnalysisTimeViewport(startSeconds: 0, endSeconds: max(0.001, duration))
    }

    public var duration: Double { max(0.001, endSeconds - startSeconds) }

    public func time(atNormalizedX normalizedX: Double) -> Double {
        startSeconds + min(1, max(0, normalizedX)) * duration
    }

    public func normalizedX(for timeSeconds: Double) -> Double {
        (timeSeconds - startSeconds) / duration
    }

    /// Factor greater than one zooms in; less than one zooms out.
    public func zoomed(
        by factor: Double,
        anchorNormalizedX: Double = 0.5,
        totalDuration: Double,
        minimumDuration: Double = 0.05
    ) -> AnalysisTimeViewport {
        let total = max(0.001, totalDuration)
        let safeFactor = factor.isFinite ? max(0.05, factor) : 1
        let newDuration = min(total, max(minimumDuration, duration / safeFactor))
        let anchor = min(1, max(0, anchorNormalizedX))
        let anchorTime = time(atNormalizedX: anchor)
        var start = anchorTime - newDuration * anchor
        start = min(max(0, start), max(0, total - newDuration))
        return AnalysisTimeViewport(startSeconds: start, endSeconds: start + newDuration)
    }

    public func panned(bySeconds delta: Double, totalDuration: Double) -> AnalysisTimeViewport {
        let total = max(0.001, totalDuration)
        let span = min(duration, total)
        let proposed = startSeconds + (delta.isFinite ? delta : 0)
        let start = min(max(0, proposed), max(0, total - span))
        return AnalysisTimeViewport(startSeconds: start, endSeconds: start + span)
    }
}

/// Exact evidence under a spectrogram cursor. Magnitudes are relative to the
/// global peak of the rendered analysis derivative, not calibrated SPL.
public struct SpectrogramInspection: Hashable, Sendable {
    public var timeSeconds: Double
    public var frequencyHz: Double
    public var relativeMagnitudeDB: Double
    public var timeBin: Int
    public var frequencyBin: Int
    public var nearestPartialHarmonic: Int?
    public var nearestPartialFrequencyHz: Double?
    public var nearestPartialSignalToNoiseDB: Double?
    public var nearestPartialIsValid: Bool?

    public init(
        timeSeconds: Double,
        frequencyHz: Double,
        relativeMagnitudeDB: Double,
        timeBin: Int,
        frequencyBin: Int,
        nearestPartialHarmonic: Int? = nil,
        nearestPartialFrequencyHz: Double? = nil,
        nearestPartialSignalToNoiseDB: Double? = nil,
        nearestPartialIsValid: Bool? = nil
    ) {
        self.timeSeconds = timeSeconds
        self.frequencyHz = frequencyHz
        self.relativeMagnitudeDB = relativeMagnitudeDB
        self.timeBin = timeBin
        self.frequencyBin = frequencyBin
        self.nearestPartialHarmonic = nearestPartialHarmonic
        self.nearestPartialFrequencyHz = nearestPartialFrequencyHz
        self.nearestPartialSignalToNoiseDB = nearestPartialSignalToNoiseDB
        self.nearestPartialIsValid = nearestPartialIsValid
    }
}

public enum SpectrogramInspector {
    public static func inspect(
        data: SpectrogramData,
        normalizedX: Double,
        normalizedY: Double,
        viewport: AnalysisTimeViewport
    ) -> SpectrogramInspection? {
        guard data.timeBins > 0, data.frequencyBins > 0,
              data.magnitudes.isEmpty == false else { return nil }
        let x = min(1, max(0, normalizedX))
        let y = min(1, max(0, normalizedY))
        let timeStep = max(0.000_001, data.timeStepSeconds ?? 1)
        let time = viewport.time(atNormalizedX: x)
        let timeBin = min(data.timeBins - 1, max(0, Int((time / timeStep).rounded())))
        let frequencyBin = min(data.frequencyBins - 1, max(0, Int(((1 - y) * Double(data.frequencyBins - 1)).rounded())))
        guard data.magnitudes.indices.contains(timeBin),
              data.magnitudes[timeBin].indices.contains(frequencyBin) else { return nil }
        let frequency: Double
        if let axis = data.frequencyAxisHz, axis.indices.contains(frequencyBin) {
            frequency = axis[frequencyBin]
        } else {
            frequency = Double(frequencyBin) / Double(max(1, data.frequencyBins - 1)) * data.maximumFrequency
        }

        let nearest = nearestPartial(
            tracks: data.partialTracks ?? [],
            time: time,
            frequency: frequency,
            timeTolerance: max(timeStep * 1.6, 0.01),
            centsTolerance: max(30, data.configuration?.partialSearchCents ?? 50)
        )
        return SpectrogramInspection(
            timeSeconds: time,
            frequencyHz: frequency,
            relativeMagnitudeDB: Double(data.magnitudes[timeBin][frequencyBin]),
            timeBin: timeBin,
            frequencyBin: frequencyBin,
            nearestPartialHarmonic: nearest?.harmonic,
            nearestPartialFrequencyHz: nearest?.point.frequencyHz,
            nearestPartialSignalToNoiseDB: nearest?.point.localSignalToNoiseDB,
            nearestPartialIsValid: nearest?.point.isValid
        )
    }

    private static func nearestPartial(
        tracks: [PartialTrack],
        time: Double,
        frequency: Double,
        timeTolerance: Double,
        centsTolerance: Double
    ) -> (harmonic: Int, point: PartialTrackPoint)? {
        guard frequency > 0 else { return nil }
        var best: (harmonic: Int, point: PartialTrackPoint, cents: Double)?
        for track in tracks {
            guard let point = track.points.min(by: {
                abs($0.timeSeconds - time) < abs($1.timeSeconds - time)
            }), abs(point.timeSeconds - time) <= timeTolerance, point.frequencyHz > 0 else { continue }
            let cents = abs(1_200 * log2(point.frequencyHz / frequency))
            if cents <= centsTolerance, best == nil || cents < best!.cents {
                best = (track.harmonicNumber, point, cents)
            }
        }
        return best.map { ($0.harmonic, $0.point) }
    }
}
