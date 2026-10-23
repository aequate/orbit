import SwiftUI
import OrbitKit

/// Draws one frame of a simulation. Every element carries a written label, so nothing
/// relies on remembering an earlier frame or picturing what is off screen.
struct SimSceneView: View {
    let scene: SimScene
    let hue: Color

    var body: some View {
        Canvas { context, size in
            let ink = Ink(hue: hue)
            switch scene {
            case .array(let array):
                if array.vertical {
                    SimDraw.stack(context, size: size, scene: array, ink: ink)
                } else {
                    SimDraw.row(context, size: size, scene: array, ink: ink)
                }
            case .buckets(let buckets):
                SimDraw.buckets(context, size: size, scene: buckets, ink: ink)
            case .graph(let graph):
                SimDraw.graph(context, size: size, scene: graph, ink: ink)
            case .curve(let curve):
                SimDraw.curve(context, size: size, scene: curve, ink: ink)
            }
        }
        .aspectRatio(4.0 / 3.0, contentMode: .fit)
    }
}

enum SimDraw {
    static func text(_ context: GraphicsContext, _ string: String, at point: CGPoint, size: CGFloat, weight: Font.Weight = .semibold, colour: Color = Theme.ink, anchor: UnitPoint = .center) {
        let resolved = context.resolve(Text(string).font(.system(size: size, weight: weight)).foregroundColor(colour))
        context.draw(resolved, at: point, anchor: anchor)
    }

    static func measure(_ context: GraphicsContext, _ string: String, size: CGFloat, weight: Font.Weight = .semibold) -> CGSize {
        context.resolve(Text(string).font(.system(size: size, weight: weight))).measure(in: CGSize(width: 400, height: 100))
    }

    static func cell(_ context: GraphicsContext, _ cell: SimCell, in rect: CGRect, ink: Ink, fontSize: CGFloat) {
        let shape = Path(roundedRect: rect, cornerRadius: min(9, rect.height / 4), style: .continuous)
        context.fill(shape, with: .color(ink.fill(cell.mark)))
        context.stroke(shape, with: .color(ink.stroke(cell.mark)), style: ink.strokeStyle(cell.mark))
        text(context, cell.text, at: CGPoint(x: rect.midX, y: rect.midY), size: fontSize, colour: ink.text(cell.mark))
    }

    // MARK: Row of cells

    static func row(_ context: GraphicsContext, size: CGSize, scene: ArrayScene, ink: Ink) {
        let n = scene.cells.count
        guard n > 0 else {
            text(context, "(empty)", at: CGPoint(x: size.width / 2, y: size.height / 2), size: 15, weight: .medium, colour: Theme.inkSoft)
            return
        }
        let gap: CGFloat = 4
        let usable = size.width - 24
        let side = max(22, min(58, (usable - gap * CGFloat(n - 1)) / CGFloat(n)))
        let total = side * CGFloat(n) + gap * CGFloat(n - 1)
        let x0 = (size.width - total) / 2
        let y0 = size.height * 0.42 - side / 2
        let fontSize = max(11, min(19, side * 0.42))

        for (i, item) in scene.cells.enumerated() {
            let rect = CGRect(x: x0 + CGFloat(i) * (side + gap), y: y0, width: side, height: side)
            cell(context, item, in: rect, ink: ink, fontSize: fontSize)
            if let note = item.note {
                text(context, note, at: CGPoint(x: rect.midX, y: rect.maxY + 11), size: max(10, min(12, side * 0.3)), weight: .medium, colour: Theme.inkSoft)
            }
        }

        // Pointer labels above their cells, staggered when they would collide.
        var grouped: [Int: [String]] = [:]
        for marker in scene.markers where marker.index >= 0 && marker.index < n {
            grouped[marker.index, default: []].append(marker.label)
        }
        var lastEnd: [CGFloat] = [-CGFloat.infinity, -CGFloat.infinity]
        for index in grouped.keys.sorted() {
            let label = (grouped[index] ?? []).joined(separator: " · ")
            let cx = x0 + CGFloat(index) * (side + gap) + side / 2
            let width = measure(context, label, size: 12).width + 10
            let level = cx - width / 2 > lastEnd[0] ? 0 : 1
            lastEnd[level] = cx + width / 2
            let ly = y0 - 14 - CGFloat(level) * 20
            Geo.chip(context, text: label, at: CGPoint(x: cx, y: ly), size: 12, fill: Theme.sunken, ink: Theme.ink)
            var tick = Path()
            tick.move(to: CGPoint(x: cx, y: ly + 9))
            tick.addLine(to: CGPoint(x: cx, y: y0 - 2))
            context.stroke(tick, with: .color(Theme.inkSoft), lineWidth: 1.2)
        }

        if let label = scene.label {
            text(context, label, at: CGPoint(x: size.width / 2, y: y0 + side + 40), size: 17, colour: Theme.ink)
        }
    }

    // MARK: Vertical stack

    static func stack(_ context: GraphicsContext, size: CGSize, scene: ArrayScene, ink: Ink) {
        let n = scene.cells.count
        let floorY = size.height - 40
        let widest = scene.cells.map { measure(context, $0.text, size: 15).width }.max() ?? 60
        let width = min(size.width * 0.6, max(110, widest + 32))
        let x0 = size.width * 0.42 - width / 2
        var floor = Path()
        floor.move(to: CGPoint(x: x0 - 14, y: floorY + 3))
        floor.addLine(to: CGPoint(x: x0 + width + 14, y: floorY + 3))
        context.stroke(floor, with: .color(Theme.inkSoft), lineWidth: 2)

        if n == 0 {
            text(context, "(empty)", at: CGPoint(x: x0 + width / 2, y: floorY - 20), size: 15, weight: .medium, colour: Theme.inkSoft)
        }
        let height = n == 0 ? 40 : min(42, (floorY - 16) / CGFloat(n) - 4)
        var rects: [CGRect] = []
        for (i, item) in scene.cells.enumerated() {
            let rect = CGRect(x: x0, y: floorY - CGFloat(i + 1) * (height + 4), width: width, height: height)
            rects.append(rect)
            cell(context, item, in: rect, ink: ink, fontSize: min(16, height * 0.42))
            if let note = item.note {
                text(context, note, at: CGPoint(x: rect.minX - 8, y: rect.midY), size: 12, weight: .medium, colour: Theme.inkSoft, anchor: .trailing)
            }
        }
        for marker in scene.markers where marker.index >= 0 && marker.index < rects.count {
            let rect = rects[marker.index]
            text(context, "← " + marker.label, at: CGPoint(x: rect.maxX + 8, y: rect.midY), size: 13, colour: Theme.ink, anchor: .leading)
        }
        if let label = scene.label {
            text(context, label, at: CGPoint(x: size.width / 2, y: size.height - 16), size: 15, colour: Theme.ink)
        }
    }

    // MARK: Hash buckets

    static func buckets(_ context: GraphicsContext, size: CGSize, scene: BucketScene, ink: Ink) {
        let rows = max(1, scene.buckets.count)
        let top: CGFloat = 40
        let rowHeight = min(44, (size.height - top - 8) / CGFloat(rows))
        let cellHeight = rowHeight - 8

        if let incoming = scene.incoming {
            var line = "Key: " + incoming
            if let target = scene.target { line += "  →  bucket " + String(target) }
            text(context, line, at: CGPoint(x: 12, y: 18), size: 15, colour: Theme.ink, anchor: .leading)
        }

        for (b, chain) in scene.buckets.enumerated() {
            let y = top + CGFloat(b) * rowHeight
            let rowRect = CGRect(x: 4, y: y, width: size.width - 8, height: rowHeight)
            if scene.target == b {
                context.fill(Path(roundedRect: rowRect, cornerRadius: 8, style: .continuous), with: .color(ink.hue.opacity(0.1)))
            }
            let indexRect = CGRect(x: 10, y: y + 4, width: 34, height: cellHeight)
            context.fill(Path(roundedRect: indexRect, cornerRadius: 7, style: .continuous), with: .color(Theme.sunken))
            text(context, String(b), at: CGPoint(x: indexRect.midX, y: indexRect.midY), size: 14, colour: Theme.inkSoft)

            var x = indexRect.maxX + 22
            var previousEnd = CGPoint(x: indexRect.maxX + 2, y: indexRect.midY)
            for item in chain {
                let w = max(52, measure(context, item.text, size: 14).width + 20)
                let rect = CGRect(x: x, y: y + 4, width: w, height: cellHeight)
                var link = Path()
                link.move(to: previousEnd)
                let tip = CGPoint(x: rect.minX - 2, y: rect.midY)
                link.addLine(to: tip)
                context.stroke(link, with: .color(Theme.inkSoft), lineWidth: 1.4)
                context.fill(Geo.arrowHead(at: tip, from: previousEnd, size: 7), with: .color(Theme.inkSoft))
                cell(context, item, in: rect, ink: ink, fontSize: 14)
                previousEnd = CGPoint(x: rect.maxX + 2, y: rect.midY)
                x = rect.maxX + 22
            }
            if chain.isEmpty {
                text(context, "empty", at: CGPoint(x: indexRect.maxX + 14, y: indexRect.midY), size: 13, weight: .regular, colour: Theme.inkSoft.opacity(0.7), anchor: .leading)
            }
        }
    }

    // MARK: Graph

    static func edgeColour(_ mark: Mark, ink: Ink) -> Color {
        switch mark {
        case .idle: return Theme.inkSoft.opacity(0.55)
        case .muted: return Theme.line
        case .done: return Theme.good
        default: return ink.hue
        }
    }

    static func graph(_ context: GraphicsContext, size: CGSize, scene: GraphScene, ink: Ink) {
        let footerSpace: CGFloat = scene.footer == nil ? 0 : 30
        let frame = CGRect(x: 26, y: 24, width: size.width - 52, height: size.height - 48 - footerSpace)
        let radius = max(14, min(21, size.width / 18))
        var centres: [String: CGPoint] = [:]
        for node in scene.nodes {
            centres[node.id] = CGPoint(x: frame.minX + node.x * frame.width, y: frame.minY + node.y * frame.height)
        }

        for edge in scene.edges {
            guard let a = centres[edge.from], let b = centres[edge.to] else { continue }
            let start = Geo.exit(circle: a, radius: radius + 2, toward: b)
            let end = Geo.exit(circle: b, radius: radius + 2, toward: a)
            var path = Path()
            path.move(to: start)
            path.addLine(to: end)
            let width: CGFloat = edge.mark == .idle || edge.mark == .muted ? 1.6 : 3
            let style = edge.mark == .compare
                ? StrokeStyle(lineWidth: width, lineCap: .round, dash: [6, 4])
                : StrokeStyle(lineWidth: width, lineCap: .round)
            let colour = edgeColour(edge.mark, ink: ink)
            context.stroke(path, with: .color(colour), style: style)
            if scene.directed {
                context.fill(Geo.arrowHead(at: end, from: start, size: 8), with: .color(colour))
            }
            if let label = edge.label {
                Geo.chip(context, text: label, at: Geo.midpoint(start, end), size: 12, fill: Theme.paper, ink: Theme.inkSoft)
            }
        }

        for node in scene.nodes {
            guard let c = centres[node.id] else { continue }
            let rect = CGRect(x: c.x - radius, y: c.y - radius, width: 2 * radius, height: 2 * radius)
            let circle = Path(ellipseIn: rect)
            context.fill(circle, with: .color(Theme.surface))
            context.fill(circle, with: .color(ink.fill(node.mark)))
            context.stroke(circle, with: .color(ink.stroke(node.mark)), style: ink.strokeStyle(node.mark))
            text(context, node.label, at: c, size: max(12, radius * 0.72), colour: ink.text(node.mark))
            if let badge = node.badge {
                let at = CGPoint(x: c.x + radius * 0.9, y: c.y - radius * 1.05)
                Geo.chip(context, text: badge, at: at, size: 12, fill: Theme.ink, ink: Theme.paper)
            }
        }

        if let footer = scene.footer {
            text(context, footer, at: CGPoint(x: size.width / 2, y: size.height - 18), size: 15, colour: Theme.ink)
        }
    }

    // MARK: Curves

    static func curve(_ context: GraphicsContext, size: CGSize, scene: CurveScene, ink: Ink) {
        let plot = CGRect(x: 34, y: 14, width: size.width - 48, height: size.height - 42)
        let xr = scene.xRange
        let yr = scene.yRange
        let xSpan = max(0.0001, xr.upperBound - xr.lowerBound)
        let ySpan = max(0.0001, yr.upperBound - yr.lowerBound)
        func map(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(
                x: plot.minX + CGFloat((x - xr.lowerBound) / xSpan) * plot.width,
                y: plot.maxY - CGFloat((y - yr.lowerBound) / ySpan) * plot.height
            )
        }

        // Axes through zero when zero is in range, otherwise along the edges.
        let axisY = yr.contains(0) ? map(xr.lowerBound, 0).y : plot.maxY
        let axisX = xr.contains(0) ? map(0, yr.lowerBound).x : plot.minX
        var axes = Path()
        axes.move(to: CGPoint(x: plot.minX, y: axisY))
        axes.addLine(to: CGPoint(x: plot.maxX, y: axisY))
        axes.move(to: CGPoint(x: axisX, y: plot.minY))
        axes.addLine(to: CGPoint(x: axisX, y: plot.maxY))
        context.stroke(axes, with: .color(Theme.line), lineWidth: 1.2)
        text(context, short(xr.lowerBound), at: CGPoint(x: plot.minX, y: plot.maxY + 13), size: 11, weight: .medium, colour: Theme.inkSoft)
        text(context, short(xr.upperBound), at: CGPoint(x: plot.maxX, y: plot.maxY + 13), size: 11, weight: .medium, colour: Theme.inkSoft)
        text(context, short(yr.upperBound), at: CGPoint(x: plot.minX - 6, y: plot.minY + 6), size: 11, weight: .medium, colour: Theme.inkSoft, anchor: .trailing)
        text(context, short(yr.lowerBound), at: CGPoint(x: plot.minX - 6, y: plot.maxY), size: 11, weight: .medium, colour: Theme.inkSoft, anchor: .trailing)

        var clipped = context
        clipped.clip(to: Path(plot.insetBy(dx: -2, dy: -2)))

        for item in scene.curves {
            guard let first = item.points.first else { continue }
            var path = Path()
            path.move(to: map(first.x, first.y))
            for p in item.points.dropFirst() { path.addLine(to: map(p.x, p.y)) }
            let colour = edgeColour(item.mark == .idle ? .focus : item.mark, ink: ink)
            let faded = item.mark == .muted ? Theme.line : (item.mark == .idle ? Theme.inkSoft : colour)
            let style = item.mark == .compare
                ? StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [7, 5])
                : StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
            clipped.stroke(path, with: .color(faded), style: style)
        }

        // Straight lines: the secant through two points, or the tangent at one.
        if let p = scene.point, let q = scene.secondPoint, abs(q.x - p.x) > 1e-9 {
            let slope = (q.y - p.y) / (q.x - p.x)
            clipped.stroke(line(through: p, slope: slope, xr: xr, map: map), with: .color(Theme.inkSoft), style: StrokeStyle(lineWidth: 1.6, dash: [6, 4]))
        }
        if let p = scene.point, let slope = scene.tangentSlope {
            clipped.stroke(line(through: p, slope: slope, xr: xr, map: map), with: .color(ink.hue), lineWidth: 2)
        }

        if scene.trail.count > 1 {
            var trail = Path()
            trail.move(to: map(scene.trail[0].x, scene.trail[0].y))
            for p in scene.trail.dropFirst() { trail.addLine(to: map(p.x, p.y)) }
            clipped.stroke(trail, with: .color(ink.hue.opacity(0.6)), style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
        }
        for p in scene.trail {
            let c = map(p.x, p.y)
            let dot = Path(ellipseIn: CGRect(x: c.x - 3.5, y: c.y - 3.5, width: 7, height: 7))
            clipped.fill(dot, with: .color(Theme.paper))
            clipped.stroke(dot, with: .color(ink.hue), lineWidth: 1.5)
        }
        if let q = scene.secondPoint {
            let c = map(q.x, q.y)
            let dot = Path(ellipseIn: CGRect(x: c.x - 6, y: c.y - 6, width: 12, height: 12))
            clipped.fill(dot, with: .color(Theme.paper))
            clipped.stroke(dot, with: .color(ink.hue), lineWidth: 2.5)
        }
        if let p = scene.point {
            let c = map(p.x, p.y)
            clipped.fill(Path(ellipseIn: CGRect(x: c.x - 7, y: c.y - 7, width: 14, height: 14)), with: .color(ink.hue))
        }

        // Curve names at their right-hand ends, kept apart vertically.
        var used: [CGFloat] = []
        for item in scene.curves where !item.label.isEmpty {
            guard let last = item.points.last(where: { yr.contains($0.y) && xr.contains($0.x) }) else { continue }
            var at = map(last.x, last.y)
            at.x = min(at.x, plot.maxX - 30)
            at.y = max(plot.minY + 10, at.y - 12)
            while used.contains(where: { abs($0 - at.y) < 18 }) { at.y += 18 }
            used.append(at.y)
            Geo.chip(context, text: item.label, at: at, size: 12, fill: Theme.surface, ink: item.mark == .muted ? Theme.inkSoft : Theme.ink)
        }
    }

    static func line(through p: Point2, slope: Double, xr: ClosedRange<Double>, map: (Double, Double) -> CGPoint) -> Path {
        var path = Path()
        path.move(to: map(xr.lowerBound, p.y + slope * (xr.lowerBound - p.x)))
        path.addLine(to: map(xr.upperBound, p.y + slope * (xr.upperBound - p.x)))
        return path
    }

    static func short(_ value: Double) -> String {
        if value == value.rounded() { return String(Int(value)) }
        return String(format: "%.1f", value)
    }
}
