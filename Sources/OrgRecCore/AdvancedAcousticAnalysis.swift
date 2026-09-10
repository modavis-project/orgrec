import Accelerate
@preconcurrency import AVFAudio
import Foundation

// MARK: - Perceptual and modulation-aware spectral descriptors

/// A reproducible, descriptive view of the stable portion of a sound. These
/// values characterize the recorded signal; they are not organological labels
/// and they do not replace the retained partial tracks.
public struct PerceptualSpectralSummary: Codable, Hashable, Sendable {
    public var contractVersion: String
    public var fftSize: Int
    public var hopSize: Int
    public var analyzedFrameCount: Int
    public var analyzedDurationSeconds: Double
    public var spectralSpreadHz: Double?
    public var spectralSkewness: Double?
    public var spectralKurtosis: Double?
    public var spectralFlatness: Double?
    public var spectralEntropy: Double?
    public var spectralCrestDB: Double?
    public var spectralFlux: Double?
    public var auditoryCentroidERB: Double?
    public var auditorySpreadERB: Double?
    public var auditoryFlatness: Double?
    public var harmonicEnergyRatio: Double?
    public var harmonicSpectralSlopeDBPerOctave: Double?
    public var harmonicSpectralDeviationDB: Double?
    public var tristimulus1: Double?
    public var tristimulus2: Double?
    public var tristimulus3: Double?
    public var amplitudeModulationRateHz: Double?
    public var amplitudeModulationDepthDB: Double?
    public var amplitudeModulationConfidence: Double?
    public var spectralCentroidModulationRateHz: Double?
    public var spectralCentroidModulationDepthERB: Double?
    public var spectralCentroidModulationConfidence: Double?
    public var method: String
    public var limitations: [String]

    public init(
        contractVersion: String = "orgrec-perceptual-spectral-summary/1",
        fftSize: Int,
        hopSize: Int,
        analyzedFrameCount: Int,
        analyzedDurationSeconds: Double,
        spectralSpreadHz: Double? = nil,
        spectralSkewness: Double? = nil,
        spectralKurtosis: Double? = nil,
        spectralFlatness: Double? = nil,
        spectralEntropy: Double? = nil,
        spectralCrestDB: Double? = nil,
        spectralFlux: Double? = nil,
        auditoryCentroidERB: Double? = nil,
        auditorySpreadERB: Double? = nil,
        auditoryFlatness: Double? = nil,
        harmonicEnergyRatio: Double? = nil,
        harmonicSpectralSlopeDBPerOctave: Double? = nil,
        harmonicSpectralDeviationDB: Double? = nil,
        tristimulus1: Double? = nil,
        tristimulus2: Double? = nil,
        tristimulus3: Double? = nil,
        amplitudeModulationRateHz: Double? = nil,
        amplitudeModulationDepthDB: Double? = nil,
        amplitudeModulationConfidence: Double? = nil,
        spectralCentroidModulationRateHz: Double? = nil,
        spectralCentroidModulationDepthERB: Double? = nil,
        spectralCentroidModulationConfidence: Double? = nil,
        method: String,
        limitations: [String] = []
    ) {
        self.contractVersion = contractVersion
        self.fftSize = fftSize
        self.hopSize = hopSize
        self.analyzedFrameCount = analyzedFrameCount
        self.analyzedDurationSeconds = analyzedDurationSeconds
        self.spectralSpreadHz = spectralSpreadHz
        self.spectralSkewness = spectralSkewness
        self.spectralKurtosis = spectralKurtosis
        self.spectralFlatness = spectralFlatness
        self.spectralEntropy = spectralEntropy
        self.spectralCrestDB = spectralCrestDB
        self.spectralFlux = spectralFlux
        self.auditoryCentroidERB = auditoryCentroidERB
        self.auditorySpreadERB = auditorySpreadERB
        self.auditoryFlatness = auditoryFlatness
        self.harmonicEnergyRatio = harmonicEnergyRatio
        self.harmonicSpectralSlopeDBPerOctave = harmonicSpectralSlopeDBPerOctave
        self.harmonicSpectralDeviationDB = harmonicSpectralDeviationDB
        self.tristimulus1 = tristimulus1
        self.tristimulus2 = tristimulus2
        self.tristimulus3 = tristimulus3
        self.amplitudeModulationRateHz = amplitudeModulationRateHz
        self.amplitudeModulationDepthDB = amplitudeModulationDepthDB
        self.amplitudeModulationConfidence = amplitudeModulationConfidence
        self.spectralCentroidModulationRateHz = spectralCentroidModulationRateHz
        self.spectralCentroidModulationDepthERB = spectralCentroidModulationDepthERB
        self.spectralCentroidModulationConfidence = spectralCentroidModulationConfidence
        self.method = method
        self.limitations = limitations
    }

    public var validationErrors: [String] {
        var errors: [String] = []
        if fftSize < 1_024 || !fftSize.isMultiple(of: 2) { errors.append("Perceptual spectral FFT size is invalid.") }
        if hopSize <= 0 { errors.append("Perceptual spectral hop size is invalid.") }
        if analyzedFrameCount <= 0 || !analyzedDurationSeconds.isFinite || analyzedDurationSeconds <= 0 { errors.append("Perceptual spectral evidence has an invalid extent.") }
        let finiteValues = [spectralSpreadHz, spectralSkewness, spectralKurtosis, spectralCrestDB, auditoryCentroidERB, auditorySpreadERB, harmonicSpectralSlopeDBPerOctave, harmonicSpectralDeviationDB, amplitudeModulationRateHz, amplitudeModulationDepthDB, spectralCentroidModulationRateHz, spectralCentroidModulationDepthERB]
        if finiteValues.compactMap({ $0 }).contains(where: { !$0.isFinite }) { errors.append("Perceptual spectral evidence contains a non-finite value.") }
        let ratios = [spectralFlatness, spectralEntropy, spectralFlux, auditoryFlatness, harmonicEnergyRatio, tristimulus1, tristimulus2, tristimulus3, amplitudeModulationConfidence, spectralCentroidModulationConfidence]
        if ratios.compactMap({ $0 }).contains(where: { !$0.isFinite || !(0...1).contains($0) }) { errors.append("Perceptual spectral ratio or confidence lies outside zero through one.") }
        if let first = tristimulus1, let second = tristimulus2, let third = tristimulus3, abs(first + second + third - 1) > 0.01 {
            errors.append("Tristimulus components must sum to one within numerical tolerance.")
        }
        if [amplitudeModulationRateHz, spectralCentroidModulationRateHz].compactMap({ $0 }).contains(where: { $0 <= 0 }) { errors.append("Spectral modulation rates must be positive.") }
        if [amplitudeModulationDepthDB, spectralCentroidModulationDepthERB].compactMap({ $0 }).contains(where: { $0 < 0 }) { errors.append("Spectral modulation depths cannot be negative.") }
        return errors
    }
}

public enum PerceptualSpectralAnalyzer {
    private struct Modulation {
        var rate: Double
        var depth: Double
        var confidence: Double
    }

    /// Implements a bounded STFT plus an ERB-rate triangular filter bank. The
    /// ERB representation follows the auditory-model branch advocated by the
    /// Timbre Toolbox; it is not represented as a calibrated loudness model.
    public static func analyze(
        samples source: [Float],
        sampleRate: Double,
        fundamentalFrequency: Double?,
        maximumDurationSeconds: Double = 30
    ) -> PerceptualSpectralSummary? {
        guard sampleRate.isFinite, sampleRate > 0, source.count >= 1_024 else { return nil }
        let maximumSamples = max(1_024, Int(min(30, max(1, maximumDurationSeconds)) * sampleRate))
        let samples: [Float]
        if source.count > maximumSamples {
            let start = max(0, (source.count - maximumSamples) / 2)
            samples = Array(source[start..<(start + maximumSamples)])
        } else {
            samples = source
        }
        guard samples.allSatisfy({ $0.isFinite }),
              samples.reduce(0.0, { $0 + Double($1) * Double($1) }) / Double(samples.count) > 1e-20 else { return nil }
        let candidates = [1_024, 2_048, 4_096, 8_192]
        let desired = fundamentalFrequency.map { frequency in
            max(2_048, min(8_192, Int((sampleRate * 8 / max(20, frequency)).rounded(.up))))
        } ?? 4_096
        guard let fftSize = candidates.filter({ $0 <= samples.count }).min(by: { abs($0 - desired) < abs($1 - desired) }) else { return nil }
        let hop = max(128, fftSize / 8)
        let available = 1 + (samples.count - fftSize) / hop
        let decimation = max(1, Int(ceil(Double(available) / 600)))
        let effectiveHop = hop * decimation
        let log2n = vDSP_Length(log2(Double(fftSize)))
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return nil }
        defer { vDSP_destroy_fftsetup(setup) }
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        let binWidth = sampleRate / Double(fftSize)
        let lowerBin = max(1, Int(ceil(20 / binWidth)))
        let upperBin = min(fftSize / 2 - 1, Int(floor(min(20_000, sampleRate * 0.49) / binWidth)))
        guard upperBin > lowerBin else { return nil }

        var accumulated = [Double](repeating: 0, count: fftSize / 2)
        var priorNormalized: [Double]?
        var fluxValues: [Double] = []
        var centroidERBTrack: [Double] = []
        var frameCount = 0
        var offset = 0
        while offset + fftSize <= samples.count, frameCount < 600 {
            let power = powerSpectrum(
                frame: Array(samples[offset..<(offset + fftSize)]),
                window: window,
                setup: setup,
                log2n: log2n
            )
            for index in power.indices { accumulated[index] += power[index] }
            let usable = Array(power[lowerBin...upperBin])
            let total = max(1e-24, usable.reduce(0, +))
            let normalized = usable.map { $0 / total }
            if let priorNormalized {
                let cosine = zip(normalized, priorNormalized).reduce(0.0) { $0 + sqrt(max(0, $1.0 * $1.1)) }
                fluxValues.append(min(1, max(0, 1 - cosine)))
            }
            priorNormalized = normalized
            let centroidHz = zip(lowerBin...upperBin, usable).reduce(0.0) { result, pair in
                result + Double(pair.0) * binWidth * pair.1
            } / total
            centroidERBTrack.append(erbRate(centroidHz))
            frameCount += 1
            offset += effectiveHop
        }
        guard frameCount > 0 else { return nil }
        accumulated = accumulated.map { $0 / Double(frameCount) }
        let usablePowers = Array(accumulated[lowerBin...upperBin])
        let frequencies = (lowerBin...upperBin).map { Double($0) * binWidth }
        let totalPower = max(1e-24, usablePowers.reduce(0, +))
        let centroid = zip(frequencies, usablePowers).reduce(0.0) { $0 + $1.0 * $1.1 } / totalPower
        let spread = sqrt(zip(frequencies, usablePowers).reduce(0.0) { $0 + pow($1.0 - centroid, 2) * $1.1 } / totalPower)
        let skewness = spread > 0 ? zip(frequencies, usablePowers).reduce(0.0) { $0 + pow(($1.0 - centroid) / spread, 3) * $1.1 } / totalPower : nil
        let kurtosis = spread > 0 ? zip(frequencies, usablePowers).reduce(0.0) { $0 + pow(($1.0 - centroid) / spread, 4) * $1.1 } / totalPower : nil
        let arithmeticMean = totalPower / Double(usablePowers.count)
        let geometricMean = exp(usablePowers.reduce(0.0) { $0 + log(max($1, 1e-30)) } / Double(usablePowers.count))
        let flatness = min(1, max(0, geometricMean / max(1e-30, arithmeticMean)))
        let probabilities = usablePowers.map { $0 / totalPower }
        let entropy = -probabilities.reduce(0.0) { $0 + ($1 > 0 ? $1 * log($1) : 0) } / log(Double(probabilities.count))
        let crest = 10 * log10(max(1e-30, (usablePowers.max() ?? 0) / max(1e-30, arithmeticMean)))

        let erb = erbBands(powers: accumulated, binWidth: binWidth, lowerHz: 40, upperHz: min(16_000, sampleRate * 0.48), count: 32)
        let erbTotal = max(1e-24, erb.reduce(0.0) { $0 + $1.power })
        let auditoryCentroid = erb.reduce(0.0) { $0 + $1.rate * $1.power } / erbTotal
        let auditorySpread = sqrt(erb.reduce(0.0) { $0 + pow($1.rate - auditoryCentroid, 2) * $1.power } / erbTotal)
        let erbArithmetic = erbTotal / Double(max(1, erb.count))
        let erbGeometric = exp(erb.reduce(0.0) { $0 + log(max($1.power, 1e-30)) } / Double(max(1, erb.count)))

        let harmonic = harmonicDescriptors(
            powers: accumulated,
            binWidth: binWidth,
            lowerBin: lowerBin,
            upperBin: upperBin,
            fundamental: fundamentalFrequency
        )
        let envelope = rmsEnvelope(samples: samples, sampleRate: sampleRate)
        let amplitudeModulation = modulation(values: envelope.values, sampleInterval: envelope.stepSeconds)
        let centroidModulation = modulation(values: centroidERBTrack, sampleInterval: Double(effectiveHop) / sampleRate)

        var limitations = [
            "ERB-rate bands are a descriptive triangular filter bank, not a calibrated loudness or masking model.",
            "Descriptor covariance and recording position must be considered before perceptual or organological interpretation."
        ]
        if fundamentalFrequency == nil {
            limitations.append("Harmonic-energy, slope, deviation, and tristimulus descriptors are unavailable without a defensible fundamental.")
        } else if harmonic == nil {
            limitations.append("Harmonic descriptors are unavailable: insufficient energy or frequency resolution.")
        }
        return PerceptualSpectralSummary(
            fftSize: fftSize,
            hopSize: effectiveHop,
            analyzedFrameCount: frameCount,
            analyzedDurationSeconds: Double(samples.count) / sampleRate,
            spectralSpreadHz: spread,
            spectralSkewness: skewness,
            spectralKurtosis: kurtosis,
            spectralFlatness: flatness,
            spectralEntropy: min(1, max(0, entropy)),
            spectralCrestDB: crest,
            spectralFlux: fluxValues.isEmpty ? nil : median(fluxValues),
            auditoryCentroidERB: auditoryCentroid,
            auditorySpreadERB: auditorySpread,
            auditoryFlatness: min(1, max(0, erbGeometric / max(1e-30, erbArithmetic))),
            harmonicEnergyRatio: harmonic?.energyRatio,
            harmonicSpectralSlopeDBPerOctave: harmonic?.slope,
            harmonicSpectralDeviationDB: harmonic?.deviation,
            tristimulus1: harmonic?.tristimulus.0,
            tristimulus2: harmonic?.tristimulus.1,
            tristimulus3: harmonic?.tristimulus.2,
            amplitudeModulationRateHz: amplitudeModulation?.rate,
            amplitudeModulationDepthDB: amplitudeModulation?.depth,
            amplitudeModulationConfidence: amplitudeModulation?.confidence,
            spectralCentroidModulationRateHz: centroidModulation?.rate,
            spectralCentroidModulationDepthERB: centroidModulation?.depth,
            spectralCentroidModulationConfidence: centroidModulation?.confidence,
            method: "Hann STFT power descriptors, 32-band ERB-rate triangular summary, disjoint harmonic-region energy/2, tristimulus, and detrended sinusoidal modulation scan (0.2–20 Hz)",
            limitations: limitations
        )
    }

    private static func powerSpectrum(
        frame source: [Float],
        window: [Float],
        setup: FFTSetup,
        log2n: vDSP_Length
    ) -> [Double] {
        var frame = source
        vDSP_vmul(frame, 1, window, 1, &frame, 1, vDSP_Length(frame.count))
        var real = [Float](repeating: 0, count: frame.count / 2)
        var imaginary = real
        frame.withUnsafeBytes { raw in
            raw.bindMemory(to: DSPComplex.self).withMemoryRebound(to: DSPComplex.self) { complex in
                real.withUnsafeMutableBufferPointer { rp in
                    imaginary.withUnsafeMutableBufferPointer { ip in
                        var split = DSPSplitComplex(realp: rp.baseAddress!, imagp: ip.baseAddress!)
                        vDSP_ctoz(complex.baseAddress!, 2, &split, 1, vDSP_Length(frame.count / 2))
                        vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                    }
                }
            }
        }
        let normalization = 1 / pow(Double(frame.count), 2)
        return real.indices.map { index in
            (Double(real[index]) * Double(real[index]) + Double(imaginary[index]) * Double(imaginary[index])) * normalization
        }
    }

    private static func erbBands(
        powers: [Double], binWidth: Double, lowerHz: Double, upperHz: Double, count: Int
    ) -> [(rate: Double, power: Double)] {
        guard count > 0, upperHz > lowerHz else { return [] }
        let lower = erbRate(lowerHz), upper = erbRate(upperHz)
        let anchors = (0..<(count + 2)).map { lower + Double($0) / Double(count + 1) * (upper - lower) }
        return (1...count).map { band in
            let left = anchors[band - 1], center = anchors[band], right = anchors[band + 1]
            var power = 0.0
            for index in powers.indices {
                let rate = erbRate(Double(index) * binWidth)
                let weight: Double
                if rate >= left, rate <= center { weight = (rate - left) / max(1e-12, center - left) }
                else if rate > center, rate <= right { weight = (right - rate) / max(1e-12, right - center) }
                else { weight = 0 }
                power += powers[index] * weight
            }
            return (center, power)
        }
    }

    private static func harmonicDescriptors(
        powers: [Double], binWidth: Double, lowerBin: Int, upperBin: Int, fundamental: Double?
    ) -> (energyRatio: Double, slope: Double?, deviation: Double?, tristimulus: (Double, Double, Double))? {
        guard let fundamental, fundamental.isFinite, fundamental >= 20 else { return nil }
        let total = powers[lowerBin...upperBin].reduce(0, +)
        guard total.isFinite, total > 1e-24 else { return nil }
        let maximumHarmonic = min(64, Int((Double(upperBin) * binWidth / fundamental).rounded(.down)))
        guard maximumHarmonic >= 1 else { return nil }
        var usedBins = Set<Int>()
        var partials: [(number: Int, power: Double)] = []
        for harmonic in 1...maximumHarmonic {
            let expected = fundamental * Double(harmonic)
            let toleranceHz = max(binWidth * 1.5, expected * (pow(2, 35.0 / 1_200) - 1))
            guard let region = SpectrumSegmentation.harmonicBins(
                harmonic: harmonic, fundamental: fundamental, binWidth: binWidth,
                toleranceHz: toleranceHz, lowerBin: lowerBin, upperBin: upperBin
            ) else { continue }
            region.forEach { usedBins.insert($0) }
            partials.append((harmonic, region.reduce(0.0) { $0 + powers[$1] }))
        }
        let harmonicPower = usedBins.reduce(0.0) { $0 + powers[$1] }
        let partialTotal = partials.reduce(0.0) { $0 + $1.power }
        guard partialTotal.isFinite, partialTotal > 1e-24 else { return nil }
        let t1 = (partials.first(where: { $0.number == 1 })?.power ?? 0) / partialTotal
        let t2 = partials.filter { (2...4).contains($0.number) }.reduce(0.0) { $0 + $1.power } / partialTotal
        let t3 = max(0, 1 - t1 - t2)
        let regressionPoints = partials.filter { $0.power > partialTotal * 1e-8 }.map {
            (x: log2(Double($0.number)), y: 10 * log10(max(1e-30, $0.power / partialTotal)))
        }
        let regression = linearRegression(regressionPoints)
        let deviation: Double?
        if let regression, regressionPoints.count >= 3 {
            deviation = sqrt(regressionPoints.reduce(0.0) { result, point in
                result + pow(point.y - (regression.intercept + regression.slope * point.x), 2)
            } / Double(regressionPoints.count))
        } else { deviation = nil }
        return (min(1, max(0, harmonicPower / total)), regression?.slope, deviation, (t1, t2, t3))
    }

    private static func rmsEnvelope(samples: [Float], sampleRate: Double) -> (values: [Double], stepSeconds: Double) {
        let window = max(64, Int(0.02 * sampleRate))
        let hop = max(32, Int(0.005 * sampleRate))
        guard samples.count >= window else { return ([], Double(hop) / sampleRate) }
        var values: [Double] = []
        var offset = 0
        while offset + window <= samples.count {
            var rms: Float = 0
            samples.withUnsafeBufferPointer { pointer in
                if let base = pointer.baseAddress {
                    vDSP_rmsqv(base.advanced(by: offset), 1, &rms, vDSP_Length(window))
                }
            }
            values.append(20 * log10(max(1e-12, Double(rms))))
            offset += hop
        }
        return (values, Double(hop) / sampleRate)
    }

    private static func modulation(values: [Double], sampleInterval: Double) -> Modulation? {
        guard values.count >= 80, sampleInterval > 0 else { return nil }
        let duration = Double(values.count - 1) * sampleInterval
        guard duration >= 1 else { return nil }
        let xMean = Double(values.count - 1) / 2
        let yMean = values.reduce(0, +) / Double(values.count)
        let denominator = values.indices.reduce(0.0) { $0 + pow(Double($1) - xMean, 2) }
        let slope = denominator > 0 ? values.indices.reduce(0.0) {
            $0 + (Double($1) - xMean) * (values[$1] - yMean)
        } / denominator : 0
        let detrended = values.indices.map { values[$0] - yMean - slope * (Double($0) - xMean) }
        let totalEnergy = detrended.reduce(0.0) { $0 + $1 * $1 }
        guard totalEnergy > 1e-10 else { return nil }
        let maximumFrequency = min(20, 0.45 / sampleInterval)
        let minimumFrequency = max(0.2, 1.5 / duration)
        guard maximumFrequency > minimumFrequency else { return nil }
        let step = max(0.01, 1 / (duration * 5))
        var best: (frequency: Double, explained: Double)?
        var frequency = minimumFrequency
        while frequency <= maximumFrequency {
            var cosine = 0.0, sine = 0.0, cosineEnergy = 0.0, sineEnergy = 0.0
            for index in detrended.indices {
                let phase = 2 * Double.pi * frequency * Double(index) * sampleInterval
                let c = cos(phase), s = sin(phase)
                cosine += detrended[index] * c; sine += detrended[index] * s
                cosineEnergy += c * c; sineEnergy += s * s
            }
            let explained = (cosine * cosine / max(1e-12, cosineEnergy) + sine * sine / max(1e-12, sineEnergy)) / totalEnergy
            if best == nil || explained > best!.explained { best = (frequency, explained) }
            frequency += step
        }
        guard let best, best.explained >= 0.08 else { return nil }
        let depth = quantile(values, probability: 0.95) - quantile(values, probability: 0.05)
        return Modulation(rate: best.frequency, depth: max(0, depth), confidence: min(1, max(0, best.explained)))
    }

    private static func erbRate(_ frequency: Double) -> Double {
        21.4 * log10(1 + 0.00437 * max(0, frequency))
    }
}

// MARK: - Qualified response and energy-decay analysis

public enum AcousticResponseQualification: String, Codable, CaseIterable, Identifiable, Sendable {
    case deconvolvedImpulseResponse
    case impulsiveSourceResponse
    case observedInstrumentRelease

    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .deconvolvedImpulseResponse: "Deconvolved impulse response"
        case .impulsiveSourceResponse: "Impulsive-source response"
        case .observedInstrumentRelease: "Observed pipe-plus-room release"
        }
    }
    public var supportsEarlyEnergyMetrics: Bool { self != .observedInstrumentRelease }
    public var isRoomImpulseResponse: Bool { self != .observedInstrumentRelease }
}

public struct AcousticDecayFit: Codable, Hashable, Identifiable, Sendable {
    public var id: String { label }
    public var label: String
    public var upperLevelDB: Double
    public var lowerLevelDB: Double
    public var slopeDBPerSecond: Double
    public var extrapolatedDecayTimeSeconds: Double
    public var coefficientOfDetermination: Double
    public var standardUncertaintySeconds: Double?
    public var pointCount: Int
}

public struct MultiSlopeDecayEvidence: Codable, Hashable, Sendable {
    public var deltaBIC: Double
    public var earlyDecayTimeSeconds: Double
    public var lateDecayTimeSeconds: Double
    public var transitionTimeSeconds: Double
    public var transitionLevelDB: Double
    public var earlyFitR2: Double
    public var lateFitR2: Double
}

public struct AcousticBandMetrics: Codable, Hashable, Identifiable, Sendable {
    public var id: String { centerFrequencyHz.map { String(format: "%.6f", $0) } ?? "broadband" }
    public var centerFrequencyHz: Double?
    public var lowerFrequencyHz: Double?
    public var upperFrequencyHz: Double?
    public var edt: AcousticDecayFit?
    public var t20: AcousticDecayFit?
    public var t30: AcousticDecayFit?
    public var clarity50DB: Double?
    public var clarity80DB: Double?
    public var definition50: Double?
    public var centerTimeSeconds: Double?
    public var directToReverberantRatioDB: Double?
    public var estimatedNoiseFloorDB: Double
    public var usableDecayRangeDB: Double
    public var multiSlope: MultiSlopeDecayEvidence?
    public var temporalResolutionSeconds: Double
}

public struct AcousticResponseAnalysis: Codable, Hashable, Sendable {
    public var contractVersion: String
    public var qualification: AcousticResponseQualification
    public var referenceChannel: Int
    public var analyzedAt: Date
    public var analyzedDurationSeconds: Double
    public var directArrivalSeconds: Double?
    public var broadband: AcousticBandMetrics
    public var octaveBands: [AcousticBandMetrics]
    public var standardReference: String?
    public var conformanceStatement: String
    public var method: String
    public var warnings: [String]

    public var validationErrors: [String] {
        var errors: [String] = []
        if referenceChannel < 0 { errors.append("Acoustic-response reference channel cannot be negative.") }
        if !analyzedDurationSeconds.isFinite || analyzedDurationSeconds <= 0 { errors.append("Acoustic-response duration must be positive.") }
        let centers = octaveBands.compactMap(\.centerFrequencyHz)
        if Set(centers).count != centers.count { errors.append("Acoustic-response octave-band centers must be unique.") }
        for band in [broadband] + octaveBands { errors.append(contentsOf: Self.errors(for: band)) }
        if qualification == .observedInstrumentRelease {
            if standardReference != nil { errors.append("Observed instrument release must not claim a room-acoustic standard reference.") }
            if broadband.clarity50DB != nil || broadband.clarity80DB != nil || broadband.definition50 != nil || broadband.directToReverberantRatioDB != nil {
                errors.append("Observed instrument release must not contain impulse-response early-energy metrics.")
            }
        } else if standardReference?.isEmpty != false {
            errors.append("A declared room impulse response requires an exact standard reference.")
        }
        return errors
    }

    private static func errors(for band: AcousticBandMetrics) -> [String] {
        var errors: [String] = []
        if let center = band.centerFrequencyHz, !center.isFinite || center <= 0 { errors.append("Acoustic band center frequency is invalid.") }
        if !band.estimatedNoiseFloorDB.isFinite || !band.usableDecayRangeDB.isFinite || band.usableDecayRangeDB < 0 || !band.temporalResolutionSeconds.isFinite || band.temporalResolutionSeconds <= 0 {
            errors.append("Acoustic band range, noise floor, or time resolution is invalid.")
        }
        for fit in [band.edt, band.t20, band.t30].compactMap({ $0 }) {
            if !fit.slopeDBPerSecond.isFinite || fit.slopeDBPerSecond >= 0 || !fit.extrapolatedDecayTimeSeconds.isFinite || fit.extrapolatedDecayTimeSeconds <= 0 || !fit.coefficientOfDetermination.isFinite || !(0...1).contains(fit.coefficientOfDetermination) || fit.pointCount < 3 {
                errors.append("Acoustic decay fit \(fit.label) is invalid.")
            }
            if let uncertainty = fit.standardUncertaintySeconds, !uncertainty.isFinite || uncertainty < 0 { errors.append("Acoustic decay-fit uncertainty is invalid.") }
        }
        if let definition = band.definition50, !definition.isFinite || !(0...1).contains(definition) { errors.append("D50 must lie between zero and one.") }
        let finite = [band.clarity50DB, band.clarity80DB, band.centerTimeSeconds, band.directToReverberantRatioDB].compactMap({ $0 })
        if finite.contains(where: { !$0.isFinite }) { errors.append("Acoustic early-energy evidence contains a non-finite value.") }
        if let centerTime = band.centerTimeSeconds, centerTime < 0 { errors.append("Acoustic center time cannot be negative.") }
        if let multi = band.multiSlope {
            if !multi.deltaBIC.isFinite || multi.deltaBIC < 0 || !multi.earlyDecayTimeSeconds.isFinite || multi.earlyDecayTimeSeconds <= 0 || !multi.lateDecayTimeSeconds.isFinite || multi.lateDecayTimeSeconds <= 0 || !multi.transitionTimeSeconds.isFinite || multi.transitionTimeSeconds < 0 || !(0...1).contains(multi.earlyFitR2) || !(0...1).contains(multi.lateFitR2) {
                errors.append("Multi-slope decay evidence is invalid.")
            }
        }
        return errors
    }
}

public enum AcousticResponseAnalyzer {
    private struct Regression {
        var slope: Double
        var intercept: Double
        var r2: Double
        var slopeStandardError: Double?
        var count: Int
        var sse: Double
    }

    private struct DecayCurve {
        var times: [Double]
        var levels: [Double]
        var correctedEnergy: [Double]
        var noisePower: Double
        var truncationIndex: Int
        var usableRange: Double
    }

    public static func analyze(
        fileURL: URL,
        referenceChannel: Int,
        qualification: AcousticResponseQualification,
        maximumDurationSeconds: Double = 30
    ) throws -> AcousticResponseAnalysis? {
        let file = try AVAudioFile(forReading: fileURL)
        let format = file.processingFormat
        guard file.length > 0, format.channelCount > 0 else { return nil }
        let selected = max(0, min(Int(format.channelCount) - 1, referenceChannel))
        let frames = min(file.length, Int64(max(1, min(60, maximumDurationSeconds)) * format.sampleRate))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)) else { return nil }
        try file.read(into: buffer, frameCount: AVAudioFrameCount(frames))
        guard let channels = buffer.floatChannelData else { return nil }
        let samples = Array(UnsafeBufferPointer(start: channels[selected], count: Int(buffer.frameLength)))
        return analyze(samples: samples, sampleRate: format.sampleRate, referenceChannel: selected, qualification: qualification)
    }

    public static func analyze(
        samples source: [Float],
        sampleRate: Double,
        referenceChannel: Int = 0,
        qualification: AcousticResponseQualification,
        originSample: Int? = nil
    ) -> AcousticResponseAnalysis? {
        guard sampleRate.isFinite, sampleRate > 0, source.count >= max(256, Int(sampleRate * 0.12)) else { return nil }
        let detectedOrigin: Int
        if let originSample { detectedOrigin = max(0, min(source.count - 1, originSample)) }
        else { detectedOrigin = arrivalIndex(samples: source, sampleRate: sampleRate) }
        let maximumCount = min(source.count - detectedOrigin, Int(sampleRate * 30))
        guard maximumCount >= max(256, Int(sampleRate * 0.1)) else { return nil }
        var samples = Array(source[detectedOrigin..<(detectedOrigin + maximumCount)]).map(Double.init)
        let tailCount = max(32, min(samples.count / 5, Int(sampleRate)))
        let tailMean = samples.suffix(tailCount).reduce(0, +) / Double(tailCount)
        samples = samples.map { $0 - tailMean }
        guard let broadbandCurve = decayCurve(energies: samples.map { $0 * $0 }, stepSeconds: 1 / sampleRate) else { return nil }
        let supportsEarly = qualification.supportsEarlyEnergyMetrics
        let broadband = metrics(
            curve: broadbandCurve,
            center: nil,
            lower: nil,
            upper: nil,
            temporalResolution: 1 / sampleRate,
            supportsEarlyEnergy: supportsEarly
        )
        let octave = octaveBandMetrics(samples: samples, sampleRate: sampleRate)
        var warnings: [String] = []
        if broadband.usableDecayRangeDB < 25 {
            warnings.append("Usable decay range is below 25 dB; T20/T30 evidence is limited or unavailable.")
        } else if broadband.usableDecayRangeDB < 35 {
            warnings.append("Usable decay range is below 35 dB; T30 is unavailable or noise-sensitive.")
        }
        if let t20 = broadband.t20, t20.coefficientOfDetermination < 0.9 {
            warnings.append("The broadband T20 decay is not strongly linear (R² < 0.90).")
        }
        if broadband.multiSlope != nil {
            warnings.append("BIC supports multiple decay slopes; a single reverberation-time value is incomplete for this response.")
        }
        if qualification == .observedInstrumentRelease {
            warnings.append("The measured decay combines pipe shut-off, partial-dependent radiation, microphone position, and room response; it is not an ISO 3382 reverberation time.")
        }
        let standard = qualification.isRoomImpulseResponse ? "https://www.iso.org/standard/40979.html (ISO 3382-1:2009)" : nil
        let conformance = qualification.isRoomImpulseResponse
            ? "Research estimate derived from a declared response. OrgRec records the ISO 3382-1:2009 reference and estimator details but is not a certified IEC 61260 filter instrument or a complete ISO test report."
            : "Descriptive pipe-plus-room release evidence; no ISO 3382 conformance is claimed."
        return AcousticResponseAnalysis(
            contractVersion: "orgrec-acoustic-response-analysis/1",
            qualification: qualification,
            referenceChannel: max(0, referenceChannel),
            analyzedAt: .now,
            analyzedDurationSeconds: Double(samples.count) / sampleRate,
            directArrivalSeconds: qualification.isRoomImpulseResponse ? Double(detectedOrigin) / sampleRate : nil,
            broadband: broadband,
            octaveBands: octave,
            standardReference: standard,
            conformanceStatement: conformance,
            method: "Noise-intersection-truncated, noise-subtracted Schroeder energy integration; 0…−10, −5…−25, and −5…−35 dB regressions with slope uncertainty; ΔBIC piecewise-decay test; broadband early-energy metrics; Hann-STFT base-10 octave decay estimates",
            warnings: warnings
        )
    }

    private static func arrivalIndex(samples: [Float], sampleRate: Double) -> Int {
        guard let peakIndex = samples.indices.max(by: { abs(samples[$0]) < abs(samples[$1]) }) else { return 0 }
        let peak = max(1e-12, Double(abs(samples[peakIndex])))
        let baselineCount = max(32, min(peakIndex, Int(sampleRate * 0.1)))
        let baseline: Double
        if baselineCount > 0 {
            baseline = sqrt(samples.prefix(baselineCount).reduce(0.0) { $0 + Double($1) * Double($1) } / Double(baselineCount))
        } else { baseline = 0 }
        let threshold = max(peak * 0.02, baseline * 8, 1e-8)
        return samples[0...peakIndex].firstIndex { Double(abs($0)) >= threshold } ?? peakIndex
    }

    private static func decayCurve(energies source: [Double], stepSeconds: Double) -> DecayCurve? {
        guard source.count >= 64, stepSeconds > 0 else { return nil }
        let tailCount = max(16, min(source.count / 5, Int(1 / stepSeconds)))
        let tail = Array(source.suffix(tailCount)).sorted()
        let noisePower = max(1e-30, quantile(tail, probability: 0.5))
        let blockSize = max(1, Int(0.01 / stepSeconds))
        var blockLevels: [(sample: Int, level: Double)] = []
        var offset = 0
        while offset + blockSize <= source.count {
            let mean = source[offset..<(offset + blockSize)].reduce(0, +) / Double(blockSize)
            blockLevels.append((offset + blockSize / 2, 10 * log10(max(1e-30, mean))))
            offset += blockSize
        }
        let noiseDB = 10 * log10(noisePower)
        let peakDB = blockLevels.map(\.level).max() ?? noiseDB
        let provisional = blockLevels.filter { point in
            let relative = point.level - peakDB
            return relative <= -5 && relative >= -25 && point.level >= noiseDB + 8
        }.map { (x: Double($0.sample) * stepSeconds, y: $0.level) }
        let provisionalFit = regression(provisional)
        let intersectionTime: Double
        if let fit = provisionalFit, fit.slope < -0.1 {
            intersectionTime = (noiseDB + 8 - fit.intercept) / fit.slope
        } else {
            intersectionTime = Double(source.count - 1) * stepSeconds
        }
        let minimumTruncation = min(source.count - 1, max(blockSize * 4, Int(0.08 / stepSeconds)))
        let truncation = max(minimumTruncation, min(source.count - 1, Int(max(0, intersectionTime) / stepSeconds)))
        let corrected = source[0...truncation].map { max(0, $0 - noisePower) }
        guard corrected.reduce(0, +) > 1e-24 else { return nil }
        var integral = [Double](repeating: 0, count: corrected.count)
        var running = 0.0
        for index in corrected.indices.reversed() {
            running += corrected[index]
            integral[index] = running
        }
        let reference = max(1e-30, integral[0])
        let stride = max(1, Int(0.0025 / stepSeconds))
        var times: [Double] = [], levels: [Double] = []
        var index = 0
        while index < integral.count {
            times.append(Double(index) * stepSeconds)
            levels.append(10 * log10(max(1e-30, integral[index] / reference)))
            index += stride
        }
        if times.last != Double(integral.count - 1) * stepSeconds {
            times.append(Double(integral.count - 1) * stepSeconds)
            levels.append(10 * log10(max(1e-30, integral.last! / reference)))
        }
        // The final integrated sample can approach numerical zero and must not
        // be mistaken for measurement dynamic range. Usable range ends at the
        // estimated decay/noise intersection, eight decibels above the tail
        // noise estimate used for truncation.
        let usable = max(0, peakDB - (noiseDB + 8))
        return DecayCurve(times: times, levels: levels, correctedEnergy: corrected, noisePower: noisePower, truncationIndex: truncation, usableRange: usable)
    }

    private static func metrics(
        curve: DecayCurve,
        center: Double?,
        lower: Double?,
        upper: Double?,
        temporalResolution: Double,
        supportsEarlyEnergy: Bool
    ) -> AcousticBandMetrics {
        let edt = decayFit(label: "EDT", upper: 0, lower: -10, curve: curve)
        let t20 = decayFit(label: "T20", upper: -5, lower: -25, curve: curve)
        let t30 = decayFit(label: "T30", upper: -5, lower: -35, curve: curve)
        let total = max(1e-30, curve.correctedEnergy.reduce(0, +))
        func split(_ seconds: Double) -> (early: Double, late: Double) {
            let cutoff = min(curve.correctedEnergy.count, max(1, Int(seconds / temporalResolution)))
            let early = curve.correctedEnergy.prefix(cutoff).reduce(0, +)
            return (early, max(1e-30, total - early))
        }
        let split50 = split(0.05), split80 = split(0.08), direct = split(0.0025)
        let centerTime = curve.correctedEnergy.indices.reduce(0.0) {
            $0 + Double($1) * temporalResolution * curve.correctedEnergy[$1]
        } / total
        return AcousticBandMetrics(
            centerFrequencyHz: center,
            lowerFrequencyHz: lower,
            upperFrequencyHz: upper,
            edt: edt,
            t20: t20,
            t30: t30,
            clarity50DB: supportsEarlyEnergy ? 10 * log10(max(1e-30, split50.early) / split50.late) : nil,
            clarity80DB: supportsEarlyEnergy ? 10 * log10(max(1e-30, split80.early) / split80.late) : nil,
            definition50: supportsEarlyEnergy ? min(1, max(0, split50.early / total)) : nil,
            centerTimeSeconds: supportsEarlyEnergy ? centerTime : nil,
            directToReverberantRatioDB: supportsEarlyEnergy ? 10 * log10(max(1e-30, direct.early) / direct.late) : nil,
            estimatedNoiseFloorDB: 10 * log10(max(1e-30, curve.noisePower)),
            usableDecayRangeDB: curve.usableRange,
            multiSlope: multiSlope(curve),
            temporalResolutionSeconds: temporalResolution
        )
    }

    private static func decayFit(label: String, upper: Double, lower: Double, curve: DecayCurve) -> AcousticDecayFit? {
        guard curve.usableRange >= abs(lower) else { return nil }
        let points = zip(curve.times, curve.levels).filter { $0.1 <= upper && $0.1 >= lower }.map { (x: $0.0, y: $0.1) }
        guard let fit = regression(points), fit.slope < -0.01, points.count >= 6 else { return nil }
        let rt = -60 / fit.slope
        let uncertainty = fit.slopeStandardError.map { abs(60 / (fit.slope * fit.slope)) * $0 }
        return AcousticDecayFit(
            label: label,
            upperLevelDB: upper,
            lowerLevelDB: lower,
            slopeDBPerSecond: fit.slope,
            extrapolatedDecayTimeSeconds: rt,
            coefficientOfDetermination: fit.r2,
            standardUncertaintySeconds: uncertainty,
            pointCount: fit.count
        )
    }

    private static func multiSlope(_ curve: DecayCurve) -> MultiSlopeDecayEvidence? {
        let points = zip(curve.times, curve.levels).filter { $0.1 <= -5 && $0.1 >= -min(40, curve.usableRange - 2) }.map { (x: $0.0, y: $0.1) }
        guard points.count >= 18, let single = regression(points), single.sse > 1e-12 else { return nil }
        let singleBIC = Double(points.count) * log(single.sse / Double(points.count)) + 2 * log(Double(points.count))
        var best: (index: Int, early: Regression, late: Regression, bic: Double)?
        for index in 7...(points.count - 8) {
            guard let early = regression(Array(points[0...index])), let late = regression(Array(points[index..<points.count])),
                  early.slope < -0.01, late.slope < -0.01 else { continue }
            let sse = max(1e-12, early.sse + late.sse)
            let bic = Double(points.count) * log(sse / Double(points.count)) + 5 * log(Double(points.count))
            if best == nil || bic < best!.bic { best = (index, early, late, bic) }
        }
        guard let best else { return nil }
        let delta = singleBIC - best.bic
        let earlyRT = -60 / best.early.slope, lateRT = -60 / best.late.slope
        let ratio = max(earlyRT, lateRT) / max(1e-9, min(earlyRT, lateRT))
        guard delta >= 10, ratio >= 1.25, best.early.r2 >= 0.85, best.late.r2 >= 0.85 else { return nil }
        return MultiSlopeDecayEvidence(
            deltaBIC: delta,
            earlyDecayTimeSeconds: earlyRT,
            lateDecayTimeSeconds: lateRT,
            transitionTimeSeconds: points[best.index].x,
            transitionLevelDB: points[best.index].y,
            earlyFitR2: best.early.r2,
            lateFitR2: best.late.r2
        )
    }

    private static func octaveBandMetrics(samples: [Double], sampleRate: Double) -> [AcousticBandMetrics] {
        let fftSize = samples.count >= 4_096 ? 4_096 : 2_048
        guard samples.count >= fftSize else { return [] }
        let hop = max(128, fftSize / 8)
        let log2n = vDSP_Length(log2(Double(fftSize)))
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return [] }
        defer { vDSP_destroy_fftsetup(setup) }
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        let octaveEdgeRatio = pow(10.0, 3.0 / 20.0)
        let candidateCenters: [Double] = (-4...3).map { exponent in
            1_000.0 * pow(10.0, 3.0 * Double(exponent) / 10.0)
        }
        let centers = candidateCenters.filter { center in
            center / octaveEdgeRatio < sampleRate / 2
        }
        var energies = [[Double]](repeating: [], count: centers.count)
        var offset = 0
        while offset + fftSize <= samples.count {
            let frame = Array(samples[offset..<(offset + fftSize)]).map(Float.init)
            let power = PerceptualSpectralAnalyzerPowerBridge.powerSpectrum(frame: frame, window: window, setup: setup, log2n: log2n)
            let binWidth = sampleRate / Double(fftSize)
            for (band, center) in centers.enumerated() {
                let lower = max(1, Int(ceil(center / octaveEdgeRatio / binWidth)))
                let upper = min(power.count - 1, Int(floor(center * octaveEdgeRatio / binWidth)))
                energies[band].append(lower <= upper ? power[lower...upper].reduce(0, +) : 0)
            }
            offset += hop
        }
        let step = Double(hop) / sampleRate
        return centers.enumerated().compactMap { index, center in
            guard let curve = decayCurve(energies: energies[index], stepSeconds: step) else { return nil }
            return metrics(
                curve: curve,
                center: center,
                lower: center / octaveEdgeRatio,
                upper: center * octaveEdgeRatio,
                temporalResolution: step,
                supportsEarlyEnergy: false
            )
        }
    }

    private static func regression(_ points: [(x: Double, y: Double)]) -> Regression? {
        guard points.count >= 3 else { return nil }
        let meanX = points.reduce(0.0) { $0 + $1.x } / Double(points.count)
        let meanY = points.reduce(0.0) { $0 + $1.y } / Double(points.count)
        let sxx = points.reduce(0.0) { $0 + pow($1.x - meanX, 2) }
        guard sxx > 1e-18 else { return nil }
        let slope = points.reduce(0.0) { $0 + ($1.x - meanX) * ($1.y - meanY) } / sxx
        let intercept = meanY - slope * meanX
        let sse = points.reduce(0.0) { $0 + pow($1.y - (intercept + slope * $1.x), 2) }
        let sst = points.reduce(0.0) { $0 + pow($1.y - meanY, 2) }
        let standardError = points.count > 2 ? sqrt(max(0, sse / Double(points.count - 2)) / sxx) : nil
        return Regression(slope: slope, intercept: intercept, r2: sst > 1e-18 ? max(0, min(1, 1 - sse / sst)) : 1, slopeStandardError: standardError, count: points.count, sse: sse)
    }
}

/// Shared FFT implementation without widening the public analyzer API.
private enum PerceptualSpectralAnalyzerPowerBridge {
    static func powerSpectrum(frame source: [Float], window: [Float], setup: FFTSetup, log2n: vDSP_Length) -> [Double] {
        var frame = source
        vDSP_vmul(frame, 1, window, 1, &frame, 1, vDSP_Length(frame.count))
        var real = [Float](repeating: 0, count: frame.count / 2), imaginary = real
        frame.withUnsafeBytes { raw in
            raw.bindMemory(to: DSPComplex.self).withMemoryRebound(to: DSPComplex.self) { complex in
                real.withUnsafeMutableBufferPointer { rp in imaginary.withUnsafeMutableBufferPointer { ip in
                    var split = DSPSplitComplex(realp: rp.baseAddress!, imagp: ip.baseAddress!)
                    vDSP_ctoz(complex.baseAddress!, 2, &split, 1, vDSP_Length(frame.count / 2))
                    vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                }}
            }
        }
        let normalization = 1 / pow(Double(frame.count), 2)
        return real.indices.map { (Double(real[$0]) * Double(real[$0]) + Double(imaginary[$0]) * Double(imaginary[$0])) * normalization }
    }
}

private func linearRegression(_ points: [(x: Double, y: Double)]) -> (slope: Double, intercept: Double)? {
    guard points.count >= 2 else { return nil }
    let meanX = points.reduce(0.0) { $0 + $1.x } / Double(points.count)
    let meanY = points.reduce(0.0) { $0 + $1.y } / Double(points.count)
    let denominator = points.reduce(0.0) { $0 + pow($1.x - meanX, 2) }
    guard denominator > 1e-18 else { return nil }
    let slope = points.reduce(0.0) { $0 + ($1.x - meanX) * ($1.y - meanY) } / denominator
    return (slope, meanY - slope * meanX)
}

private func quantile(_ values: [Double], probability: Double) -> Double {
    guard values.isEmpty == false else { return 0 }
    let sorted = values.sorted()
    let position = min(1, max(0, probability)) * Double(sorted.count - 1)
    let lower = Int(floor(position)), upper = Int(ceil(position))
    if lower == upper { return sorted[lower] }
    return sorted[lower] + (sorted[upper] - sorted[lower]) * (position - Double(lower))
}

private func median(_ values: [Double]) -> Double {
    quantile(values, probability: 0.5)
}
