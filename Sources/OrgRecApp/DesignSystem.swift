import AppKit
import OrgRecCore
import SwiftUI

/// OrgRec's four-color visual system. Opacity is used for shades; no additional
/// chromatic accents should be introduced in feature views.
enum OrgRecTheme {
    /// Warm Japanese paper.
    static let washi = adaptive(light: 0xF5F1E8, dark: 0x181815)
    /// Carbon ink.
    static let sumi = adaptive(light: 0x252521, dark: 0xECE8DE)
    /// Traditional seal vermilion (shu-iro).
    static let shu = adaptive(light: 0xB94732, dark: 0xE06A51)
    /// Muted indigo (ai-iro).
    static let ai = adaptive(light: 0x365D68, dark: 0x78A7B2)

    static let surface = adaptive(light: 0xFBF9F3, dark: 0x20201C)
    static let recessed = adaptive(light: 0xEEE9DE, dark: 0x141411)
    static let hairline = sumi.opacity(0.13)
    static let secondaryText = sumi.opacity(0.62)
    static let tertiaryText = sumi.opacity(0.42)

    static let cornerRadius: CGFloat = 7
    static let compactCornerRadius: CGFloat = 5

    static func status(_ severity: ConsistencySeverity) -> Color {
        switch severity {
        case .blocker, .warning: shu
        case .information: ai
        }
    }

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let darkMode = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return nsColor(hex: darkMode ? dark : light)
        })
    }

    private static func nsColor(hex: UInt32) -> NSColor {
        NSColor(
            calibratedRed: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: 1
        )
    }
}

struct OrgRecCardModifier: ViewModifier {
    var inset: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .padding(inset)
            .background(OrgRecTheme.surface, in: RoundedRectangle(cornerRadius: OrgRecTheme.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OrgRecTheme.cornerRadius, style: .continuous)
                    .stroke(OrgRecTheme.hairline, lineWidth: 1)
            }
    }
}

struct JapaneseSectionTitleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(.title2, design: .serif, weight: .semibold))
            .tracking(-0.2)
            .foregroundStyle(OrgRecTheme.sumi)
    }
}

struct EyebrowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(.caption2, design: .rounded, weight: .semibold))
            .tracking(1.25)
            .textCase(.uppercase)
            .foregroundStyle(OrgRecTheme.shu)
    }
}

extension View {
    func orgRecCard(inset: CGFloat = 18) -> some View {
        modifier(OrgRecCardModifier(inset: inset))
    }

    func japaneseSectionTitle() -> some View {
        modifier(JapaneseSectionTitleModifier())
    }

    func eyebrow() -> some View {
        modifier(EyebrowModifier())
    }
}
