import SwiftUI
import UIKit
import OrbitKit

extension UIColor {
    convenience init(hex: UInt32) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >> 8) & 0xFF) / 255
        let b = CGFloat(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

extension Color {
    /// A colour that follows light and dark mode.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

/// Orbit's whole visual vocabulary: solid surfaces, one radius, serif titles, six cluster hues.
enum Theme {
    static let paper = Color(light: 0xF2F4F5, dark: 0x0F1214)
    static let surface = Color(light: 0xFFFFFF, dark: 0x181C20)
    static let sunken = Color(light: 0xE6E9EC, dark: 0x22272C)
    static let ink = Color(light: 0x121518, dark: 0xECEFF2)
    static let inkSoft = Color(light: 0x59616A, dark: 0x9BA5AF)
    static let line = Color(light: 0xD6DBDF, dark: 0x2D333A)
    static let accent = Color(light: 0x2F5BD8, dark: 0x86A2FF)
    static let good = Color(light: 0x23865A, dark: 0x4CC98A)
    static let bad = Color(light: 0xBF3D4E, dark: 0xF07E8C)

    static let radius: CGFloat = 14
    static let gutter: CGFloat = 20

    static func hue(_ key: String) -> Color {
        switch key {
        case "blue": return Color(light: 0x3563D9, dark: 0x7096FF)
        case "green": return Color(light: 0x23865A, dark: 0x4CC98A)
        case "orange": return Color(light: 0xC8641E, dark: 0xF29A55)
        case "violet": return Color(light: 0x7D4FCB, dark: 0xB08CF5)
        case "rose": return Color(light: 0xBF3D68, dark: 0xF07EA2)
        case "teal": return Color(light: 0x0F7F93, dark: 0x4CC4D8)
        default: return accent
        }
    }

    static func title(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }

    static let body = Font.system(size: 17)
    static let reading = Font.system(size: 19)
    static let caption = Font.system(size: 13, weight: .medium)
    static let label = Font.system(size: 12, weight: .semibold)
}

/// Joins text pieces. Long `+` chains of strings can time out Swift's type checker.
enum Words {
    static func join(_ parts: [String]) -> String {
        parts.joined()
    }
}

extension Atlas {
    func hue(of topicID: String) -> Color {
        Theme.hue(cluster(of: topicID)?.hue ?? "")
    }
}

// MARK: - Surfaces

struct SurfaceModifier: ViewModifier {
    var fill: Color = Theme.surface
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}

extension View {
    func surface(_ fill: Color = Theme.surface, padding: CGFloat = 16) -> some View {
        modifier(SurfaceModifier(fill: fill, padding: padding))
    }
}

/// Small uppercase heading above a section.
struct SectionLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(Theme.label)
            .tracking(0.8)
            .foregroundStyle(Theme.inkSoft)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Cluster name with its colour swatch.
struct ClusterTag: View {
    let cluster: Cluster?

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(Theme.hue(cluster?.hue ?? "")).frame(width: 8, height: 8)
            Text(cluster?.name ?? "")
                .font(Theme.caption)
                .foregroundStyle(Theme.inkSoft)
        }
    }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    var fill: Color = Theme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Theme.paper)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(fill, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Theme.sunken, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Compact capsule-free chip used for filters and links.
struct ChipButtonStyle: ButtonStyle {
    var selected = false
    var tint: Color = Theme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(selected ? Theme.paper : Theme.ink)
            .padding(.horizontal, 12)
            .frame(minHeight: 34)
            .background(selected ? tint : Theme.surface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(selected ? tint : Theme.line, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// A plain segmented control with large, readable segments.
struct Segmented<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let title: (Value) -> String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                let isOn = option == selection
                Button {
                    selection = option
                } label: {
                    Text(title(option))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isOn ? Theme.ink : Theme.inkSoft)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(isOn ? Theme.surface : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Theme.sunken, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
    }
}

/// A thin progress bar.
struct ProgressLine: View {
    let fraction: Double
    var tint: Color = Theme.accent

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.sunken)
                Capsule().fill(tint).frame(width: max(0, min(1, fraction)) * geo.size.width)
            }
        }
        .frame(height: 6)
        .accessibilityElement()
        .accessibilityValue(Text(String(Int((fraction * 100).rounded())) + " percent"))
    }
}

/// Wraps children onto new lines when they run out of room.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            widest = max(widest, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width.isFinite ? width : widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
