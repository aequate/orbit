import SwiftUI
import OrbitKit

/// Where every topic sits in both layouts, so the map can morph between them.
struct MapScene {
    let atlas: Atlas
    let orbit: [String: Vec3]
    let tower: [String: Vec3]

    func position(_ id: String, morph: Double) -> Vec3 {
        let a = orbit[id] ?? .zero
        let b = tower[id] ?? a
        return a.lerp(to: b, morph)
    }

    func project(camera: Camera, morph: Double, size: CGSize) -> [String: Projected] {
        var result: [String: Projected] = [:]
        let w = Double(size.width)
        let h = Double(size.height)
        for topic in atlas.topics {
            result[topic.id] = camera.project(position(topic.id, morph: morph), width: w, height: h)
        }
        return result
    }

    /// The topic under a tap, preferring nodes nearer the viewer when several overlap.
    func hit(_ location: CGPoint, camera: Camera, morph: Double, size: CGSize) -> String? {
        let points = project(camera: camera, morph: morph, size: size)
        var best: String?
        var bestScore = Double.infinity
        for (id, p) in points {
            let dx = p.x - Double(location.x)
            let dy = p.y - Double(location.y)
            let distance = (dx * dx + dy * dy).squareRoot()
            guard distance <= 28 else { continue }
            let score = distance - p.depth * 12
            if score < bestScore {
                bestScore = score
                best = id
            }
        }
        return best
    }
}

/// What to emphasise when drawing.
struct MapStyle {
    var selected: String?
    var neighbours: Set<String> = []
    var prerequisites: Set<String> = []
    var filter: String?
    var understood: Set<String> = []
    var hues: [String: Color] = [:]
}

/// Draws the map: guide rings, prerequisite links, idea nodes and their labels.
enum MapRenderer {
    static func smooth(_ t: Double) -> Double {
        t * t * (3 - 2 * t)
    }

    static func fade(_ depth: Double) -> Double {
        let t = max(0, min(1, (depth + 1) / 2))
        return 0.3 + 0.7 * t
    }

    static func point(_ p: Projected) -> CGPoint {
        CGPoint(x: p.x, y: p.y)
    }

    static func nodeRadius(_ topic: Topic, p: Projected, zoom: Double, selected: Bool) -> Double {
        let base: Double = topic.destination ? 8.5 : 6.5
        let grow: Double = min(1.5, zoom.squareRoot())
        return (base + (selected ? 3 : 0)) * p.scale * grow
    }

    static func draw(_ context: GraphicsContext, size: CGSize, scene: MapScene, camera: Camera, morph rawMorph: Double, style: MapStyle) {
        let morph = smooth(rawMorph)
        let points = scene.project(camera: camera, morph: morph, size: size)
        drawRings(context, size: size, scene: scene, camera: camera, morph: morph)
        drawEdges(context, scene: scene, points: points, camera: camera, style: style)
        drawNodes(context, scene: scene, points: points, camera: camera, style: style)
        drawLabels(context, size: size, scene: scene, points: points, camera: camera, style: style)
    }

    // MARK: Rings

    static func ring(y: Double, radius: Double, camera: Camera, size: CGSize) -> Path {
        var path = Path()
        let count = 72
        for i in 0...count {
            let t = Double(i) / Double(count) * 2 * .pi
            let p = camera.project(Vec3(cos(t) * radius, y, sin(t) * radius), width: Double(size.width), height: Double(size.height))
            if i == 0 { path.move(to: point(p)) } else { path.addLine(to: point(p)) }
        }
        return path
    }

    static func drawRings(_ context: GraphicsContext, size: CGSize, scene: MapScene, camera: Camera, morph: Double) {
        var ctx = context
        if morph < 0.99 {
            ctx.opacity = 1 - morph
            ctx.stroke(ring(y: 0, radius: 1.08, camera: camera, size: size), with: .color(Theme.line), lineWidth: 1)
        }
        if morph > 0.01 {
            ctx.opacity = morph
            let maxDepth = scene.atlas.maxDepth
            for depth in 0...max(0, maxDepth) {
                let y = GraphLayout.towerHeight(depth: depth, maxDepth: maxDepth)
                ctx.stroke(ring(y: y, radius: GraphLayout.towerRadius, camera: camera, size: size), with: .color(Theme.line), lineWidth: 1)
            }
            let w = Double(size.width)
            let h = Double(size.height)
            let bottom = camera.project(Vec3(0, GraphLayout.towerHeight(depth: 0, maxDepth: maxDepth) - 0.16, 0), width: w, height: h)
            let top = camera.project(Vec3(0, GraphLayout.towerHeight(depth: maxDepth, maxDepth: maxDepth) + 0.16, 0), width: w, height: h)
            let style = Font.system(size: 12, weight: .semibold)
            ctx.draw(Text("FOUNDATIONS").font(style).foregroundColor(Theme.inkSoft), at: point(bottom))
            ctx.draw(Text("ADVANCED").font(style).foregroundColor(Theme.inkSoft), at: point(top))
        }
    }

    // MARK: Edges

    static func drawEdges(_ context: GraphicsContext, scene: MapScene, points: [String: Projected], camera: Camera, style: MapStyle) {
        var ctx = context
        var highlighted: [(from: Projected, to: Projected, toID: String, incoming: Bool)] = []
        for link in scene.atlas.links {
            guard let a = points[link.from], let b = points[link.to] else { continue }
            let isIncoming = style.selected == link.to
            let isOutgoing = style.selected == link.from
            if isIncoming || isOutgoing {
                highlighted.append((from: a, to: b, toID: link.to, incoming: isIncoming))
                continue
            }
            var alpha = fade((a.depth + b.depth) / 2)
            if style.selected != nil { alpha *= 0.35 }
            if let filter = style.filter {
                let inFilter = scene.atlas.topic(link.from)?.cluster == filter || scene.atlas.topic(link.to)?.cluster == filter
                if !inFilter { alpha *= 0.3 }
            }
            ctx.opacity = alpha
            var path = Path()
            path.move(to: point(a))
            path.addLine(to: point(b))
            ctx.stroke(path, with: .color(Theme.inkSoft.opacity(0.55)), lineWidth: 1)
        }

        guard let selected = style.selected else { return }
        let hue = style.hues[selected] ?? Theme.accent
        for edge in highlighted {
            ctx.opacity = 1
            let start = point(edge.from)
            let end = point(edge.to)
            let dx = end.x - start.x
            let dy = end.y - start.y
            let length = max(0.001, (dx * dx + dy * dy).squareRoot())
            let ux = dx / length
            let uy = dy / length
            let targetTopic = scene.atlas.topic(edge.toID)
            let inset = targetTopic.map { nodeRadius($0, p: edge.to, zoom: camera.zoom, selected: edge.toID == selected) } ?? 6
            let tip = CGPoint(x: end.x - ux * (inset + 3), y: end.y - uy * (inset + 3))
            var path = Path()
            path.move(to: start)
            path.addLine(to: tip)
            let stroke = edge.incoming
                ? StrokeStyle(lineWidth: 2, lineCap: .round)
                : StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 5])
            ctx.stroke(path, with: .color(hue), style: stroke)

            guard length > 24 else { continue }
            var head = Path()
            let size = 8.0
            head.move(to: tip)
            head.addLine(to: CGPoint(x: tip.x - ux * size - uy * size * 0.55, y: tip.y - uy * size + ux * size * 0.55))
            head.addLine(to: CGPoint(x: tip.x - ux * size + uy * size * 0.55, y: tip.y - uy * size - ux * size * 0.55))
            head.closeSubpath()
            ctx.fill(head, with: .color(hue))
        }
    }

    // MARK: Nodes

    static func isDimmed(_ topic: Topic, style: MapStyle) -> Bool {
        if let filter = style.filter, topic.cluster != filter { return true }
        if let selected = style.selected, topic.id != selected, !style.neighbours.contains(topic.id) { return true }
        return false
    }

    static func drawNodes(_ context: GraphicsContext, scene: MapScene, points: [String: Projected], camera: Camera, style: MapStyle) {
        var ctx = context
        let ordered = scene.atlas.topics.sorted { (points[$0.id]?.depth ?? 0) < (points[$1.id]?.depth ?? 0) }
        for topic in ordered {
            guard let p = points[topic.id] else { continue }
            let isSelected = style.selected == topic.id
            let r = nodeRadius(topic, p: p, zoom: camera.zoom, selected: isSelected)
            let rect = CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)
            let hue = style.hues[topic.id] ?? Theme.accent
            var alpha = fade(p.depth)
            if isDimmed(topic, style: style) { alpha *= 0.28 }
            ctx.opacity = isSelected ? 1 : alpha
            let circle = Path(ellipseIn: rect)
            if style.understood.contains(topic.id) {
                ctx.fill(circle, with: .color(hue))
            } else {
                ctx.fill(circle, with: .color(Theme.paper))
                ctx.stroke(circle, with: .color(hue), lineWidth: max(1.5, 2 * p.scale))
            }
            if isSelected {
                let outer = rect.insetBy(dx: -5, dy: -5)
                ctx.stroke(Path(ellipseIn: outer), with: .color(Theme.ink), lineWidth: 2)
            }
        }
    }

    // MARK: Labels

    static func drawLabels(_ context: GraphicsContext, size: CGSize, scene: MapScene, points: [String: Projected], camera: Camera, style: MapStyle) {
        struct Candidate {
            let topic: Topic
            let p: Projected
            let priority: Int
        }
        var candidates: [Candidate] = []
        let showAll = camera.zoom > 1.7
        for topic in scene.atlas.topics {
            guard let p = points[topic.id] else { continue }
            if topic.id == style.selected {
                candidates.append(Candidate(topic: topic, p: p, priority: 0))
            } else if style.neighbours.contains(topic.id) {
                candidates.append(Candidate(topic: topic, p: p, priority: 1))
            } else if !isDimmed(topic, style: style) && (p.depth > 0.35 || (showAll && p.depth > -0.3)) {
                candidates.append(Candidate(topic: topic, p: p, priority: 2))
            }
        }
        candidates.sort { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
            return lhs.p.depth > rhs.p.depth
        }

        var ctx = context
        var placed: [CGRect] = []
        let bounds = CGRect(origin: .zero, size: size).insetBy(dx: 4, dy: 4)
        let limit = showAll ? 24 : 14
        for candidate in candidates {
            if placed.count >= limit && candidate.priority == 2 { break }
            let isSelected = candidate.priority == 0
            let font: Font = isSelected ? Theme.title(16) : .system(size: 13, weight: .semibold)
            let colour: Color = isSelected ? Theme.paper : Theme.ink
            let resolved = ctx.resolve(Text(candidate.topic.title).font(font).foregroundColor(colour))
            let textSize = resolved.measure(in: CGSize(width: 220, height: 60))
            let r = nodeRadius(candidate.topic, p: candidate.p, zoom: camera.zoom, selected: isSelected)
            let padX: CGFloat = 7
            let padY: CGFloat = 4
            var chip = CGRect(
                x: candidate.p.x - textSize.width / 2 - padX,
                y: candidate.p.y + r + (isSelected ? 9 : 5),
                width: textSize.width + 2 * padX,
                height: textSize.height + 2 * padY
            )
            // Keep chips on screen.
            if chip.minX < bounds.minX { chip.origin.x = bounds.minX }
            if chip.maxX > bounds.maxX { chip.origin.x = bounds.maxX - chip.width }
            if chip.maxY > bounds.maxY { chip.origin.y = candidate.p.y - r - 5 - chip.height }
            let crowded = placed.contains { $0.insetBy(dx: -3, dy: -2).intersects(chip) }
            if crowded && !isSelected { continue }
            placed.append(chip)

            ctx.opacity = isSelected ? 1 : max(0.75, fade(candidate.p.depth))
            let shape = Path(roundedRect: chip, cornerRadius: 7, style: .continuous)
            if isSelected {
                ctx.fill(shape, with: .color(Theme.ink))
            } else {
                ctx.fill(shape, with: .color(Theme.surface))
                ctx.stroke(shape, with: .color(Theme.line), lineWidth: 1)
            }
            ctx.draw(resolved, at: CGPoint(x: chip.midX, y: chip.midY))
        }
    }
}
