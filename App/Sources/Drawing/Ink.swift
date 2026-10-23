import SwiftUI
import OrbitKit

/// How simulation marks look. Every state differs in shape or fill, not only colour.
struct Ink {
    let hue: Color

    func fill(_ mark: Mark) -> Color {
        switch mark {
        case .idle: return Theme.surface
        case .focus: return hue
        case .compare: return hue.opacity(0.16)
        case .done: return Theme.good.opacity(0.18)
        case .muted: return Theme.sunken
        case .fresh: return Theme.surface
        }
    }

    func stroke(_ mark: Mark) -> Color {
        switch mark {
        case .idle: return Theme.line
        case .focus: return hue
        case .compare: return hue
        case .done: return Theme.good
        case .muted: return Theme.line
        case .fresh: return hue
        }
    }

    func lineWidth(_ mark: Mark) -> CGFloat {
        switch mark {
        case .fresh: return 2.5
        case .compare, .focus, .done: return 2
        default: return 1
        }
    }

    func text(_ mark: Mark) -> Color {
        switch mark {
        case .focus: return Theme.paper
        case .muted: return Theme.inkSoft.opacity(0.7)
        default: return Theme.ink
        }
    }

    /// A dashed outline marks "fresh" so it reads even without colour.
    func strokeStyle(_ mark: Mark) -> StrokeStyle {
        mark == .fresh
            ? StrokeStyle(lineWidth: lineWidth(mark), dash: [5, 3])
            : StrokeStyle(lineWidth: lineWidth(mark))
    }
}

enum Geo {
    /// Where the line from a box's centre toward `target` leaves the box.
    static func exit(from rect: CGRect, toward target: CGPoint, pad: CGFloat = 3) -> CGPoint {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let dx = target.x - c.x
        let dy = target.y - c.y
        if abs(dx) < 0.001 && abs(dy) < 0.001 { return c }
        let hw = rect.width / 2 + pad
        let hh = rect.height / 2 + pad
        let tx = abs(dx) > 0.001 ? hw / abs(dx) : CGFloat.infinity
        let ty = abs(dy) > 0.001 ? hh / abs(dy) : CGFloat.infinity
        let t = min(1, min(tx, ty))
        return CGPoint(x: c.x + dx * t, y: c.y + dy * t)
    }

    /// Where the line from a circle's centre toward `target` leaves the circle.
    static func exit(circle c: CGPoint, radius: CGFloat, toward target: CGPoint) -> CGPoint {
        let dx = target.x - c.x
        let dy = target.y - c.y
        let length = max(0.001, (dx * dx + dy * dy).squareRoot())
        let t = min(1, radius / length)
        return CGPoint(x: c.x + dx * t, y: c.y + dy * t)
    }

    static func arrowHead(at tip: CGPoint, from start: CGPoint, size: CGFloat = 9) -> Path {
        let dx = tip.x - start.x
        let dy = tip.y - start.y
        let length = max(0.001, (dx * dx + dy * dy).squareRoot())
        let ux = dx / length
        let uy = dy / length
        var head = Path()
        head.move(to: tip)
        head.addLine(to: CGPoint(x: tip.x - ux * size - uy * size * 0.5, y: tip.y - uy * size + ux * size * 0.5))
        head.addLine(to: CGPoint(x: tip.x - ux * size + uy * size * 0.5, y: tip.y - uy * size - ux * size * 0.5))
        head.closeSubpath()
        return head
    }

    static func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    /// Draws a text label on a small solid chip.
    static func chip(_ context: GraphicsContext, text: String, at point: CGPoint, size: CGFloat = 12, fill: Color = Theme.surface, ink: Color = Theme.inkSoft) {
        let resolved = context.resolve(Text(text).font(.system(size: size, weight: .semibold)).foregroundColor(ink))
        let measured = resolved.measure(in: CGSize(width: 200, height: 40))
        let rect = CGRect(
            x: point.x - measured.width / 2 - 5,
            y: point.y - measured.height / 2 - 2,
            width: measured.width + 10,
            height: measured.height + 4
        )
        context.fill(Path(roundedRect: rect, cornerRadius: 5, style: .continuous), with: .color(fill))
        context.draw(resolved, at: point)
    }
}
