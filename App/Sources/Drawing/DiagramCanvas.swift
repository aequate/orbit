import SwiftUI
import OrbitKit

/// Draws a `Diagram` as it stands after a given step. Things that just appeared are
/// outlined in the topic's colour so the eye knows where to look.
struct DiagramCanvas: View {
    let diagram: Diagram
    let step: Int
    let hue: Color

    var body: some View {
        Canvas { context, size in
            draw(context, size: size)
        }
        .aspectRatio(4.0 / 3.0, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let visible = diagram.visible(through: step)
        let labels = diagram.nodes.filter { visible.contains($0.id) && !$0.label.isEmpty }.map(\.label)
        return "Diagram showing " + Atlas.list(labels)
    }

    private struct Placed {
        let node: Diagram.Node
        let rect: CGRect
        let resolved: GraphicsContext.ResolvedText?
        let labelRect: CGRect
    }

    private func draw(_ context: GraphicsContext, size: CGSize) {
        let visible = diagram.visible(through: step)
        let fresh = step == 0 ? visible : diagram.fresh(at: step)
        let inset: CGFloat = 10
        let frame = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
        let fontSize = max(11, min(15, size.width / 25))
        let maxLabelWidth = size.width * 0.3

        var placed: [String: Placed] = [:]
        for node in diagram.nodes where visible.contains(node.id) {
            let centre = CGPoint(x: frame.minX + node.x * frame.width, y: frame.minY + node.y * frame.height)
            let isFresh = fresh.contains(node.id)
            switch node.role {
            case .anchor:
                let rect = CGRect(x: centre.x, y: centre.y, width: 0, height: 0)
                placed[node.id] = Placed(node: node, rect: rect, resolved: nil, labelRect: rect)
            case .dot:
                let r: CGFloat = 6
                let rect = CGRect(x: centre.x - r, y: centre.y - r, width: 2 * r, height: 2 * r)
                let text = Text(node.label).font(.system(size: fontSize - 1, weight: .medium)).foregroundColor(Theme.ink)
                let resolved = context.resolve(text)
                let m = resolved.measure(in: CGSize(width: maxLabelWidth, height: 200))
                let labelRect = CGRect(x: centre.x - m.width / 2, y: rect.maxY + 3, width: m.width, height: m.height)
                placed[node.id] = Placed(node: node, rect: rect, resolved: resolved, labelRect: labelRect)
            case .note:
                let text = Text(node.label).font(.system(size: fontSize - 1, weight: .regular)).foregroundColor(isFresh ? Theme.ink : Theme.inkSoft)
                let resolved = context.resolve(text)
                let m = resolved.measure(in: CGSize(width: maxLabelWidth, height: 200))
                let rect = CGRect(x: centre.x - m.width / 2, y: centre.y - m.height / 2, width: m.width, height: m.height)
                placed[node.id] = Placed(node: node, rect: rect, resolved: resolved, labelRect: rect)
            case .box, .pill:
                let text = Text(node.label).font(.system(size: fontSize, weight: .semibold)).foregroundColor(Theme.ink)
                let resolved = context.resolve(text)
                let m = resolved.measure(in: CGSize(width: maxLabelWidth, height: 200))
                let padX: CGFloat = node.role == .pill ? 13 : 10
                let padY: CGFloat = 7
                let rect = CGRect(x: centre.x - m.width / 2 - padX, y: centre.y - m.height / 2 - padY, width: m.width + 2 * padX, height: m.height + 2 * padY)
                let labelRect = CGRect(x: centre.x - m.width / 2, y: centre.y - m.height / 2, width: m.width, height: m.height)
                placed[node.id] = Placed(node: node, rect: rect, resolved: resolved, labelRect: labelRect)
            }
        }

        // Edges first, so boxes sit on top of line ends.
        for edge in diagram.edges where visible.contains(edge.id) {
            guard let a = placed[edge.from], let b = placed[edge.to] else { continue }
            let isFresh = fresh.contains(edge.id)
            let colour = isFresh ? hue : Theme.inkSoft
            let ca = CGPoint(x: a.rect.midX, y: a.rect.midY)
            let cb = CGPoint(x: b.rect.midX, y: b.rect.midY)
            let start = endpoint(a, toward: cb)
            let end = endpoint(b, toward: ca)
            var path = Path()
            path.move(to: start)
            path.addLine(to: end)
            let width: CGFloat = isFresh ? 2.5 : 1.6
            let style = edge.style == .dashed
                ? StrokeStyle(lineWidth: width, lineCap: .round, dash: [6, 4])
                : StrokeStyle(lineWidth: width, lineCap: .round)
            context.stroke(path, with: .color(colour), style: style)
            if edge.style != .line {
                context.fill(Geo.arrowHead(at: end, from: start), with: .color(colour))
            }
            if edge.style == .both {
                context.fill(Geo.arrowHead(at: start, from: end), with: .color(colour))
            }
            if let label = edge.label, !label.isEmpty {
                Geo.chip(context, text: label, at: Geo.midpoint(start, end), size: fontSize - 2, fill: Theme.paper, ink: isFresh ? hue : Theme.inkSoft)
            }
        }

        for (_, item) in placed.sorted(by: { $0.key < $1.key }) {
            let isFresh = fresh.contains(item.node.id)
            switch item.node.role {
            case .anchor:
                break
            case .dot:
                let circle = Path(ellipseIn: item.rect)
                context.fill(circle, with: .color(isFresh ? hue : Theme.ink))
                if let resolved = item.resolved {
                    context.draw(resolved, in: item.labelRect)
                }
            case .note:
                if let resolved = item.resolved {
                    context.draw(resolved, in: item.labelRect)
                }
            case .box, .pill:
                let radius: CGFloat = item.node.role == .pill ? item.rect.height / 2 : 9
                let shape = Path(roundedRect: item.rect, cornerRadius: radius, style: .continuous)
                context.fill(shape, with: .color(isFresh ? hue.opacity(0.12) : Theme.surface))
                context.stroke(shape, with: .color(isFresh ? hue : Theme.line), lineWidth: isFresh ? 2.5 : 1.2)
                if let resolved = item.resolved {
                    context.draw(resolved, in: item.labelRect)
                }
            }
        }
    }

    private func endpoint(_ item: Placed, toward target: CGPoint) -> CGPoint {
        switch item.node.role {
        case .anchor:
            return CGPoint(x: item.rect.midX, y: item.rect.midY)
        case .dot:
            return Geo.exit(circle: CGPoint(x: item.rect.midX, y: item.rect.midY), radius: item.rect.width / 2 + 3, toward: target)
        default:
            return Geo.exit(from: item.rect, toward: target)
        }
    }
}
