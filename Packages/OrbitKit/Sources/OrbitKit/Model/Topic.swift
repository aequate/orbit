import Foundation

/// How deep an explanation goes.
public enum Depth: String, Codable, CaseIterable, Sendable, Identifiable {
    case intro, core, deep

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .intro: return "Simple"
        case .core: return "Core"
        case .deep: return "Deeper"
        }
    }
}

/// A subject area. Each cluster gets its own colour and region on the map.
public struct Cluster: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let blurb: String
    /// Palette key the app maps to a colour (blue, green, orange, violet, rose, teal).
    public let hue: String

    public init(id: String, name: String, blurb: String, hue: String) {
        self.id = id
        self.name = name
        self.blurb = blurb
        self.hue = hue
    }
}

public struct SourceLink: Codable, Hashable, Sendable {
    public let title: String
    public let url: String

    public init(title: String, url: String) {
        self.title = title
        self.url = url
    }
}

/// The same idea explained at three depths.
public struct Levels: Codable, Hashable, Sendable {
    public let intro: String
    public let core: String
    public let deep: String

    public init(intro: String, core: String, deep: String) {
        self.intro = intro
        self.core = core
        self.deep = deep
    }

    public func text(for depth: Depth) -> String {
        switch depth {
        case .intro: return intro
        case .core: return core
        case .deep: return deep
        }
    }
}

/// One concept on the map. Content is hand-written and sourced, never generated.
public struct Topic: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let cluster: String
    public let aliases: [String]
    public let summary: String
    public let levels: Levels
    public let analogy: String?
    /// Direct prerequisites: topics you should understand first.
    public let requires: [String]
    public let realWorld: [String]
    public let sources: [SourceLink]
    /// Ids of step-by-step simulations (see `Simulations`).
    public let simulations: [String]
    /// A hand-authored visual build, revealed one step at a time.
    public let diagram: Diagram?
    /// Showcase topics that "why does this matter" paths prefer to lead to.
    public let destination: Bool

    public init(
        id: String, title: String, cluster: String, aliases: [String] = [], summary: String,
        levels: Levels, analogy: String? = nil, requires: [String] = [], realWorld: [String] = [],
        sources: [SourceLink] = [], simulations: [String] = [], diagram: Diagram? = nil,
        destination: Bool = false
    ) {
        self.id = id
        self.title = title
        self.cluster = cluster
        self.aliases = aliases
        self.summary = summary
        self.levels = levels
        self.analogy = analogy
        self.requires = requires
        self.realWorld = realWorld
        self.sources = sources
        self.simulations = simulations
        self.diagram = diagram
        self.destination = destination
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, cluster, aliases, summary, levels, analogy, requires, realWorld, sources
        case simulations, diagram, destination
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        cluster = try c.decode(String.self, forKey: .cluster)
        aliases = try c.decodeIfPresent([String].self, forKey: .aliases) ?? []
        summary = try c.decode(String.self, forKey: .summary)
        levels = try c.decode(Levels.self, forKey: .levels)
        analogy = try c.decodeIfPresent(String.self, forKey: .analogy)
        requires = try c.decodeIfPresent([String].self, forKey: .requires) ?? []
        realWorld = try c.decodeIfPresent([String].self, forKey: .realWorld) ?? []
        sources = try c.decodeIfPresent([SourceLink].self, forKey: .sources) ?? []
        simulations = try c.decodeIfPresent([String].self, forKey: .simulations) ?? []
        diagram = try c.decodeIfPresent(Diagram.self, forKey: .diagram)
        destination = try c.decodeIfPresent(Bool.self, forKey: .destination) ?? false
    }
}

/// Two ideas laid side by side, aspect by aspect.
public struct Comparison: Codable, Hashable, Sendable, Identifiable {
    public struct Side: Codable, Hashable, Sendable {
        public let name: String
        public let topic: String?

        public init(name: String, topic: String? = nil) {
            self.name = name
            self.topic = topic
        }
    }

    public struct Row: Codable, Hashable, Sendable {
        public let aspect: String
        public let left: String
        public let right: String

        public init(aspect: String, left: String, right: String) {
            self.aspect = aspect
            self.left = left
            self.right = right
        }
    }

    public let id: String
    public let left: Side
    public let right: Side
    public let rows: [Row]
    public let takeaway: String

    public var title: String { "\(left.name) vs \(right.name)" }

    public init(id: String, left: Side, right: Side, rows: [Row], takeaway: String) {
        self.id = id
        self.left = left
        self.right = right
        self.rows = rows
        self.takeaway = takeaway
    }
}

/// A curated, ordered path through the map.
public struct Journey: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let blurb: String
    public let topics: [String]

    public init(id: String, title: String, blurb: String, topics: [String]) {
        self.id = id
        self.title = title
        self.blurb = blurb
        self.topics = topics
    }

    public struct Progress: Hashable, Sendable {
        public let done: Int
        public let total: Int
        /// The first step not yet understood, or nil when the journey is complete.
        public let next: String?

        public var fraction: Double { total == 0 ? 0 : Double(done) / Double(total) }
        public var isComplete: Bool { next == nil }
        public var isStarted: Bool { done > 0 }
    }

    public func progress(understood: Set<String>) -> Progress {
        let done = topics.filter { understood.contains($0) }.count
        let next = topics.first { !understood.contains($0) }
        return Progress(done: done, total: topics.count, next: next)
    }
}
