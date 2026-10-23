import Foundation

/// A small labelled diagram that is built up one step at a time.
///
/// Each step reveals (and occasionally hides) nodes and edges, so a learner never has to
/// hold a picture in their head: everything shown so far stays on screen, in place.
/// Coordinates are normalised to a 4:3 frame, 0...1 on both axes, origin top-left.
public struct Diagram: Codable, Hashable, Sendable {
    public enum Role: String, Codable, Sendable {
        /// Rounded rectangle with a label.
        case box
        /// Capsule with a label.
        case pill
        /// Small filled circle with the label underneath.
        case dot
        /// Plain text, no outline.
        case note
        /// Invisible point, used as an arrow endpoint (e.g. on a sequence-diagram lifeline).
        case anchor
    }

    public enum EdgeStyle: String, Codable, Sendable {
        case arrow, dashed, line, both
    }

    public struct Node: Codable, Hashable, Sendable, Identifiable {
        public let id: String
        public let label: String
        public let x: Double
        public let y: Double
        public let role: Role

        public init(id: String, label: String, x: Double, y: Double, role: Role = .box) {
            self.id = id
            self.label = label
            self.x = x
            self.y = y
            self.role = role
        }

        private enum CodingKeys: String, CodingKey { case id, label, x, y, role }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
            x = try c.decode(Double.self, forKey: .x)
            y = try c.decode(Double.self, forKey: .y)
            role = try c.decodeIfPresent(Role.self, forKey: .role) ?? .box
        }
    }

    public struct Edge: Codable, Hashable, Sendable, Identifiable {
        public let from: String
        public let to: String
        public let label: String?
        public let style: EdgeStyle

        public var id: String { "\(from)>\(to)" }

        public init(from: String, to: String, label: String? = nil, style: EdgeStyle = .arrow) {
            self.from = from
            self.to = to
            self.label = label
            self.style = style
        }

        private enum CodingKeys: String, CodingKey { case from, to, label, style }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            from = try c.decode(String.self, forKey: .from)
            to = try c.decode(String.self, forKey: .to)
            label = try c.decodeIfPresent(String.self, forKey: .label)
            style = try c.decodeIfPresent(EdgeStyle.self, forKey: .style) ?? .arrow
        }
    }

    public struct Step: Codable, Hashable, Sendable {
        public let caption: String
        /// Node ids or edge ids ("from>to") revealed at this step.
        public let show: [String]
        /// Ids removed at this step (e.g. a pointer that gets rewired).
        public let hide: [String]

        public init(caption: String, show: [String], hide: [String] = []) {
            self.caption = caption
            self.show = show
            self.hide = hide
        }

        private enum CodingKeys: String, CodingKey { case caption, show, hide }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            caption = try c.decode(String.self, forKey: .caption)
            show = try c.decodeIfPresent([String].self, forKey: .show) ?? []
            hide = try c.decodeIfPresent([String].self, forKey: .hide) ?? []
        }
    }

    public let nodes: [Node]
    public let edges: [Edge]
    public let steps: [Step]

    public init(nodes: [Node], edges: [Edge], steps: [Step]) {
        self.nodes = nodes
        self.edges = edges
        self.steps = steps
    }

    /// Everything on screen after `step` (0-based). Showing an edge also shows its endpoints.
    public func visible(through step: Int) -> Set<String> {
        guard !steps.isEmpty, step >= 0 else { return [] }
        var ids = Set<String>()
        for index in 0...min(step, steps.count - 1) {
            ids.formUnion(steps[index].show)
            ids.subtract(steps[index].hide)
        }
        for edge in edges where ids.contains(edge.id) {
            ids.insert(edge.from)
            ids.insert(edge.to)
        }
        return ids
    }

    /// Ids that appear for the first time at `step`, highlighted so the eye knows where to go.
    public func fresh(at step: Int) -> Set<String> {
        visible(through: step).subtracting(visible(through: step - 1))
    }

    /// Authoring problems: dangling references, out-of-frame nodes, things never shown.
    public func issues() -> [String] {
        var problems: [String] = []
        let nodeIDs = Set(nodes.map(\.id))
        let edgeIDs = Set(edges.map(\.id))
        if nodeIDs.count != nodes.count { problems.append("duplicate node ids") }
        if edgeIDs.count != edges.count { problems.append("duplicate edge ids") }
        if steps.isEmpty { problems.append("no steps") }
        for node in nodes where !(0...1).contains(node.x) || !(0...1).contains(node.y) {
            problems.append("node \(node.id) is outside the frame")
        }
        for edge in edges {
            if !nodeIDs.contains(edge.from) { problems.append("edge \(edge.id) has unknown start") }
            if !nodeIDs.contains(edge.to) { problems.append("edge \(edge.id) has unknown end") }
        }
        let known = nodeIDs.union(edgeIDs)
        for (index, step) in steps.enumerated() {
            for id in step.show + step.hide where !known.contains(id) {
                problems.append("step \(index + 1) refers to unknown id \(id)")
            }
            if step.caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                problems.append("step \(index + 1) has no caption")
            }
        }
        var everShown = Set<String>()
        for index in steps.indices { everShown.formUnion(visible(through: index)) }
        for id in known.subtracting(everShown).sorted() {
            problems.append("\(id) is never shown")
        }
        return problems
    }
}
