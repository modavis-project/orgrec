import Accelerate
import AudioToolbox
@preconcurrency import AVFAudio
import Foundation

public enum LongTakeAssignmentMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case ascendingFromAnchor = "Ascending from selected note"
    case nearestPitch = "Automatic by pitch"

    public var id: String { rawValue }
}

public struct LongTakePitchCandidate: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID { roadmapItemID }
    public var roadmapItemID: UUID
    public var midiNote: Int
    public var expectedFrequencyHz: Double
    public var label: String

    public init(
        roadmapItemID: UUID,
        midiNote: Int,
        expectedFrequencyHz: Double,
        label: String
    ) {
        self.roadmapItemID = roadmapItemID
        self.midiNote = midiNote
        self.expectedFrequencyHz = expectedFrequencyHz
        self.label = label
    }
}

public struct LongTakeSegmentationConfiguration: Codable, Hashable, Sendable {
    public var hopSeconds: Double
    public var minimumNoteDurationSeconds: Double
    public var minimumSilenceDurationSeconds: Double
    public var onsetPersistenceSeconds: Double
    public var preRollSeconds: Double
    public var maximumReleaseTailSeconds: Double
    public var tailSilencePersistenceSeconds: Double
    public var stablePitchSampleSeconds: Double

    public init(
        hopSeconds: Double = 0.02,
        minimumNoteDurationSeconds: Double = 0.8,
        minimumSilenceDurationSeconds: Double = 0.38,
        onsetPersistenceSeconds: Double = 0.06,
        preRollSeconds: Double = 0.01,
        maximumReleaseTailSeconds: Double = 4,
        tailSilencePersistenceSeconds: Double = 0.24,
        stablePitchSampleSeconds: Double = 2.5
    ) {
        self.hopSeconds = hopSeconds
        self.minimumNoteDurationSeconds = minimumNoteDurationSeconds
        self.minimumSilenceDurationSeconds = minimumSilenceDurationSeconds
        self.onsetPersistenceSeconds = onsetPersistenceSeconds
        self.preRollSeconds = preRollSeconds
        self.maximumReleaseTailSeconds = maximumReleaseTailSeconds
        self.tailSilencePersistenceSeconds = tailSilencePersistenceSeconds
        self.stablePitchSampleSeconds = stablePitchSampleSeconds
    }
}

public struct LongTakeSegment: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var sequenceNumber: Int
    public var onsetSeconds: Double
    public var soundOffsetSeconds: Double
    public var exportStartSeconds: Double
    public var exportEndSeconds: Double
    public var onsetFrame: Int64?
    public var soundOffsetFrame: Int64?
    public var exportStartFrame: Int64?
    public var exportEndFrame: Int64?
    public var onsetDetectionMethod: String?
    public var onsetTimeResolutionSeconds: Double?
    public var onsetFrequencyWindowSeconds: Double?
    public var tailEndSeconds: Double?
    public var tailEndFrame: Int64?
    public var tailDetectionMethod: String?
    public var tailConfidence: Double?
    public var onsetConfidence: Double
    public var offsetConfidence: Double
    public var peakDBFS: Double
    public var estimatedFrequencyHz: Double?
    public var pitchConfidence: Double?
    public var assignedRoadmapItemID: UUID?
    public var assignedMIDINote: Int?
    public var expectedFrequencyHz: Double?
    public var pitchDeviationCents: Double?
    public var assignmentConfidence: Double
    public var warnings: [String]

    public init(
        id: UUID = UUID(),
        sequenceNumber: Int,
        onsetSeconds: Double,
        soundOffsetSeconds: Double,
        exportStartSeconds: Double,
        exportEndSeconds: Double,
        onsetFrame: Int64? = nil,
        soundOffsetFrame: Int64? = nil,
        exportStartFrame: Int64? = nil,
        exportEndFrame: Int64? = nil,
        onsetDetectionMethod: String? = nil,
        onsetTimeResolutionSeconds: Double? = nil,
        onsetFrequencyWindowSeconds: Double? = nil,
        tailEndSeconds: Double? = nil,
        tailEndFrame: Int64? = nil,
        tailDetectionMethod: String? = nil,
        tailConfidence: Double? = nil,
        onsetConfidence: Double,
        offsetConfidence: Double,
        peakDBFS: Double,
        estimatedFrequencyHz: Double? = nil,
        pitchConfidence: Double? = nil,
        assignedRoadmapItemID: UUID? = nil,
        assignedMIDINote: Int? = nil,
        expectedFrequencyHz: Double? = nil,
        pitchDeviationCents: Double? = nil,
        assignmentConfidence: Double = 0,
        warnings: [String] = []
    ) {
        self.id = id
        self.sequenceNumber = sequenceNumber
        self.onsetSeconds = onsetSeconds
        self.soundOffsetSeconds = soundOffsetSeconds
        self.exportStartSeconds = exportStartSeconds
        self.exportEndSeconds = exportEndSeconds
        self.onsetFrame = onsetFrame
        self.soundOffsetFrame = soundOffsetFrame
        self.exportStartFrame = exportStartFrame
        self.exportEndFrame = exportEndFrame
        self.onsetDetectionMethod = onsetDetectionMethod
        self.onsetTimeResolutionSeconds = onsetTimeResolutionSeconds
        self.onsetFrequencyWindowSeconds = onsetFrequencyWindowSeconds
        self.tailEndSeconds = tailEndSeconds
        self.tailEndFrame = tailEndFrame
        self.tailDetectionMethod = tailDetectionMethod
        self.tailConfidence = tailConfidence
        self.onsetConfidence = onsetConfidence
        self.offsetConfidence = offsetConfidence
        self.peakDBFS = peakDBFS
        self.estimatedFrequencyHz = estimatedFrequencyHz
        self.pitchConfidence = pitchConfidence
        self.assignedRoadmapItemID = assignedRoadmapItemID
        self.assignedMIDINote = assignedMIDINote
        self.expectedFrequencyHz = expectedFrequencyHz
        self.pitchDeviationCents = pitchDeviationCents
        self.assignmentConfidence = assignmentConfidence
        self.warnings = warnings
    }

    public var durationSeconds: Double { max(0, exportEndSeconds - exportStartSeconds) }
}

public struct LongTakeAnalysis: Codable, Hashable, Sendable {
    public var contract: String
    public var analyzerVersion: String
    public var analyzedAt: Date
    public var sourceFilename: String
    public var sourceDurationSeconds: Double
    public var sampleRate: Double
    public var channelCount: Int
    public var bitDepth: Int?
    public var encoding: String?
    public var referenceChannel: Int
    public var assignmentMode: LongTakeAssignmentMode
    public var anchorRoadmapItemID: UUID?
    public var noiseFloorDBFS: Double
    public var activityThresholdDBFS: Double
    public var tailThresholdDBFS: Double
    public var configuration: LongTakeSegmentationConfiguration
    public var segments: [LongTakeSegment]
    public var warnings: [String]

    public init(
        contract: String = "orgrec.long-take-analysis/v2",
        analyzerVersion: String = LongTakeSegmenter.algorithmVersion,
        analyzedAt: Date = .now,
        sourceFilename: String,
        sourceDurationSeconds: Double,
        sampleRate: Double,
        channelCount: Int,
        bitDepth: Int? = nil,
        encoding: String? = nil,
        referenceChannel: Int,
        assignmentMode: LongTakeAssignmentMode,
        anchorRoadmapItemID: UUID?,
        noiseFloorDBFS: Double,
        activityThresholdDBFS: Double,
        tailThresholdDBFS: Double,
        configuration: LongTakeSegmentationConfiguration,
        segments: [LongTakeSegment],
        warnings: [String] = []
    ) {
        self.contract = contract
        self.analyzerVersion = analyzerVersion
        self.analyzedAt = analyzedAt
        self.sourceFilename = sourceFilename
        self.sourceDurationSeconds = sourceDurationSeconds
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.bitDepth = bitDepth
        self.encoding = encoding
        self.referenceChannel = referenceChannel
        self.assignmentMode = assignmentMode
        self.anchorRoadmapItemID = anchorRoadmapItemID
        self.noiseFloorDBFS = noiseFloorDBFS
        self.activityThresholdDBFS = activityThresholdDBFS
        self.tailThresholdDBFS = tailThresholdDBFS
        self.configuration = configuration
        self.segments = segments
        self.warnings = warnings
    }

    public var assignedSegmentCount: Int { segments.filter { $0.assignedRoadmapItemID != nil }.count }
    public var reviewSegmentCount: Int {
        segments.filter { !$0.warnings.isEmpty || $0.assignmentConfidence < 0.7 }.count
    }
}

public struct LongTakeSourceRecord: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var importedAt: Date
    public var sourceFilename: String
    public var relativeAudioPath: String
    public var sha256: String
    public var fileSize: Int64
    public var sampleRate: Double
    public var channelCount: Int
    public var frameCount: Int64
    public var analysis: LongTakeAnalysis
    public var generatedTakeIDs: [UUID]
    public var sourceWasRecordedInOrgRec: Bool

    public init(
        id: UUID = UUID(),
        importedAt: Date = .now,
        sourceFilename: String,
        relativeAudioPath: String,
        sha256: String,
        fileSize: Int64,
        sampleRate: Double,
        channelCount: Int,
        frameCount: Int64,
        analysis: LongTakeAnalysis,
        generatedTakeIDs: [UUID],
        sourceWasRecordedInOrgRec: Bool
    ) {
        self.id = id
        self.importedAt = importedAt
        self.sourceFilename = sourceFilename
        self.relativeAudioPath = relativeAudioPath
        self.sha256 = sha256
        self.fileSize = fileSize
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.frameCount = frameCount
        self.analysis = analysis
        self.generatedTakeIDs = generatedTakeIDs
        self.sourceWasRecordedInOrgRec = sourceWasRecordedInOrgRec
    }
}

public struct LongTakeSliceProvenance: Codable, Hashable, Sendable {
    public var longTakeID: UUID
    public var sourceRelativeAudioPath: String
    public var sourceSHA256: String
    public var sourceStartSeconds: Double
    public var sourceEndSeconds: Double
    public var detectedOnsetSeconds: Double
    public var detectedSoundOffsetSeconds: Double
    public var sourceStartFrame: Int64?
    public var sourceEndFrame: Int64?
    public var detectedOnsetFrame: Int64?
    public var detectedSoundOffsetFrame: Int64?
    public var assignmentMode: LongTakeAssignmentMode
    public var assignmentConfidence: Double
    public var analyzerVersion: String

    public init(
        longTakeID: UUID,
        sourceRelativeAudioPath: String,
        sourceSHA256: String,
        sourceStartSeconds: Double,
        sourceEndSeconds: Double,
        detectedOnsetSeconds: Double,
        detectedSoundOffsetSeconds: Double,
        sourceStartFrame: Int64? = nil,
        sourceEndFrame: Int64? = nil,
        detectedOnsetFrame: Int64? = nil,
        detectedSoundOffsetFrame: Int64? = nil,
        assignmentMode: LongTakeAssignmentMode,
        assignmentConfidence: Double,
        analyzerVersion: String
    ) {
        self.longTakeID = longTakeID
        self.sourceRelativeAudioPath = sourceRelativeAudioPath
        self.sourceSHA256 = sourceSHA256
        self.sourceStartSeconds = sourceStartSeconds
        self.sourceEndSeconds = sourceEndSeconds
        self.detectedOnsetSeconds = detectedOnsetSeconds
        self.detectedSoundOffsetSeconds = detectedSoundOffsetSeconds
        self.sourceStartFrame = sourceStartFrame
        self.sourceEndFrame = sourceEndFrame
        self.detectedOnsetFrame = detectedOnsetFrame
        self.detectedSoundOffsetFrame = detectedSoundOffsetFrame
        self.assignmentMode = assignmentMode
        self.assignmentConfidence = assignmentConfidence
        self.analyzerVersion = analyzerVersion
    }
}

public actor LongTakeSegmenter {
    public static let algorithmVersion = "orgrec-organ-long-take/3"

    private struct EnergyFrame {
        var levelDBFS: Double
        var peakDBFS: Double
    }

    private struct DetectedRange {
        var onsetIndex: Int
        var offsetIndex: Int
        var tailEndIndex: Int
        var rightCensored: Bool
    }

    private struct OnsetRefinement {
        var frame: Int64
        var confidence: Double
        var timeResolutionSeconds: Double
        var frequencyWindowSeconds: Double
        var method: String
    }

    private struct TailRefinement {
        var frame: Int64
        var confidence: Double
        var method: String
        var overlapsNextOnset: Bool
        var reachedSearchLimit: Bool
    }

    private struct RegionEvidence {
        var range: DetectedRange
        var estimate: PitchEstimate?
    }

    private struct AssignmentDecision {
        var candidate: LongTakePitchCandidate?
        var sequenceConfidence: Double
        var isRetake: Bool
        var skippedPositions: Int
    }

    private let pitchEstimator: PYINPitchEstimator

    public init(pitchEstimator: PYINPitchEstimator = PYINPitchEstimator()) {
        self.pitchEstimator = pitchEstimator
    }

    public func analyze(
        fileURL: URL,
        candidates: [LongTakePitchCandidate] = [],
        anchorRoadmapItemID: UUID? = nil,
        assignmentMode: LongTakeAssignmentMode = .ascendingFromAnchor,
        referenceChannel: Int = 0,
        configuration requestedConfiguration: LongTakeSegmentationConfiguration = LongTakeSegmentationConfiguration()
    ) async throws -> LongTakeAnalysis {
        var configuration = requestedConfiguration
        configuration.hopSeconds = min(0.1, max(0.005, configuration.hopSeconds))
        configuration.minimumNoteDurationSeconds = max(0.2, configuration.minimumNoteDurationSeconds)
        configuration.minimumSilenceDurationSeconds = max(0.12, configuration.minimumSilenceDurationSeconds)
        configuration.onsetPersistenceSeconds = max(configuration.hopSeconds, configuration.onsetPersistenceSeconds)
        configuration.preRollSeconds = max(0, configuration.preRollSeconds)
        configuration.maximumReleaseTailSeconds = max(0, configuration.maximumReleaseTailSeconds)
        configuration.tailSilencePersistenceSeconds = max(configuration.hopSeconds, configuration.tailSilencePersistenceSeconds)
        configuration.stablePitchSampleSeconds = max(0.25, configuration.stablePitchSampleSeconds)

        let envelope = try readEnergyEnvelope(
            fileURL: fileURL,
            referenceChannel: referenceChannel,
            hopSeconds: configuration.hopSeconds
        )
        guard envelope.frames.count >= 4 else {
            throw OrgRecError.unsupportedAudio("The long take is too short for note segmentation.")
        }
        let smoothedLevels = medianSmooth(envelope.frames.map(\.levelDBFS), radius: 2)
        let noiseFloor = quantile(smoothedLevels, probability: 0.1)
        let representativePeak = quantile(smoothedLevels, probability: 0.98)
        let dynamicRange = max(0, representativePeak - noiseFloor)
        guard dynamicRange >= 5 else {
            throw OrgRecError.unsupportedAudio("The recording has less than 5 dB of usable activity above its estimated room-noise floor.")
        }
        let thresholdLift = min(18, max(7, dynamicRange * 0.32))
        let activityThreshold = min(representativePeak - 5, noiseFloor + thresholdLift)
        let releaseThreshold = activityThreshold - min(4, max(2, dynamicRange * 0.08))
        let tailThreshold = min(activityThreshold - 1, noiseFloor + min(8, max(3, dynamicRange * 0.15)))
        let ranges = detectRanges(
            levels: smoothedLevels,
            activityThreshold: activityThreshold,
            releaseThreshold: releaseThreshold,
            tailThreshold: tailThreshold,
            configuration: configuration
        )

        let sortedCandidates = candidates.sorted {
            if $0.midiNote != $1.midiNote { return $0.midiNote < $1.midiNote }
            return $0.label.localizedStandardCompare($1.label) == .orderedAscending
        }
        let orderedCandidates: [LongTakePitchCandidate]
        if let anchorRoadmapItemID,
           let anchorIndex = sortedCandidates.firstIndex(where: { $0.roadmapItemID == anchorRoadmapItemID }) {
            orderedCandidates = Array(sortedCandidates[anchorIndex...])
        } else {
            orderedCandidates = sortedCandidates
        }

        let pitchFile = try AVAudioFile(forReading: fileURL)
        var evidence: [RegionEvidence] = []
        evidence.reserveCapacity(ranges.count)
        for (rangeIndex, range) in ranges.enumerated() {
            let coarseOnset = min(envelope.durationSeconds, Double(range.onsetIndex) * configuration.hopSeconds)
            let offset = min(envelope.durationSeconds, Double(range.offsetIndex) * configuration.hopSeconds)
            let pitchSamples = try readStablePitchSamples(
                file: pitchFile,
                referenceChannel: envelope.referenceChannel,
                onsetSeconds: coarseOnset,
                offsetSeconds: offset,
                maximumDuration: configuration.stablePitchSampleSeconds
            )
            let pitchRate = min(24_000, envelope.sampleRate)
            let resampled = resampleForLongTake(pitchSamples, from: envelope.sampleRate, to: pitchRate)
            let estimate = try await pitchEstimator.estimate(
                samples: resampled,
                sampleRate: pitchRate,
                expectedFrequency: assignmentMode == .ascendingFromAnchor && orderedCandidates.indices.contains(rangeIndex)
                    ? orderedCandidates[rangeIndex].expectedFrequencyHz
                    : nil
            )
            evidence.append(RegionEvidence(range: range, estimate: estimate))
        }

        let decisions: [AssignmentDecision]
        switch assignmentMode {
        case .ascendingFromAnchor:
            decisions = sequenceAssignments(evidence: evidence, candidates: orderedCandidates)
        case .nearestPitch:
            decisions = nearestPitchAssignments(evidence: evidence, candidates: sortedCandidates)
        }

        var segments: [LongTakeSegment] = []
        for (index, item) in evidence.enumerated() {
            let range = item.range
            let estimate = item.estimate
            let decision = decisions.indices.contains(index)
                ? decisions[index]
                : AssignmentDecision(candidate: nil, sequenceConfidence: 0, isRetake: false, skippedPositions: 0)
            let assigned = decision.candidate
            let coarseOnset = min(envelope.durationSeconds, Double(range.onsetIndex) * configuration.hopSeconds)
            let offset = min(envelope.durationSeconds, Double(range.offsetIndex) * configuration.hopSeconds)
            let coarseTailEnd = min(envelope.durationSeconds, Double(range.tailEndIndex) * configuration.hopSeconds)
            let nextOnset = ranges.indices.contains(index + 1)
                ? Double(ranges[index + 1].onsetIndex) * configuration.hopSeconds
                : envelope.durationSeconds
            let lowerOnsetBound = index > 0
                ? min(coarseOnset, Double(ranges[index - 1].offsetIndex) * configuration.hopSeconds)
                : 0
            let onsetRefinement = try refineOnset(
                file: pitchFile,
                referenceChannel: envelope.referenceChannel,
                coarseOnsetSeconds: coarseOnset,
                lowerBoundSeconds: lowerOnsetBound,
                estimatedFrequencyHz: estimate?.frequencyHz ?? assigned?.expectedFrequencyHz,
                globalNoiseFloorDBFS: noiseFloor
            )
            let onsetFrame = max(Int64(0), min(Int64(pitchFile.length), onsetRefinement.frame))
            let onset = Double(onsetFrame) / envelope.sampleRate
            let exportStartFrame = max(
                Int64(0),
                onsetFrame - Int64((configuration.preRollSeconds * envelope.sampleRate).rounded())
            )
            let nextOnsetLimit = max(offset, nextOnset - max(0.005, configuration.preRollSeconds))
            let tailSearchEnd = min(
                envelope.durationSeconds,
                offset + configuration.maximumReleaseTailSeconds,
                nextOnsetLimit
            )
            let tailRefinement = try refineTailEnd(
                file: pitchFile,
                referenceChannel: envelope.referenceChannel,
                onsetSeconds: onset,
                coarseOffsetSeconds: offset,
                coarseTailEndSeconds: coarseTailEnd,
                searchEndSeconds: tailSearchEnd,
                limitedByNextOnset: nextOnsetLimit < min(envelope.durationSeconds, offset + configuration.maximumReleaseTailSeconds) - 0.001,
                estimatedFrequencyHz: estimate?.frequencyHz ?? assigned?.expectedFrequencyHz,
                globalNoiseFloorDBFS: noiseFloor,
                silencePersistenceSeconds: configuration.tailSilencePersistenceSeconds
            )
            let soundOffsetFrame = max(Int64(0), min(Int64(pitchFile.length), Int64((offset * envelope.sampleRate).rounded())))
            let exportEndFrame = max(
                soundOffsetFrame,
                min(Int64(pitchFile.length), tailRefinement.frame)
            )
            let exportStart = Double(exportStartFrame) / envelope.sampleRate
            let deviation = assigned.flatMap { candidate in
                estimate.flatMap { centsDifference(measured: $0.frequencyHz, expected: candidate.expectedFrequencyHz) }
            }
            let localPeak = envelope.frames[range.onsetIndex..<min(envelope.frames.count, max(range.onsetIndex + 1, range.offsetIndex))]
                .map(\.peakDBFS).max() ?? representativePeak
            let onsetConfidence = onsetRefinement.confidence
            let offsetConfidence = range.rightCensored ? 0.2 : min(1, max(0.45, (activityThreshold - smoothedLevels[min(smoothedLevels.count - 1, range.offsetIndex)]) / 12 + 0.55))
            var assignmentConfidence = assigned == nil ? 0 : decision.sequenceConfidence
            if let deviation {
                let foldedDeviation = octaveFoldedCents(deviation)
                assignmentConfidence *= max(0.25, 1 - min(1, foldedDeviation / 140))
            } else if assigned != nil {
                assignmentConfidence *= 0.7
            }
            var warnings: [String] = []
            if range.rightCensored { warnings.append("The note continues to the end of the source recording.") }
            if assigned == nil { warnings.append("No roadmap note could be assigned.") }
            if estimate == nil { warnings.append("Pitch evidence was inconclusive; verify the sequence assignment by ear.") }
            if let deviation, abs(deviation) > 80 {
                warnings.append("Measured pitch differs from the assigned roadmap note by \(Int(deviation.rounded())) cents.")
            }
            if assignmentConfidence < 0.7, assigned != nil {
                warnings.append("The automatic note assignment needs review.")
            }
            if decision.isRetake {
                warnings.append("This region appears to be an alternate take of the preceding roadmap note.")
            }
            if decision.skippedPositions > 0 {
                warnings.append("The sequence skipped \(decision.skippedPositions) expected roadmap position(s) before this region; those pipes may be missing from the recording.")
            }
            if tailRefinement.overlapsNextOnset {
                warnings.append("The release did not reach the local harmonic noise floor before the next note; the exported tail may be incomplete or contaminated.")
            } else if tailRefinement.reachedSearchLimit {
                warnings.append("The release did not reach the local harmonic noise floor within the configured tail window; verify the exported end.")
            }
            if tailRefinement.method.hasSuffix("fallback") {
                warnings.append("The frequency-local tail detector lacked stable harmonic evidence and retained the conservative broadband boundary.")
            }
            if onsetRefinement.method.hasSuffix("fallback") {
                warnings.append("The fine onset detector used the conservative coarse boundary; verify this cut by ear.")
            }
            segments.append(LongTakeSegment(
                sequenceNumber: index + 1,
                onsetSeconds: onset,
                soundOffsetSeconds: offset,
                exportStartSeconds: exportStart,
                exportEndSeconds: Double(exportEndFrame) / envelope.sampleRate,
                onsetFrame: onsetFrame,
                soundOffsetFrame: soundOffsetFrame,
                exportStartFrame: exportStartFrame,
                exportEndFrame: exportEndFrame,
                onsetDetectionMethod: onsetRefinement.method,
                onsetTimeResolutionSeconds: onsetRefinement.timeResolutionSeconds,
                onsetFrequencyWindowSeconds: onsetRefinement.frequencyWindowSeconds,
                tailEndSeconds: Double(tailRefinement.frame) / envelope.sampleRate,
                tailEndFrame: tailRefinement.frame,
                tailDetectionMethod: tailRefinement.method,
                tailConfidence: tailRefinement.confidence,
                onsetConfidence: onsetConfidence,
                offsetConfidence: offsetConfidence,
                peakDBFS: localPeak,
                estimatedFrequencyHz: estimate?.frequencyHz,
                pitchConfidence: estimate?.confidence,
                assignedRoadmapItemID: assigned?.roadmapItemID,
                assignedMIDINote: assigned?.midiNote,
                expectedFrequencyHz: assigned?.expectedFrequencyHz,
                pitchDeviationCents: deviation,
                assignmentConfidence: assignmentConfidence,
                warnings: warnings
            ))
        }

        var warnings: [String] = []
        if ranges.isEmpty {
            warnings.append("No sustained notes were found above the adaptive activity threshold.")
        }
        if assignmentMode == .ascendingFromAnchor, ranges.count > orderedCandidates.count {
            warnings.append("The source contains more notes than the remaining ascending roadmap positions; extra regions were left unassigned.")
        }
        if ranges.count == 1, envelope.durationSeconds >= 2 * configuration.minimumNoteDurationSeconds {
            warnings.append("Only one region was found. Leave at least \(configuration.minimumSilenceDurationSeconds.formatted(.number.precision(.fractionLength(2)))) seconds between notes; legato transitions require manual splitting.")
        }
        let duplicateAssignments = Dictionary(grouping: segments.compactMap(\.assignedRoadmapItemID), by: { $0 })
            .filter { $0.value.count > 1 }.count
        if duplicateAssignments > 0 {
            warnings.append("\(duplicateAssignments) roadmap note assignment(s) are duplicated and require review.")
        }
        return LongTakeAnalysis(
            sourceFilename: fileURL.lastPathComponent,
            sourceDurationSeconds: envelope.durationSeconds,
            sampleRate: envelope.sampleRate,
            channelCount: envelope.channelCount,
            bitDepth: envelope.bitDepth,
            encoding: envelope.encoding,
            referenceChannel: envelope.referenceChannel,
            assignmentMode: assignmentMode,
            anchorRoadmapItemID: anchorRoadmapItemID,
            noiseFloorDBFS: noiseFloor,
            activityThresholdDBFS: activityThreshold,
            tailThresholdDBFS: tailThreshold,
            configuration: configuration,
            segments: segments,
            warnings: warnings
        )
    }

    /// Assigns an ascending recording jointly instead of advancing once per detected
    /// region. The state cursor can remain on the preceding pipe for a retake, jump
    /// over a missing pipe, or consume a region without assigning it.
    private func sequenceAssignments(
        evidence: [RegionEvidence],
        candidates: [LongTakePitchCandidate]
    ) -> [AssignmentDecision] {
        guard evidence.isEmpty == false, candidates.isEmpty == false else {
            return evidence.map { _ in
                AssignmentDecision(candidate: nil, sequenceConfidence: 0, isRetake: false, skippedPositions: 0)
            }
        }

        struct BackPointer {
            var previousCursor: Int
            var candidateIndex: Int?
            var isRetake: Bool
            var skippedPositions: Int
        }

        let stateCount = candidates.count + 1
        var scores = [Double](repeating: .infinity, count: stateCount)
        scores[0] = 0
        var history: [[BackPointer?]] = []
        history.reserveCapacity(evidence.count)

        for item in evidence {
            var next = [Double](repeating: .infinity, count: stateCount)
            var pointers = [BackPointer?](repeating: nil, count: stateCount)
            for cursor in 0..<stateCount where scores[cursor].isFinite {
                let discardScore = scores[cursor] + discardCost(estimate: item.estimate)
                if discardScore < next[cursor] {
                    next[cursor] = discardScore
                    pointers[cursor] = BackPointer(
                        previousCursor: cursor,
                        candidateIndex: nil,
                        isRetake: false,
                        skippedPositions: 0
                    )
                }

                if cursor > 0 {
                    let retryIndex = cursor - 1
                    let retryScore = scores[cursor]
                        + 0.7
                        + assignmentObservationCost(estimate: item.estimate, candidate: candidates[retryIndex])
                    if retryScore < next[cursor] {
                        next[cursor] = retryScore
                        pointers[cursor] = BackPointer(
                            previousCursor: cursor,
                            candidateIndex: retryIndex,
                            isRetake: true,
                            skippedPositions: 0
                        )
                    }
                }

                guard cursor < candidates.count else { continue }
                for candidateIndex in cursor..<candidates.count {
                    let skipped = candidateIndex - cursor
                    let assignmentScore = scores[cursor]
                        + Double(skipped) * 0.8
                        + assignmentObservationCost(estimate: item.estimate, candidate: candidates[candidateIndex])
                    let destinationCursor = candidateIndex + 1
                    if assignmentScore < next[destinationCursor] {
                        next[destinationCursor] = assignmentScore
                        pointers[destinationCursor] = BackPointer(
                            previousCursor: cursor,
                            candidateIndex: candidateIndex,
                            isRetake: false,
                            skippedPositions: skipped
                        )
                    }
                }
            }
            scores = next
            history.append(pointers)
        }

        var cursor = scores.indices.min(by: { scores[$0] < scores[$1] }) ?? 0
        var result = [AssignmentDecision](
            repeating: AssignmentDecision(candidate: nil, sequenceConfidence: 0, isRetake: false, skippedPositions: 0),
            count: evidence.count
        )
        if history.isEmpty == false {
            for evidenceIndex in stride(from: history.count - 1, through: 0, by: -1) {
                guard let pointer = history[evidenceIndex][cursor] else { continue }
                if let candidateIndex = pointer.candidateIndex {
                    let estimate = evidence[evidenceIndex].estimate
                    result[evidenceIndex] = AssignmentDecision(
                        candidate: candidates[candidateIndex],
                        sequenceConfidence: assignmentConfidence(
                            estimate: estimate,
                            candidate: candidates[candidateIndex],
                            structuralPenalty: (pointer.isRetake ? 0.08 : 0) + min(0.2, Double(pointer.skippedPositions) * 0.04)
                        ),
                        isRetake: pointer.isRetake,
                        skippedPositions: pointer.skippedPositions
                    )
                }
                cursor = pointer.previousCursor
            }
        }

        // A stop whose spectral content is not well represented by a single F0 (for
        // example a compound stop) must not lose most of its notes merely because the
        // monophonic estimator abstained. Preserve the documented ascending protocol,
        // but lower confidence so the batch review exposes the limitation.
        let assignedCount = result.filter { $0.candidate != nil }.count
        if assignedCount < max(1, min(evidence.count, candidates.count) / 2) {
            return evidence.indices.map { index in
                guard candidates.indices.contains(index) else {
                    return AssignmentDecision(candidate: nil, sequenceConfidence: 0, isRetake: false, skippedPositions: 0)
                }
                return AssignmentDecision(
                    candidate: candidates[index],
                    sequenceConfidence: evidence[index].estimate == nil ? 0.48 : 0.58,
                    isRetake: false,
                    skippedPositions: 0
                )
            }
        }
        return result
    }

    private func nearestPitchAssignments(
        evidence: [RegionEvidence],
        candidates: [LongTakePitchCandidate]
    ) -> [AssignmentDecision] {
        evidence.map { item in
            guard let frequency = item.estimate?.frequencyHz,
                  let candidate = candidates.min(by: {
                      abs(centsDifference(measured: frequency, expected: $0.expectedFrequencyHz) ?? .infinity)
                          < abs(centsDifference(measured: frequency, expected: $1.expectedFrequencyHz) ?? .infinity)
                  }) else {
                return AssignmentDecision(candidate: nil, sequenceConfidence: 0, isRetake: false, skippedPositions: 0)
            }
            return AssignmentDecision(
                candidate: candidate,
                sequenceConfidence: assignmentConfidence(estimate: item.estimate, candidate: candidate, structuralPenalty: 0),
                isRetake: false,
                skippedPositions: 0
            )
        }
    }

    private func assignmentObservationCost(
        estimate: PitchEstimate?,
        candidate: LongTakePitchCandidate
    ) -> Double {
        guard let estimate,
              let signed = centsDifference(measured: estimate.frequencyHz, expected: candidate.expectedFrequencyHz) else {
            return 2.4
        }
        let raw = abs(signed)
        let folded = octaveFoldedCents(signed)
        let octaves = abs((raw / 1_200).rounded())
        let directCost = raw / 65
        let octaveAwareCost = folded / 50 + octaves * 1.25
        let mismatch = min(8, min(directCost, octaveAwareCost))
        return mismatch * (0.65 + 0.7 * estimate.confidence) - 0.55 * estimate.confidence
    }

    private func discardCost(estimate: PitchEstimate?) -> Double {
        guard let estimate else { return 0.65 }
        return 2.1 + min(1.5, estimate.confidence * 1.8)
    }

    private func assignmentConfidence(
        estimate: PitchEstimate?,
        candidate: LongTakePitchCandidate,
        structuralPenalty: Double
    ) -> Double {
        guard let estimate,
              let signed = centsDifference(measured: estimate.frequencyHz, expected: candidate.expectedFrequencyHz) else {
            return max(0.35, 0.58 - structuralPenalty)
        }
        let match = max(0, 1 - octaveFoldedCents(signed) / 120)
        return min(0.95, max(0.2, 0.52 + 0.43 * estimate.confidence * match - structuralPenalty))
    }

    private func octaveFoldedCents(_ signedCents: Double) -> Double {
        let folded = signedCents - (signedCents / 1_200).rounded() * 1_200
        return abs(folded)
    }

    /// Follows the measured pipe partials into the room decay. Broadband RMS alone
    /// loses a quiet tonal tail as soon as it falls below unrelated room noise.
    private func refineTailEnd(
        file: AVAudioFile,
        referenceChannel: Int,
        onsetSeconds: Double,
        coarseOffsetSeconds: Double,
        coarseTailEndSeconds: Double,
        searchEndSeconds: Double,
        limitedByNextOnset: Bool,
        estimatedFrequencyHz: Double?,
        globalNoiseFloorDBFS: Double,
        silencePersistenceSeconds: Double
    ) throws -> TailRefinement {
        let rate = file.processingFormat.sampleRate
        let fallbackSeconds = max(
            coarseOffsetSeconds,
            min(searchEndSeconds, coarseTailEndSeconds + 0.12)
        )
        let fallbackFrame = max(Int64(0), min(Int64(file.length), Int64((fallbackSeconds * rate).rounded())))
        guard searchEndSeconds > coarseOffsetSeconds + 0.02,
              let fundamental = estimatedFrequencyHz,
              fundamental >= 12,
              fundamental < rate * 0.43 else {
            return TailRefinement(
                frame: fallbackFrame,
                confidence: 0.35,
                method: "adaptive-broadband-tail-fallback",
                overlapsNextOnset: limitedByNextOnset,
                reachedSearchLimit: false
            )
        }

        let baselineLookback = min(0.6, max(0.18, 8 / fundamental + 0.12))
        let sliceStartSeconds = max(0, onsetSeconds - baselineLookback)
        let sliceStartFrame = max(Int64(0), Int64(floor(sliceStartSeconds * rate)))
        let sliceEndFrame = min(Int64(file.length), Int64(ceil(searchEndSeconds * rate)))
        let frameCount = max(Int64(0), sliceEndFrame - sliceStartFrame)
        guard frameCount >= 256, frameCount <= Int64(UInt32.max),
              let buffer = AVAudioPCMBuffer(
                  pcmFormat: file.processingFormat,
                  frameCapacity: AVAudioFrameCount(frameCount)
              ) else {
            return TailRefinement(
                frame: fallbackFrame,
                confidence: 0.3,
                method: "adaptive-broadband-tail-fallback",
                overlapsNextOnset: limitedByNextOnset,
                reachedSearchLimit: false
            )
        }
        file.framePosition = sliceStartFrame
        try file.read(into: buffer, frameCount: buffer.frameCapacity)
        guard buffer.frameLength >= 256,
              let channel = buffer.floatChannelData?[max(0, min(Int(buffer.format.channelCount) - 1, referenceChannel))] else {
            return TailRefinement(
                frame: fallbackFrame,
                confidence: 0.3,
                method: "adaptive-broadband-tail-fallback",
                overlapsNextOnset: limitedByNextOnset,
                reachedSearchLimit: false
            )
        }
        let samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
        let windowSeconds = min(0.09, max(0.012, 4 / fundamental))
        let windowFrames = max(64, Int((windowSeconds * rate).rounded()))
        let hopSeconds = min(0.01, max(0.0025, windowSeconds / 5))
        let hopFrames = max(1, Int((hopSeconds * rate).rounded()))
        guard samples.count >= windowFrames + hopFrames else {
            return TailRefinement(
                frame: fallbackFrame,
                confidence: 0.3,
                method: "adaptive-broadband-tail-fallback",
                overlapsNextOnset: limitedByNextOnset,
                reachedSearchLimit: false
            )
        }

        let broadPrefix = squaredEnergyPrefix(samples)
        let harmonicPrefixes = harmonicCorrelationPrefixes(
            samples: samples,
            sampleRate: rate,
            fundamental: fundamental,
            maximumHarmonic: 6
        )
        guard harmonicPrefixes.isEmpty == false else {
            return TailRefinement(
                frame: fallbackFrame,
                confidence: 0.3,
                method: "adaptive-broadband-tail-fallback",
                overlapsNextOnset: limitedByNextOnset,
                reachedSearchLimit: false
            )
        }
        let starts = Array(stride(from: 0, through: samples.count - windowFrames, by: hopFrames))
        let harmonicLevels = starts.map {
            harmonicLevel(prefixes: harmonicPrefixes, start: $0, end: $0 + windowFrames)
        }
        let broadLevels = starts.map {
            energyLevel(prefix: broadPrefix, start: $0, end: $0 + windowFrames)
        }
        let localOnsetFrame = Int((onsetSeconds * rate).rounded()) - Int(sliceStartFrame)
        let localOffsetFrame = Int((coarseOffsetSeconds * rate).rounded()) - Int(sliceStartFrame)
        var noiseIndices = starts.indices.filter {
            starts[$0] + windowFrames <= max(0, localOnsetFrame - Int(0.015 * rate))
        }
        if noiseIndices.count < 4 {
            noiseIndices = harmonicLevels.indices.sorted { harmonicLevels[$0] < harmonicLevels[$1] }
                .prefix(max(1, harmonicLevels.count / 8)).map { $0 }
        }
        let harmonicBase = quantile(noiseIndices.map { harmonicLevels[$0] }, probability: 0.5)
        let broadBase = max(
            globalNoiseFloorDBFS - 6,
            quantile(noiseIndices.map { broadLevels[$0] }, probability: 0.5)
        )
        let sustainStart = localOnsetFrame + Int(min(0.7, max(0.12, (coarseOffsetSeconds - onsetSeconds) * 0.15)) * rate)
        let sustainEnd = max(sustainStart + windowFrames, localOffsetFrame - Int(0.08 * rate))
        var sustainIndices = starts.indices.filter {
            starts[$0] >= sustainStart && starts[$0] + windowFrames <= sustainEnd
        }
        if sustainIndices.isEmpty {
            sustainIndices = starts.indices.filter { starts[$0] < localOffsetFrame }
        }
        let harmonicActive = quantile(sustainIndices.map { harmonicLevels[$0] }, probability: 0.7)
        let broadActive = quantile(sustainIndices.map { broadLevels[$0] }, probability: 0.7)
        let harmonicContrast = harmonicActive - harmonicBase
        let broadContrast = broadActive - broadBase
        guard harmonicContrast >= 3.5 else {
            return TailRefinement(
                frame: fallbackFrame,
                confidence: min(0.45, max(0.2, broadContrast / 24)),
                method: "adaptive-broadband-tail-fallback",
                overlapsNextOnset: limitedByNextOnset,
                reachedSearchLimit: false
            )
        }

        let tailThreshold = harmonicBase + min(6, max(3, harmonicContrast * 0.15))
        let persistenceSeconds = min(0.6, max(0.4, silencePersistenceSeconds))
        let persistence = max(2, Int(ceil(persistenceSeconds / hopSeconds)))
        let requiredQuiet = max(1, Int(ceil(Double(persistence) * 0.9)))
        let searchStartIndex = starts.firstIndex(where: { $0 >= localOffsetFrame }) ?? starts.count
        var quietStartIndex: Int?
        if searchStartIndex + persistence <= harmonicLevels.count {
            for index in searchStartIndex...(harmonicLevels.count - persistence) {
                let quiet = harmonicLevels[index..<(index + persistence)].filter { $0 <= tailThreshold }.count
                if quiet >= requiredQuiet {
                    quietStartIndex = index
                    break
                }
            }
        }
        if let quietStartIndex {
            let confirmedQuietEnd = starts[min(starts.count - 1, quietStartIndex + persistence - 1)] + windowFrames
            let guardFrames = Int((0.25 * rate).rounded())
            let refinedFrame = min(sliceEndFrame, sliceStartFrame + Int64(confirmedQuietEnd + guardFrames))
            return TailRefinement(
                frame: max(fallbackFrame, refinedFrame),
                confidence: min(0.98, max(0.45, harmonicContrast / 24)),
                method: "frequency-local-harmonic-decay",
                overlapsNextOnset: false,
                reachedSearchLimit: false
            )
        }

        return TailRefinement(
            frame: max(fallbackFrame, sliceEndFrame),
            confidence: min(0.7, max(0.35, harmonicContrast / 30)),
            method: "frequency-local-harmonic-decay-censored",
            overlapsNextOnset: limitedByNextOnset,
            reachedSearchLimit: limitedByNextOnset == false
        )
    }

    private func readEnergyEnvelope(
        fileURL: URL,
        referenceChannel: Int,
        hopSeconds: Double
    ) throws -> (frames: [EnergyFrame], sampleRate: Double, channelCount: Int, bitDepth: Int?, encoding: String?, referenceChannel: Int, durationSeconds: Double) {
        let file = try AVAudioFile(forReading: fileURL)
        let format = file.processingFormat
        let stream = file.fileFormat.streamDescription.pointee
        guard stream.mFormatID == kAudioFormatLinearPCM else {
            throw OrgRecError.unsupportedAudio("Long-take splitting currently requires uncompressed PCM WAV or AIFF audio.")
        }
        guard file.length > 0, format.sampleRate > 0, format.channelCount > 0 else {
            throw OrgRecError.unsupportedAudio("The selected long take has no readable PCM frames.")
        }
        let selectedChannel = max(0, min(Int(format.channelCount) - 1, referenceChannel))
        let hopFrames = max(32, Int((format.sampleRate * hopSeconds).rounded()))
        let bufferFrames = AVAudioFrameCount(hopFrames * 64)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferFrames) else {
            throw OrgRecError.unsupportedAudio("OrgRec could not allocate a long-take analysis buffer.")
        }
        var frames: [EnergyFrame] = []
        frames.reserveCapacity(max(1, Int(ceil(Double(file.length) / Double(hopFrames)))))
        while file.framePosition < file.length {
            try file.read(into: buffer, frameCount: min(bufferFrames, AVAudioFrameCount(file.length - file.framePosition)))
            guard buffer.frameLength > 0, let channel = buffer.floatChannelData?[selectedChannel] else { break }
            var offset = 0
            let available = Int(buffer.frameLength)
            while offset < available {
                let count = min(hopFrames, available - offset)
                var energy: Float = 0
                var peak: Float = 0
                vDSP_svesq(channel.advanced(by: offset), 1, &energy, vDSP_Length(count))
                vDSP_maxmgv(channel.advanced(by: offset), 1, &peak, vDSP_Length(count))
                let rms = sqrt(Double(energy) / Double(max(1, count)))
                frames.append(EnergyFrame(
                    levelDBFS: 20 * log10(max(rms, 0.000_001)),
                    peakDBFS: 20 * log10(max(Double(peak), 0.000_001))
                ))
                offset += count
            }
        }
        return (
            frames,
            format.sampleRate,
            Int(format.channelCount),
            Int(stream.mBitsPerChannel),
            (stream.mFormatFlags & kAudioFormatFlagIsFloat) != 0 ? "linear PCM floating point" : "linear PCM integer",
            selectedChannel,
            Double(file.length) / format.sampleRate
        )
    }

    private func detectRanges(
        levels: [Double],
        activityThreshold: Double,
        releaseThreshold: Double,
        tailThreshold: Double,
        configuration: LongTakeSegmentationConfiguration
    ) -> [DetectedRange] {
        let onsetFrames = max(1, Int(ceil(configuration.onsetPersistenceSeconds / configuration.hopSeconds)))
        let silenceFrames = max(1, Int(ceil(configuration.minimumSilenceDurationSeconds / configuration.hopSeconds)))
        let minimumNoteFrames = max(1, Int(ceil(configuration.minimumNoteDurationSeconds / configuration.hopSeconds)))
        let tailFrames = max(1, Int(ceil(configuration.tailSilencePersistenceSeconds / configuration.hopSeconds)))
        let maximumTailFrames = max(0, Int(ceil(configuration.maximumReleaseTailSeconds / configuration.hopSeconds)))
        var result: [DetectedRange] = []
        var cursor = 0
        while cursor + onsetFrames <= levels.count {
            guard let onset = persistentIndex(
                levels: levels,
                startingAt: cursor,
                count: onsetFrames,
                predicate: { $0 >= activityThreshold }
            ) else { break }
            var belowCount = 0
            var offset: Int?
            var index = onset + onsetFrames
            while index < levels.count {
                if levels[index] < releaseThreshold {
                    belowCount += 1
                    if belowCount >= silenceFrames {
                        offset = index - belowCount + 1
                        break
                    }
                } else {
                    belowCount = 0
                }
                index += 1
            }
            let resolvedOffset = offset ?? levels.count
            if resolvedOffset - onset >= minimumNoteFrames {
                let maximumTailEnd = min(levels.count, resolvedOffset + maximumTailFrames)
                let tailStart = min(levels.count, resolvedOffset)
                let tail = persistentIndex(
                    levels: levels,
                    startingAt: tailStart,
                    endingBefore: maximumTailEnd,
                    count: tailFrames,
                    predicate: { $0 <= tailThreshold }
                ) ?? maximumTailEnd
                result.append(DetectedRange(
                    onsetIndex: onset,
                    offsetIndex: resolvedOffset,
                    tailEndIndex: min(levels.count, tail + tailFrames),
                    rightCensored: offset == nil
                ))
            }
            cursor = max(onset + onsetFrames, offset.map { $0 + silenceFrames } ?? levels.count)
        }
        return result
    }

    private func persistentIndex(
        levels: [Double],
        startingAt start: Int,
        endingBefore requestedEnd: Int? = nil,
        count: Int,
        predicate: (Double) -> Bool
    ) -> Int? {
        let end = min(levels.count, requestedEnd ?? levels.count)
        guard count > 0, start >= 0, start + count <= end else { return nil }
        var run = 0
        for index in start..<end {
            if predicate(levels[index]) {
                run += 1
                if run >= count { return index - count + 1 }
            } else {
                run = 0
            }
        }
        return nil
    }

    /// Refines the 20 ms segmentation boundary against the original samples. Pipe-organ
    /// attacks vary from a broadband chiff to a slowly emerging low fundamental, so the
    /// decision combines broadband, split-band and pitch-harmonic evidence rather than
    /// relying on a fixed silence threshold.
    private func refineOnset(
        file: AVAudioFile,
        referenceChannel: Int,
        coarseOnsetSeconds: Double,
        lowerBoundSeconds: Double,
        estimatedFrequencyHz: Double?,
        globalNoiseFloorDBFS: Double
    ) throws -> OnsetRefinement {
        let rate = file.processingFormat.sampleRate
        let usableFrequency = estimatedFrequencyHz.flatMap { frequency in
            (frequency >= 12 && frequency < rate * 0.45) ? frequency : nil
        }
        let lookbackSeconds = min(1.25, max(0.35, usableFrequency.map { 12 / $0 + 0.25 } ?? 0.65))
        let sliceStartSeconds = max(lowerBoundSeconds, coarseOnsetSeconds - lookbackSeconds)
        let sliceEndSeconds = min(Double(file.length) / rate, coarseOnsetSeconds + 0.25)
        let sliceStartFrame = max(Int64(0), Int64(floor(sliceStartSeconds * rate)))
        let sliceEndFrame = min(Int64(file.length), Int64(ceil(sliceEndSeconds * rate)))
        let sliceFrameCount = max(Int64(0), sliceEndFrame - sliceStartFrame)
        guard sliceFrameCount >= 64,
              sliceFrameCount <= Int64(UInt32.max),
              let buffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat,
                frameCapacity: AVAudioFrameCount(sliceFrameCount)
              ) else {
            return conservativeOnsetFallback(
                file: file,
                coarseOnsetSeconds: coarseOnsetSeconds,
                lowerBoundSeconds: lowerBoundSeconds,
                frequencyWindowSeconds: 0.02
            )
        }
        file.framePosition = AVAudioFramePosition(sliceStartFrame)
        try file.read(into: buffer, frameCount: buffer.frameCapacity)
        guard buffer.frameLength >= 64,
              let channel = buffer.floatChannelData?[max(0, min(Int(buffer.format.channelCount) - 1, referenceChannel))] else {
            return conservativeOnsetFallback(
                file: file,
                coarseOnsetSeconds: coarseOnsetSeconds,
                lowerBoundSeconds: lowerBoundSeconds,
                frequencyWindowSeconds: 0.02
            )
        }
        let samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
        let frequencyWindowSeconds = min(0.045, max(0.0025, usableFrequency.map { 2.5 / $0 } ?? 0.008))
        let windowFrames = max(32, Int((frequencyWindowSeconds * rate).rounded()))
        let hopSeconds = min(0.001, max(0.000_25, frequencyWindowSeconds / 8))
        let hopFrames = max(1, Int((hopSeconds * rate).rounded()))
        guard samples.count > windowFrames + hopFrames else {
            return conservativeOnsetFallback(
                file: file,
                coarseOnsetSeconds: coarseOnsetSeconds,
                lowerBoundSeconds: lowerBoundSeconds,
                frequencyWindowSeconds: frequencyWindowSeconds
            )
        }

        let splitCutoff = min(5_000.0, max(90.0, (usableFrequency ?? 500) * 2.5))
        let smoothing = exp(-2 * Double.pi * splitCutoff / rate)
        var lowSamples = [Float](repeating: 0, count: samples.count)
        var highSamples = [Float](repeating: 0, count: samples.count)
        var lowState = 0.0
        for index in samples.indices {
            lowState = (1 - smoothing) * Double(samples[index]) + smoothing * lowState
            lowSamples[index] = Float(lowState)
            highSamples[index] = samples[index] - Float(lowState)
        }
        let broadEnergy = squaredEnergyPrefix(samples)
        let lowEnergy = squaredEnergyPrefix(lowSamples)
        let highEnergy = squaredEnergyPrefix(highSamples)
        let harmonicPrefixes = harmonicCorrelationPrefixes(
            samples: samples,
            sampleRate: rate,
            fundamental: usableFrequency
        )
        let featureStarts = Array(stride(from: 0, through: samples.count - windowFrames, by: hopFrames))
        var broadLevels: [Double] = []
        var lowLevels: [Double] = []
        var highLevels: [Double] = []
        var harmonicLevels: [Double] = []
        broadLevels.reserveCapacity(featureStarts.count)
        lowLevels.reserveCapacity(featureStarts.count)
        highLevels.reserveCapacity(featureStarts.count)
        harmonicLevels.reserveCapacity(featureStarts.count)
        for start in featureStarts {
            let end = start + windowFrames
            broadLevels.append(energyLevel(prefix: broadEnergy, start: start, end: end))
            lowLevels.append(energyLevel(prefix: lowEnergy, start: start, end: end))
            highLevels.append(energyLevel(prefix: highEnergy, start: start, end: end))
            harmonicLevels.append(harmonicLevel(prefixes: harmonicPrefixes, start: start, end: end))
        }

        let coarseLocalFrame = max(0, min(samples.count - 1, Int((coarseOnsetSeconds * rate).rounded()) - Int(sliceStartFrame)))
        let safeNoiseEndFrame = max(windowFrames, coarseLocalFrame - Int((0.12 * rate).rounded()))
        var noiseIndices = featureStarts.indices.filter { featureStarts[$0] + windowFrames <= safeNoiseEndFrame }
        if noiseIndices.count < 6 {
            let fallbackCount = min(featureStarts.count, max(1, Int(ceil(Double(featureStarts.count) * 0.2))))
            noiseIndices = Array(0..<fallbackCount)
        }
        let activeEndFrame = min(samples.count, coarseLocalFrame + Int((0.18 * rate).rounded()))
        var activeIndices = featureStarts.indices.filter {
            featureStarts[$0] >= max(0, coarseLocalFrame - windowFrames / 2) && featureStarts[$0] < activeEndFrame
        }
        if activeIndices.isEmpty { activeIndices = [min(featureStarts.count - 1, coarseLocalFrame / hopFrames)] }

        func levels(_ values: [Double], at indices: [Int]) -> [Double] {
            indices.map { values[max(0, min(values.count - 1, $0))] }
        }
        let broadBase = max(globalNoiseFloorDBFS - 6, quantile(levels(broadLevels, at: noiseIndices), probability: 0.35))
        let lowBase = quantile(levels(lowLevels, at: noiseIndices), probability: 0.35)
        let highBase = quantile(levels(highLevels, at: noiseIndices), probability: 0.35)
        let harmonicBase = quantile(levels(harmonicLevels, at: noiseIndices), probability: 0.35)
        let broadActive = quantile(levels(broadLevels, at: activeIndices), probability: 0.75)
        let lowActive = quantile(levels(lowLevels, at: activeIndices), probability: 0.75)
        let highActive = quantile(levels(highLevels, at: activeIndices), probability: 0.75)
        let harmonicActive = quantile(levels(harmonicLevels, at: activeIndices), probability: 0.75)

        func threshold(base: Double, active: Double, minimumLift: Double = 2.5) -> Double {
            let contrast = active - base
            guard contrast > minimumLift + 0.5 else { return base + minimumLift }
            return min(active - 1, base + min(8, max(minimumLift, contrast * 0.24)))
        }
        let broadThreshold = threshold(base: broadBase, active: broadActive)
        let lowThreshold = threshold(base: lowBase, active: lowActive)
        let highThreshold = threshold(base: highBase, active: highActive)
        let harmonicThreshold = threshold(base: harmonicBase, active: harmonicActive, minimumLift: 3)
        var activity = [Bool](repeating: false, count: featureStarts.count)
        for index in featureStarts.indices {
            let spectralVotes = (lowLevels[index] >= lowThreshold ? 1 : 0)
                + (highLevels[index] >= highThreshold ? 1 : 0)
                + (harmonicLevels[index] >= harmonicThreshold ? 1 : 0)
            activity[index] = broadLevels[index] >= broadThreshold
                && (spectralVotes > 0 || broadLevels[index] >= broadThreshold + 2)
        }
        let persistenceSeconds = min(0.015, max(0.004, usableFrequency.map { 1.5 / $0 } ?? 0.008))
        let persistenceFrames = max(2, Int(ceil(persistenceSeconds / hopSeconds)))
        let searchEnd = min(featureStarts.count, max(1, (coarseLocalFrame + Int(0.12 * rate)) / hopFrames))
        let maximumLeadSeconds = min(0.3, max(0.055, usableFrequency.map { 8 / $0 + 0.03 } ?? 0.12))
        let earliestConnectedFrame = max(0, coarseLocalFrame - Int((maximumLeadSeconds * rate).rounded()))
        let searchStart = featureStarts.firstIndex(where: { $0 >= earliestConnectedFrame }) ?? 0
        let coarseFeatureIndex = min(featureStarts.count - 1, max(searchStart, coarseLocalFrame / hopFrames))
        let maximumGapSeconds = min(0.045, max(0.012, usableFrequency.map { 2 / $0 } ?? 0.025))
        let maximumGapFrames = max(1, Int(ceil(maximumGapSeconds / hopSeconds)))
        let requiredActive = max(1, Int(ceil(Double(persistenceFrames) * 0.8)))
        var anchorIndex: Int?
        if searchEnd - searchStart >= persistenceFrames {
            for index in searchStart...(searchEnd - persistenceFrames) {
                let persistent = activity[index..<(index + persistenceFrames)].filter({ $0 }).count >= requiredActive
                let bridgeEnd = max(index + persistenceFrames, coarseFeatureIndex)
                var longestQuietRun = 0
                var quietRun = 0
                if index < bridgeEnd {
                    for bridgeIndex in index...min(activity.count - 1, bridgeEnd) {
                        if activity[bridgeIndex] {
                            quietRun = 0
                        } else {
                            quietRun += 1
                            longestQuietRun = max(longestQuietRun, quietRun)
                        }
                    }
                }
                if persistent && longestQuietRun <= maximumGapFrames {
                    anchorIndex = index
                    break
                }
            }
        }
        guard let anchorIndex else {
            return conservativeOnsetFallback(
                file: file,
                coarseOnsetSeconds: coarseOnsetSeconds,
                lowerBoundSeconds: lowerBoundSeconds,
                frequencyWindowSeconds: frequencyWindowSeconds
            )
        }

        // Resolve the long spectral window to a sub-millisecond envelope boundary. The
        // lower precursor threshold preserves slow speech transients and low-pipe bloom.
        let microWindowSeconds = min(0.004, max(0.001, usableFrequency.map { 0.5 / $0 } ?? 0.0015))
        let microWindowFrames = max(8, Int((microWindowSeconds * rate).rounded()))
        let microHopFrames = max(1, Int((0.000_25 * rate).rounded()))
        let microStarts = Array(stride(from: 0, through: max(0, samples.count - microWindowFrames), by: microHopFrames))
        let microLevels = microStarts.map {
            energyLevel(prefix: broadEnergy, start: $0, end: $0 + microWindowFrames)
        }
        let microLowLevels = microStarts.map {
            energyLevel(prefix: lowEnergy, start: $0, end: $0 + microWindowFrames)
        }
        let microHighLevels = microStarts.map {
            energyLevel(prefix: highEnergy, start: $0, end: $0 + microWindowFrames)
        }
        let microHarmonicLevels = microStarts.map {
            harmonicLevel(prefixes: harmonicPrefixes, start: $0, end: $0 + microWindowFrames)
        }
        let microNoise = microStarts.indices.filter { microStarts[$0] + microWindowFrames <= safeNoiseEndFrame }
        let resolvedMicroNoise = microNoise.isEmpty ? [0] : microNoise
        let microBase = max(
            globalNoiseFloorDBFS - 6,
            quantile(levels(microLevels, at: resolvedMicroNoise), probability: 0.35)
        )
        let microLowBase = quantile(levels(microLowLevels, at: resolvedMicroNoise), probability: 0.35)
        let microHighBase = quantile(levels(microHighLevels, at: resolvedMicroNoise), probability: 0.35)
        let microHarmonicBase = quantile(levels(microHarmonicLevels, at: resolvedMicroNoise), probability: 0.35)
        let microActiveIndices = microStarts.indices.filter {
            microStarts[$0] >= max(0, coarseLocalFrame - microWindowFrames) && microStarts[$0] < activeEndFrame
        }
        let resolvedMicroActive = microActiveIndices.isEmpty
            ? [min(microLevels.count - 1, coarseLocalFrame / microHopFrames)]
            : microActiveIndices
        let microActive = quantile(
            levels(microLevels, at: resolvedMicroActive),
            probability: 0.75
        )
        let microLowActive = quantile(levels(microLowLevels, at: resolvedMicroActive), probability: 0.75)
        let microHighActive = quantile(levels(microHighLevels, at: resolvedMicroActive), probability: 0.75)
        let microHarmonicActive = quantile(levels(microHarmonicLevels, at: resolvedMicroActive), probability: 0.75)
        let microStrongThreshold = threshold(base: microBase, active: microActive, minimumLift: 2.5)
        let microLowThreshold = threshold(base: microLowBase, active: microLowActive, minimumLift: 2.5)
        let microHighThreshold = threshold(base: microHighBase, active: microHighActive, minimumLift: 2.5)
        let microHarmonicThreshold = threshold(base: microHarmonicBase, active: microHarmonicActive, minimumLift: 3)
        let microPrecursorThreshold = min(microStrongThreshold - 0.75, microBase + 1.5)
        let microHighPrecursorThreshold = min(microHighThreshold - 0.75, microHighBase + 1.5)
        let strongActivity = microStarts.indices.map { index in
            microLevels[index] >= microStrongThreshold
                && (microLowLevels[index] >= microLowThreshold
                    || microHighLevels[index] >= microHighThreshold
                    || microHarmonicLevels[index] >= microHarmonicThreshold)
        }
        let precursorActivity = microStarts.indices.map { index in
            microLevels[index] >= microPrecursorThreshold
                && microHighLevels[index] >= microHighPrecursorThreshold
        }
        let microSearchStartFrame = max(0, featureStarts[anchorIndex] - windowFrames)
        let microSearchEndFrame = min(samples.count, coarseLocalFrame + Int(0.12 * rate))
        let microSearchStart = min(microStarts.count - 1, microSearchStartFrame / microHopFrames)
        let microSearchEnd = min(microStarts.count, max(microSearchStart + 1, microSearchEndFrame / microHopFrames))
        let strongPersistence = max(2, Int(ceil(max(0.002, persistenceSeconds / 2) * rate / Double(microHopFrames))))
        let strongRequired = max(1, Int(ceil(Double(strongPersistence) * 0.8)))
        var strongIndex: Int?
        if microSearchEnd - microSearchStart >= strongPersistence {
            for index in microSearchStart...(microSearchEnd - strongPersistence) {
                let activeCount = strongActivity[index..<(index + strongPersistence)].filter { $0 }.count
                if activeCount >= strongRequired {
                    strongIndex = index
                    break
                }
            }
        }
        let resolvedStrongIndex = strongIndex ?? min(microStarts.count - 1, featureStarts[anchorIndex] / microHopFrames)
        let quietDuration = min(0.012, max(0.004, usableFrequency.map { 0.35 / $0 } ?? 0.006))
        let quietCount = max(2, Int(ceil(quietDuration * rate / Double(microHopFrames))))
        let precursorLookbackSeconds = min(0.08, max(0.05, frequencyWindowSeconds * 1.5))
        let precursorSearchFloor = max(
            microSearchStart,
            resolvedStrongIndex - Int(ceil(precursorLookbackSeconds * rate / Double(microHopFrames)))
        )
        var precursorIndex = resolvedStrongIndex
        var quietRun = 0
        if resolvedStrongIndex > precursorSearchFloor {
            for index in stride(from: resolvedStrongIndex - 1, through: precursorSearchFloor, by: -1) {
                if precursorActivity[index] == false {
                    quietRun += 1
                    if quietRun >= quietCount {
                        precursorIndex = min(resolvedStrongIndex, index + quietCount)
                        break
                    }
                } else {
                    quietRun = 0
                    precursorIndex = index
                }
            }
        }
        // A slow flue-pipe bloom can precede the pitch-locked boundary without much
        // high-frequency speech. Accept an earlier broadband precursor only when the
        // rise remains present for a much longer interval; this rejects periodic room
        // tone and isolated key/action clicks.
        let broadPersistence = max(3, Int(ceil(0.018 * rate / Double(microHopFrames))))
        let broadRequired = max(1, Int(ceil(Double(broadPersistence) * 0.85)))
        if resolvedStrongIndex - precursorSearchFloor >= broadPersistence {
            for index in precursorSearchFloor...resolvedStrongIndex {
                let end = min(microLevels.count, index + broadPersistence)
                guard end - index == broadPersistence else { break }
                let activeCount = microLevels[index..<end].filter { $0 >= microPrecursorThreshold }.count
                if activeCount >= broadRequired {
                    precursorIndex = min(precursorIndex, index)
                    break
                }
            }
        }
        var refinedLocalFrame = microStarts[max(0, min(microStarts.count - 1, precursorIndex))]
        let zeroCrossingLookback = max(1, Int(min(0.002, usableFrequency.map { 0.2 / $0 } ?? 0.002) * rate))
        let minimumLocalFrame = max(0, Int((lowerBoundSeconds * rate).rounded()) - Int(sliceStartFrame))
        if refinedLocalFrame > minimumLocalFrame {
            let crossingStart = max(minimumLocalFrame + 1, refinedLocalFrame - zeroCrossingLookback)
            if crossingStart <= refinedLocalFrame {
                for index in stride(from: refinedLocalFrame, through: crossingStart, by: -1) {
                    if samples[index - 1] == 0 || samples[index - 1].sign != samples[index].sign {
                        refinedLocalFrame = index
                        break
                    }
                }
            }
        }
        let contrast = max(
            broadActive - broadBase,
            lowActive - lowBase,
            highActive - highBase,
            harmonicActive - harmonicBase
        )
        return OnsetRefinement(
            frame: sliceStartFrame + Int64(refinedLocalFrame),
            confidence: min(1, max(0.35, (contrast - 2) / 18)),
            timeResolutionSeconds: Double(microHopFrames) / rate,
            frequencyWindowSeconds: frequencyWindowSeconds,
            method: "adaptive-multiband-harmonic-onset"
        )
    }

    private func conservativeOnsetFallback(
        file: AVAudioFile,
        coarseOnsetSeconds: Double,
        lowerBoundSeconds: Double,
        frequencyWindowSeconds: Double
    ) -> OnsetRefinement {
        let rate = file.processingFormat.sampleRate
        let conservativeSeconds = max(lowerBoundSeconds, coarseOnsetSeconds - frequencyWindowSeconds - 0.01)
        return OnsetRefinement(
            frame: max(Int64(0), min(Int64(file.length), Int64(floor(conservativeSeconds * rate)))),
            confidence: 0.25,
            timeResolutionSeconds: frequencyWindowSeconds,
            frequencyWindowSeconds: frequencyWindowSeconds,
            method: "adaptive-multiband-harmonic-onset-fallback"
        )
    }

    private func squaredEnergyPrefix(_ samples: [Float]) -> [Double] {
        var prefix = [Double](repeating: 0, count: samples.count + 1)
        for index in samples.indices {
            let value = Double(samples[index])
            prefix[index + 1] = prefix[index] + value * value
        }
        return prefix
    }

    private func energyLevel(prefix: [Double], start: Int, end: Int) -> Double {
        let boundedStart = max(0, min(prefix.count - 1, start))
        let boundedEnd = max(boundedStart + 1, min(prefix.count - 1, end))
        let meanSquare = max(1e-12, (prefix[boundedEnd] - prefix[boundedStart]) / Double(boundedEnd - boundedStart))
        return 10 * log10(meanSquare)
    }

    private func harmonicCorrelationPrefixes(
        samples: [Float],
        sampleRate: Double,
        fundamental: Double?,
        maximumHarmonic: Int = 3
    ) -> [(cosine: [Double], sine: [Double])] {
        guard let fundamental else { return [] }
        return (1...max(1, maximumHarmonic)).compactMap { harmonic in
            let frequency = fundamental * Double(harmonic)
            guard frequency < sampleRate * 0.45 else { return nil }
            let rotation = 2 * Double.pi * frequency / sampleRate
            let rotationCosine = cos(rotation)
            let rotationSine = sin(rotation)
            var oscillatorCosine = 1.0
            var oscillatorSine = 0.0
            var cosinePrefix = [Double](repeating: 0, count: samples.count + 1)
            var sinePrefix = [Double](repeating: 0, count: samples.count + 1)
            for index in samples.indices {
                let value = Double(samples[index])
                cosinePrefix[index + 1] = cosinePrefix[index] + value * oscillatorCosine
                sinePrefix[index + 1] = sinePrefix[index] + value * oscillatorSine
                let nextCosine = oscillatorCosine * rotationCosine - oscillatorSine * rotationSine
                oscillatorSine = oscillatorSine * rotationCosine + oscillatorCosine * rotationSine
                oscillatorCosine = nextCosine
            }
            return (cosinePrefix, sinePrefix)
        }
    }

    private func harmonicLevel(
        prefixes: [(cosine: [Double], sine: [Double])],
        start: Int,
        end: Int
    ) -> Double {
        guard prefixes.isEmpty == false, end > start else { return -120 }
        var magnitudeSquared = 0.0
        for prefix in prefixes {
            let real = prefix.cosine[end] - prefix.cosine[start]
            let imaginary = prefix.sine[end] - prefix.sine[start]
            magnitudeSquared += real * real + imaginary * imaginary
        }
        let amplitude = 2 * sqrt(magnitudeSquared) / Double(end - start)
        return 20 * log10(max(1e-6, amplitude))
    }

    private func readStablePitchSamples(
        file: AVAudioFile,
        referenceChannel: Int,
        onsetSeconds: Double,
        offsetSeconds: Double,
        maximumDuration: Double
    ) throws -> [Float] {
        let rate = file.processingFormat.sampleRate
        let activeDuration = max(0, offsetSeconds - onsetSeconds)
        let settle = min(0.75, max(0.12, activeDuration * 0.18))
        let start = min(offsetSeconds, onsetSeconds + settle)
        let available = max(0, offsetSeconds - start - 0.1)
        let duration = min(maximumDuration, max(0.25, available))
        let startFrame = max(0, min(file.length, AVAudioFramePosition((start * rate).rounded())))
        let frameCount = max(1, min(file.length - startFrame, AVAudioFramePosition((duration * rate).rounded())))
        file.framePosition = startFrame
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: file.processingFormat,
            frameCapacity: AVAudioFrameCount(min(Int64(UInt32.max), frameCount))
        ) else { return [] }
        try file.read(into: buffer, frameCount: buffer.frameCapacity)
        guard let channel = buffer.floatChannelData?[referenceChannel] else { return [] }
        return Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
    }
}

public struct LongTakeExportResult: Codable, Hashable, Sendable {
    public var segmentID: UUID
    public var destinationURL: URL
    public var frameCount: Int64
    public var sampleRate: Double
    public var channelCount: Int
}

public actor LongTakeAudioExporter {
    public init() {}

    public func export(
        sourceURL: URL,
        segments: [LongTakeSegment],
        destinations: [UUID: URL]
    ) throws -> [LongTakeExportResult] {
        let source = try AVAudioFile(forReading: sourceURL)
        let rate = source.processingFormat.sampleRate
        let bufferCapacity: AVAudioFrameCount = 65_536
        guard let buffer = AVAudioPCMBuffer(pcmFormat: source.processingFormat, frameCapacity: bufferCapacity) else {
            throw OrgRecError.unsupportedAudio("OrgRec could not allocate an audio-splitting buffer.")
        }
        var results: [LongTakeExportResult] = []
        for segment in segments {
            guard let destination = destinations[segment.id] else { continue }
            guard FileManager.default.fileExists(atPath: destination.path) == false else {
                throw OrgRecError.invalidProject("A split-note destination already exists: \(destination.lastPathComponent)")
            }
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            let requestedStartFrame: AVAudioFramePosition
            if let exactStartFrame = segment.exportStartFrame {
                requestedStartFrame = AVAudioFramePosition(exactStartFrame)
            } else {
                requestedStartFrame = AVAudioFramePosition((segment.exportStartSeconds * rate).rounded())
            }
            let requestedEndFrame: AVAudioFramePosition
            if let exactEndFrame = segment.exportEndFrame {
                requestedEndFrame = AVAudioFramePosition(exactEndFrame)
            } else {
                requestedEndFrame = AVAudioFramePosition((segment.exportEndSeconds * rate).rounded())
            }
            let startFrame = max(0, min(source.length, requestedStartFrame))
            let endFrame = max(startFrame, min(source.length, requestedEndFrame))
            source.framePosition = startFrame
            let output = try AVAudioFile(
                forWriting: destination,
                settings: source.fileFormat.settings,
                commonFormat: source.processingFormat.commonFormat,
                interleaved: source.processingFormat.isInterleaved
            )
            var remaining = endFrame - startFrame
            while remaining > 0 {
                let requested = AVAudioFrameCount(min(Int64(bufferCapacity), remaining))
                try source.read(into: buffer, frameCount: requested)
                guard buffer.frameLength > 0 else { break }
                try output.write(from: buffer)
                remaining -= Int64(buffer.frameLength)
            }
            let written = (endFrame - startFrame) - remaining
            results.append(LongTakeExportResult(
                segmentID: segment.id,
                destinationURL: destination,
                frameCount: written,
                sampleRate: rate,
                channelCount: Int(source.processingFormat.channelCount)
            ))
        }
        return results
    }
}

private func medianSmooth(_ values: [Double], radius: Int) -> [Double] {
    guard radius > 0, values.count > 2 else { return values }
    return values.indices.map { index in
        let lower = max(0, index - radius)
        let upper = min(values.count, index + radius + 1)
        return quantile(Array(values[lower..<upper]), probability: 0.5)
    }
}

private func quantile(_ values: [Double], probability: Double) -> Double {
    let sorted = values.sorted()
    guard sorted.isEmpty == false else { return -120 }
    let position = min(1, max(0, probability)) * Double(sorted.count - 1)
    let lower = Int(floor(position))
    let upper = Int(ceil(position))
    guard lower != upper else { return sorted[lower] }
    return sorted[lower] + (sorted[upper] - sorted[lower]) * (position - Double(lower))
}

private func resampleForLongTake(_ samples: [Float], from inputRate: Double, to outputRate: Double) -> [Float] {
    guard !samples.isEmpty, abs(inputRate - outputRate) > 0.5 else { return samples }
    let outputCount = max(1, Int(Double(samples.count) * outputRate / inputRate))
    if let inputFormat = AVAudioFormat(standardFormatWithSampleRate: inputRate, channels: 1),
       let outputFormat = AVAudioFormat(standardFormatWithSampleRate: outputRate, channels: 1),
       let converter = AVAudioConverter(from: inputFormat, to: outputFormat),
       let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: AVAudioFrameCount(samples.count)),
       let outputBuffer = AVAudioPCMBuffer(
           pcmFormat: outputFormat,
           frameCapacity: AVAudioFrameCount(max(samples.count, outputCount + 128))
       ),
       let inputChannel = inputBuffer.floatChannelData?[0] {
        inputBuffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { pointer in
            if let base = pointer.baseAddress { inputChannel.update(from: base, count: samples.count) }
        }
        if (try? converter.convert(to: outputBuffer, from: inputBuffer)) != nil,
           let outputChannel = outputBuffer.floatChannelData?[0], outputBuffer.frameLength > 0 {
            return Array(UnsafeBufferPointer(start: outputChannel, count: Int(outputBuffer.frameLength)))
        }
    }
    let ratio = inputRate / outputRate
    return (0..<outputCount).map { index in
        let position = Double(index) * ratio
        let lower = min(samples.count - 1, Int(position))
        let upper = min(samples.count - 1, lower + 1)
        let fraction = Float(position - Double(lower))
        return samples[lower] * (1 - fraction) + samples[upper] * fraction
    }
}
