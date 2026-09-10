import Foundation

/// Regions are half-open in time and in frequency-bin ownership. A release
/// boundary is a constraint, never a reason to enlarge a short sustain.
enum SpectrumSegmentation {
    static let version = "orgrec-spectrum-segmentation/2"
    static let maximumPartialFrames = 2_048

    struct SteadyRegion {
        var start: Double
        var end: Double
        var limitations: [String]
        var duration: Double { end - start }
    }

    static func steadyRegion(
        duration: Double, sustainStart: Double?, soundOffset: Double?, keyUp: Double?,
        maximumDuration: Double = 10, releaseGuard: Double = 0.1
    ) -> SteadyRegion {
        guard duration.isFinite, duration > 0, maximumDuration.isFinite, maximumDuration > 0,
              releaseGuard.isFinite, releaseGuard >= 0 else {
            return SteadyRegion(start: 0, end: 0, limitations: ["Invalid source duration or region limits."])
        }
        let observedStart = sustainStart.flatMap { $0.isFinite && $0 >= 0 && $0 < duration ? $0 : nil }
        let start = observedStart ?? min(duration * 0.25, 1)
        let release = [soundOffset, keyUp].compactMap { $0 }.filter { $0.isFinite && $0 >= 0 && $0 <= duration }.min()
        let end = min(duration, start + maximumDuration, release.map { max(0, $0 - releaseGuard) } ?? duration)
        var limitations: [String] = []
        if observedStart == nil { limitations.append("Stable-sustain onset is unobserved; the selected region is provisional.") }
        if release == nil { limitations.append("Release is unobserved; the selected region is provisional.") }
        if end - start < 2 { limitations.append("Less than two seconds of stable sustain are available; LTAS stability is limited.") }
        if end <= start { limitations.append("No sustain remains before the release boundary.") }
        return SteadyRegion(start: start, end: max(start, end), limitations: limitations)
    }

    /// A bin belongs to at most one harmonic, even when search windows overlap.
    /// Fewer than two bins per fundamental cannot separate adjacent harmonics.
    static func harmonicBins(
        harmonic: Int, fundamental: Double, binWidth: Double, toleranceHz: Double,
        lowerBin: Int, upperBin: Int
    ) -> ClosedRange<Int>? {
        guard harmonic > 0, fundamental.isFinite, binWidth.isFinite,
              binWidth > 0, fundamental >= 2 * binWidth, toleranceHz.isFinite,
              toleranceHz > 0, lowerBin >= 0, lowerBin <= upperBin,
              upperBin < Int.max else { return nil }
        let target = fundamental * Double(harmonic)
        let radius = min(toleranceHz, fundamental / 2)
        // Clip in floating point before converting, including overflowed targets.
        let lower = max(Double(lowerBin), ceil((target - radius) / binWidth))
        let upper = min(Double(upperBin), ceil((target + radius) / binWidth) - 1)
        guard lower.isFinite, upper.isFinite, lower <= upper,
              upper < Double(Int.max) else { return nil }
        return Int(lower)...Int(upper)
    }
}
