import Foundation

extension Atlas {
    /// An automatic visual build for any topic: what it needs on the left, the topic in the
    /// middle, what it unlocks on the right. Used when a topic has no hand-drawn diagram.
    public func contextDiagram(for id: String, limit: Int = 4) -> Diagram? {
        guard let topic = topic(id) else { return nil }
        let before = Array(prerequisites(of: id).prefix(limit))
        let after = Array(dependents(of: id).prefix(limit))

        var nodes = [Diagram.Node(id: "center", label: topic.title, x: 0.5, y: 0.5, role: .box)]
        var edges: [Diagram.Edge] = []
        var steps = [Diagram.Step(caption: "\(topic.title): \(topic.summary)", show: ["center"])]

        func column(_ items: [Topic], x: Double, prefix: String) -> [String] {
            var ids: [String] = []
            for (i, item) in items.enumerated() {
                let offset = Double(i) - Double(items.count - 1) / 2
                let y = min(0.9, max(0.1, 0.5 + offset * 0.22))
                let nodeID = "\(prefix)\(i)"
                nodes.append(Diagram.Node(id: nodeID, label: item.title, x: x, y: y, role: .pill))
                ids.append(nodeID)
            }
            return ids
        }

        if before.isEmpty {
            nodes.append(Diagram.Node(id: "start", label: "Starting point", x: 0.13, y: 0.5, role: .note))
            steps.append(Diagram.Step(caption: "Nothing comes before it: this is a foundation you can start from.", show: ["start"]))
        } else {
            let ids = column(before, x: 0.14, prefix: "b")
            for nodeID in ids { edges.append(Diagram.Edge(from: nodeID, to: "center")) }
            let names = Atlas.list(before.map(\.title))
            steps.append(Diagram.Step(caption: "It builds on \(names). Arrows point from what you need to what it makes possible.", show: ids.map { "\($0)>center" }))
        }

        if after.isEmpty {
            nodes.append(Diagram.Node(id: "end", label: "A destination", x: 0.87, y: 0.5, role: .note))
            steps.append(Diagram.Step(caption: "Nothing on this map builds on it yet: it's one of the places the other ideas lead to.", show: ["end"]))
        } else {
            let ids = column(after, x: 0.86, prefix: "a")
            for nodeID in ids { edges.append(Diagram.Edge(from: "center", to: nodeID)) }
            let names = Atlas.list(after.map(\.title))
            steps.append(Diagram.Step(caption: "Once you have it, it unlocks \(names).", show: ids.map { "center>\($0)" }))
        }

        return Diagram(nodes: nodes, edges: edges, steps: steps)
    }

    /// "A", "A and B", "A, B and C".
    public static func list(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        default: return items.dropLast().joined(separator: ", ") + " and " + items[items.count - 1]
        }
    }
}

extension Atlas {
    /// Ranked title/alias/summary search. Empty query returns nothing.
    public func search(_ query: String, limit: Int = 25) -> [Topic] {
        let q = Atlas.normalise(query)
        guard !q.isEmpty else { return [] }
        var scored: [(topic: Topic, score: Int)] = []
        for topic in topics {
            let score = Atlas.score(topic, query: q)
            if score > 0 { scored.append((topic: topic, score: score)) }
        }
        scored.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.topic.title < rhs.topic.title
        }
        return scored.prefix(limit).map(\.topic)
    }

    static func normalise(_ text: String) -> String {
        let lowered = text.lowercased().replacingOccurrences(of: "-", with: " ")
        return lowered.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func score(_ topic: Topic, query q: String) -> Int {
        let title = normalise(topic.title)
        if title == q { return 100 }
        if title.hasPrefix(q) { return 80 }
        let words = title.split(separator: " ").map(String.init)
        if words.contains(where: { $0.hasPrefix(q) }) { return 65 }
        for alias in topic.aliases.map(normalise) {
            if alias == q { return 60 }
            if alias.hasPrefix(q) { return 50 }
        }
        if title.contains(q) { return 40 }
        if topic.aliases.map(normalise).contains(where: { $0.contains(q) }) { return 30 }
        if q.count >= 3 && normalise(topic.summary).contains(q) { return 15 }
        return 0
    }
}
