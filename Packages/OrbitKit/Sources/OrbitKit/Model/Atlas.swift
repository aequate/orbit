import Foundation

/// The whole knowledge map: clusters, topics, comparisons and journeys, plus graph queries.
///
/// Edges point from a prerequisite to the topic that needs it, so the map is a
/// directed acyclic graph with foundations at the bottom.
public struct Atlas: Sendable {
    public let clusters: [Cluster]
    public let topics: [Topic]
    public let comparisons: [Comparison]
    public let journeys: [Journey]

    private let topicIndex: [String: Int]
    private let clusterIndex: [String: Int]
    private let dependentIDs: [String: [String]]
    private let depths: [String: Int]

    public init(clusters: [Cluster], topics: [Topic], comparisons: [Comparison] = [], journeys: [Journey] = []) {
        self.clusters = clusters
        self.topics = topics
        self.comparisons = comparisons
        self.journeys = journeys

        var topicIndex: [String: Int] = [:]
        for (i, topic) in topics.enumerated() where topicIndex[topic.id] == nil {
            topicIndex[topic.id] = i
        }
        self.topicIndex = topicIndex

        var clusterIndex: [String: Int] = [:]
        for (i, cluster) in clusters.enumerated() { clusterIndex[cluster.id] = i }
        self.clusterIndex = clusterIndex

        var dependents: [String: [String]] = [:]
        for topic in topics {
            for req in topic.requires where topicIndex[req] != nil {
                dependents[req, default: []].append(topic.id)
            }
        }
        self.dependentIDs = dependents
        self.depths = Atlas.computeDepths(topics: topics, index: topicIndex)
    }

    // MARK: Loading

    /// Content files, one per cluster, in map order (foundations first).
    public static let clusterFiles = ["math", "machine", "data", "algorithms", "networks", "ml"]

    private struct ClusterFile: Decodable {
        let cluster: Cluster
        let topics: [Topic]
    }

    private struct ExtrasFile: Decodable {
        let comparisons: [Comparison]
        let journeys: [Journey]
    }

    public enum LoadError: Error, CustomStringConvertible {
        case missing(String)

        public var description: String {
            switch self {
            case .missing(let name): return "Missing bundled content file \(name).json"
            }
        }
    }

    /// Loads the hand-written content that ships with the app.
    public static func bundled() throws -> Atlas {
        let decoder = JSONDecoder()
        var clusters: [Cluster] = []
        var topics: [Topic] = []
        for name in clusterFiles {
            let file = try decoder.decode(ClusterFile.self, from: try resource(name))
            clusters.append(file.cluster)
            topics.append(contentsOf: file.topics)
        }
        let extras = try decoder.decode(ExtrasFile.self, from: try resource("extras"))
        return Atlas(clusters: clusters, topics: topics, comparisons: extras.comparisons, journeys: extras.journeys)
    }

    private static func resource(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
            throw LoadError.missing(name)
        }
        return try Data(contentsOf: url)
    }

    // MARK: Lookup

    public func topic(_ id: String) -> Topic? {
        topicIndex[id].map { topics[$0] }
    }

    public func cluster(_ id: String) -> Cluster? {
        clusterIndex[id].map { clusters[$0] }
    }

    public func cluster(of topicID: String) -> Cluster? {
        topic(topicID).flatMap { cluster($0.cluster) }
    }

    public func clusterPosition(_ id: String) -> Int {
        clusterIndex[id] ?? 0
    }

    public func comparison(_ id: String) -> Comparison? {
        comparisons.first { $0.id == id }
    }

    public func journey(_ id: String) -> Journey? {
        journeys.first { $0.id == id }
    }

    public func topics(in clusterID: String) -> [Topic] {
        topics.filter { $0.cluster == clusterID }
    }

    /// All (prerequisite, topic) pairs.
    public var links: [(from: String, to: String)] {
        var result: [(from: String, to: String)] = []
        for topic in topics {
            for req in topic.requires where topicIndex[req] != nil {
                result.append((from: req, to: topic.id))
            }
        }
        return result
    }

    // MARK: Graph queries

    /// Direct prerequisites.
    public func prerequisites(of id: String) -> [Topic] {
        (topic(id)?.requires ?? []).compactMap { topic($0) }
    }

    /// Topics that list `id` as a direct prerequisite.
    public func dependents(of id: String) -> [Topic] {
        (dependentIDs[id] ?? []).compactMap { topic($0) }
    }

    /// Longest chain of prerequisites below a topic. Foundations are 0.
    public func depth(of id: String) -> Int {
        depths[id] ?? 0
    }

    public var maxDepth: Int {
        depths.values.max() ?? 0
    }

    /// Every prerequisite, direct or indirect, ordered so each one comes after the things it needs.
    /// This is the "prerequisite tunnel": read it top to bottom and nothing is assumed.
    public func tunnel(to id: String) -> [Topic] {
        var ordered: [String] = []
        var seen: Set<String> = [id]
        func visit(_ current: String) {
            for req in topic(current)?.requires ?? [] where !seen.contains(req) && topicIndex[req] != nil {
                seen.insert(req)
                visit(req)
                ordered.append(req)
            }
        }
        visit(id)
        return ordered.compactMap { topic($0) }
    }

    /// Every topic that builds on `id`, directly or indirectly.
    public func downstream(of id: String) -> Set<String> {
        var seen: Set<String> = []
        var frontier = dependentIDs[id] ?? []
        while let next = frontier.popLast() {
            if seen.insert(next).inserted {
                frontier.append(contentsOf: dependentIDs[next] ?? [])
            }
        }
        return seen
    }

    /// Answers "why learn this?": a chain from the topic to the furthest showcase idea it unlocks.
    /// Starts with the topic itself. Returns just the topic when nothing builds on it.
    public func whyPath(from id: String) -> [Topic] {
        guard topicIndex[id] != nil else { return [] }
        var distance: [String: Int] = [id: 0]
        var parent: [String: String] = [:]
        var queue = [id]
        var head = 0
        while head < queue.count {
            let current = queue[head]
            head += 1
            for next in dependentIDs[current] ?? [] where distance[next] == nil {
                distance[next] = distance[current]! + 1
                parent[next] = current
                queue.append(next)
            }
        }
        // Prefer the furthest destination; otherwise the furthest topic. Ties go to the first in BFS order.
        let reachable = queue.dropFirst()
        guard !reachable.isEmpty else { return [topic(id)!] }
        let destinations = reachable.filter { topic($0)?.destination == true }
        let pool = destinations.isEmpty ? Array(reachable) : Array(destinations)
        var target = pool[0]
        for candidate in pool where distance[candidate]! > distance[target]! {
            target = candidate
        }
        var path = [target]
        while let up = parent[path[path.count - 1]] {
            path.append(up)
        }
        return path.reversed().compactMap { topic($0) }
    }

    public func comparisons(involving id: String) -> [Comparison] {
        comparisons.filter { $0.left.topic == id || $0.right.topic == id }
    }

    public func journeys(containing id: String) -> [Journey] {
        journeys.filter { $0.topics.contains(id) }
    }

    // MARK: Validation

    /// Everything wrong with the content, as readable messages. Empty means healthy.
    public func issues() -> [String] {
        var problems: [String] = []
        if topicIndex.count != topics.count { problems.append("duplicate topic ids") }
        let clusterIDs = Set(clusters.map(\.id))
        for topic in topics {
            if !clusterIDs.contains(topic.cluster) {
                problems.append("\(topic.id): unknown cluster \(topic.cluster)")
            }
            for req in topic.requires where topicIndex[req] == nil {
                problems.append("\(topic.id): unknown prerequisite \(req)")
            }
            if topic.requires.contains(topic.id) {
                problems.append("\(topic.id): requires itself")
            }
            for sim in topic.simulations where !Simulations.ids.contains(sim) {
                problems.append("\(topic.id): unknown simulation \(sim)")
            }
            if topic.sources.isEmpty { problems.append("\(topic.id): no sources") }
            for source in topic.sources where URL(string: source.url)?.scheme != "https" {
                problems.append("\(topic.id): source is not an https URL: \(source.url)")
            }
            for level in Depth.allCases where topic.levels.text(for: level).count < 40 {
                problems.append("\(topic.id): \(level.rawValue) text is too short")
            }
            if let diagram = topic.diagram {
                for issue in diagram.issues() { problems.append("\(topic.id) diagram: \(issue)") }
            }
        }
        if hasCycle() { problems.append("prerequisites contain a cycle") }
        for comparison in comparisons {
            for side in [comparison.left, comparison.right] {
                if let id = side.topic, topicIndex[id] == nil {
                    problems.append("comparison \(comparison.id): unknown topic \(id)")
                }
            }
            if comparison.rows.isEmpty { problems.append("comparison \(comparison.id): no rows") }
        }
        for journey in journeys {
            for (step, id) in journey.topics.enumerated() {
                guard let topic = topic(id) else {
                    problems.append("journey \(journey.id): unknown topic \(id)")
                    continue
                }
                // A step must not depend on something the journey only teaches later.
                let later = Set(journey.topics.dropFirst(step + 1))
                for req in topic.requires where later.contains(req) {
                    problems.append("journey \(journey.id): \(id) comes before its prerequisite \(req)")
                }
            }
        }
        return problems
    }

    private func hasCycle() -> Bool {
        var state: [String: Int] = [:]  // 1 = visiting, 2 = done
        func visit(_ id: String) -> Bool {
            if state[id] == 1 { return true }
            if state[id] == 2 { return false }
            state[id] = 1
            for req in topic(id)?.requires ?? [] where topicIndex[req] != nil {
                if visit(req) { return true }
            }
            state[id] = 2
            return false
        }
        return topics.contains { visit($0.id) }
    }

    private static func computeDepths(topics: [Topic], index: [String: Int]) -> [String: Int] {
        var memo: [String: Int] = [:]
        var visiting: Set<String> = []
        func depth(_ id: String) -> Int {
            if let known = memo[id] { return known }
            guard let i = index[id], visiting.insert(id).inserted else { return 0 }
            let reqs = topics[i].requires.filter { index[$0] != nil }
            let value = reqs.isEmpty ? 0 : (reqs.map(depth).max() ?? 0) + 1
            visiting.remove(id)
            memo[id] = value
            return value
        }
        for topic in topics { _ = depth(topic.id) }
        return memo
    }
}
