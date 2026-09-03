import Foundation

/// A single documented organ-stop footage used as a nominal pitch prior.
///
/// Footage is organological documentation, not a measured pipe length or proof
/// of tuning. Compound registrations deliberately do not parse as one footage.
public struct OrganFootage: Codable, Hashable, Sendable {
    public enum ParseError: Error, Equatable, Sendable {
        case empty
        case compound
        case invalid
        case nonPositive
    }

    public let feet: Double

    public init(feet: Double) throws {
        guard feet.isFinite, feet > 0 else { throw ParseError.nonPositive }
        self.feet = feet
    }

    public init(parsing rawValue: String) throws {
        let original = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard original.isEmpty == false else { throw ParseError.empty }

        var value = original.lowercased()
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .replacingOccurrences(of: "’", with: "'")

        let compoundSeparators = ["+", "&", ";", "|", "–", "—"]
        let compoundWords = [" and ", " und ", " et ", " to "]
        if compoundSeparators.contains(where: value.contains)
            || compoundWords.contains(where: value.contains)
            || value.filter({ $0 == "′" || $0 == "'" }).count > 1 {
            throw ParseError.compound
        }

        value = value.replacingOccurrences(
            of: #"\s*(?:′|'|ft\.?|feet|foot)\s*$"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.isEmpty == false else { throw ParseError.invalid }

        if value.range(of: #"[^0-9\s,./\-½⅓⅔¼¾⅕⅖⅗⅘⅙⅚⅛⅜⅝⅞]"#, options: .regularExpression) != nil {
            throw ParseError.invalid
        }

        let vulgarFractions: [Character: Double] = [
            "½": 1.0 / 2, "⅓": 1.0 / 3, "⅔": 2.0 / 3,
            "¼": 1.0 / 4, "¾": 3.0 / 4,
            "⅕": 1.0 / 5, "⅖": 2.0 / 5, "⅗": 3.0 / 5, "⅘": 4.0 / 5,
            "⅙": 1.0 / 6, "⅚": 5.0 / 6,
            "⅛": 1.0 / 8, "⅜": 3.0 / 8, "⅝": 5.0 / 8, "⅞": 7.0 / 8,
        ]
        let vulgarCharacters = value.filter { vulgarFractions[$0] != nil }
        if vulgarCharacters.count == 1, let fractionCharacter = vulgarCharacters.first,
           let fraction = vulgarFractions[fractionCharacter] {
            let wholeText = value.replacingOccurrences(of: String(fractionCharacter), with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let whole: Double
            if wholeText.isEmpty { whole = 0 }
            else if let parsed = Double(wholeText), parsed.rounded(.towardZero) == parsed { whole = parsed }
            else { throw ParseError.invalid }
            try self.init(feet: whole + fraction)
            return
        } else if vulgarCharacters.count > 1 {
            throw ParseError.compound
        }

        let mixedPattern = #"^([0-9]+)(?:\s+|-)([0-9]+)/([0-9]+)$"#
        if let regex = try? NSRegularExpression(pattern: mixedPattern),
           let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
           match.range.location != NSNotFound,
           let wholeRange = Range(match.range(at: 1), in: value),
           let numeratorRange = Range(match.range(at: 2), in: value),
           let denominatorRange = Range(match.range(at: 3), in: value),
           let whole = Double(value[wholeRange]),
           let numerator = Double(value[numeratorRange]),
           let denominator = Double(value[denominatorRange]), denominator > 0, numerator < denominator {
            try self.init(feet: whole + numerator / denominator)
            return
        }

        // A bare slash expression is ambiguous in source descriptions (for
        // example `8/4`) and must not be silently treated as one stop footage.
        if value.contains("/") { throw ParseError.compound }
        if value.contains("-") { throw ParseError.compound }

        if value.contains(",") {
            guard value.range(of: #"^[0-9]+,[0-9]+$"#, options: .regularExpression) != nil else {
                throw ParseError.compound
            }
            value = value.replacingOccurrences(of: ",", with: ".")
        }
        guard value.range(of: #"^[0-9]+(?:\.[0-9]+)?$"#, options: .regularExpression) != nil,
              let feet = Double(value) else {
            throw ParseError.invalid
        }
        try self.init(feet: feet)
    }

    /// The nominal frequency multiplier relative to an 8′ rank.
    public var nominalFrequencyRatio: Double { 8 / feet }

    /// A semitone mapping is returned only when the nominal footage ratio is
    /// close enough to an equal-tempered semitone for discrete key mapping.
    public func nearestSemitoneOffset(tolerance: Double = 0.2) -> Int? {
        let exact = 12 * log2(nominalFrequencyRatio)
        let rounded = exact.rounded()
        guard abs(exact - rounded) < tolerance else { return nil }
        return Int(rounded)
    }

    /// Derives a nominal analysis prior. A missing designation is treated as
    /// unison for compatibility; a supplied invalid or compound value is not.
    public static func nominalFrequency(
        keyMidi: Int,
        footHeight: String?,
        referencePitchHz: Double? = nil
    ) -> Double? {
        let reference = referencePitchHz ?? 440
        guard reference.isFinite, reference > 0 else { return nil }
        let unison = reference * pow(2, Double(keyMidi - 69) / 12)
        guard let raw = footHeight?.trimmingCharacters(in: .whitespacesAndNewlines), raw.isEmpty == false else {
            return unison
        }
        guard let footage = try? OrganFootage(parsing: raw) else { return nil }
        return unison * footage.nominalFrequencyRatio
    }

    public static func nominalRatio(footHeight: String?) -> Double? {
        guard let raw = footHeight?.trimmingCharacters(in: .whitespacesAndNewlines), raw.isEmpty == false else {
            return 1
        }
        return (try? OrganFootage(parsing: raw))?.nominalFrequencyRatio
    }
}

public enum OrganologyClassifier {
    private static let compoundStopTerms = [
        "mixture", "mixtur", "mixtura", "fourniture", "plein jeu",
        "scharf", "scharff", "cymbel", "cimbel", "cymbal",
        "sesquialtera", "terzian", "rauschpfeife", "rauschquinte",
        "progressio", "cornet", "compound",
    ]

    public static func isCompoundStop(_ component: OrganComponent) -> Bool {
        isCompoundStop(label: component.label, kind: component.kind, sourceDetails: component.sourceDetails)
    }

    public static func isCompoundStop(label: String, kind: String, sourceDetails: [String: String]? = nil) -> Bool {
        let searchable = ([label, kind] + (sourceDetails?.map { "\($0.key) \($0.value)" } ?? []))
            .joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
        return compoundStopTerms.contains(where: searchable.contains)
    }
}

public extension RoadmapItem {
    /// Conservative applicability for single-fundamental pitch estimators.
    var inferredPitchApplicability: PitchAnalysisApplicability {
        if effectAnalysisProtocol != nil || instrumentNoiseProtocol != nil { return .nonPitched }
        switch coverageKind {
        case .instrumentNoise, .atonalPercussion, .sustainedEffect, .oneShotEffect,
             .repeatingEffect, .sequencedEffect, .compositeEffect, .operationalBaseline:
            return .nonPitched
        default:
            break
        }
        if let definition = soundingTargetDefinition ?? component.soundingTargetDefinition {
            let family = definition.family
            switch family {
            case .atonalPercussion, .sustainedEffect, .oneShotEffect, .repeatingEffect, .sequencedEffect, .compositeEffect:
                return .nonPitched
            case .otherSoundingElement:
                return .indeterminate
            case .pipeSpeech, .tonalPercussion:
                if Set(definition.memberComponentIDs).count > 1 { return .polyphonic }
                break
            }
        }
        if coverageKind == .customRegistration || coverageKind == .couplerEffect {
            return .polyphonic
        }
        if OrganologyClassifier.isCompoundStop(component)
            || activationRoutes?.contains(where: { Set($0.physicalPipeComponentIDs).count > 1 }) == true {
            return .polyphonic
        }
        return component.midiNote == nil ? .indeterminate : .monophonic
    }
}
