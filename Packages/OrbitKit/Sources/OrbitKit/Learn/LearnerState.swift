import Foundation

public enum PlaybackSpeed: String, Codable, CaseIterable, Sendable, Identifiable {
    case slow, normal, fast

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .slow: return "Slow"
        case .normal: return "Normal"
        case .fast: return "Fast"
        }
    }

    /// Seconds each simulation frame stays on screen while playing.
    public var secondsPerFrame: Double {
        switch self {
        case .slow: return 2.8
        case .normal: return 1.6
        case .fast: return 0.9
        }
    }
}

public struct LearnerSettings: Codable, Hashable, Sendable {
    /// Tuned for people who can't form mental images: everything stays visible and labelled,
    /// diagrams come first, and nothing moves unless you ask it to.
    public var aphantasiaMode: Bool
    public var depth: Depth
    public var playback: PlaybackSpeed
    public var mapLayout: MapLayout

    public init(aphantasiaMode: Bool = false, depth: Depth = .intro, playback: PlaybackSpeed = .normal, mapLayout: MapLayout = .orbit) {
        self.aphantasiaMode = aphantasiaMode
        self.depth = depth
        self.playback = playback
        self.mapLayout = mapLayout
    }

    private enum CodingKeys: String, CodingKey { case aphantasiaMode, depth, playback, mapLayout }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        aphantasiaMode = try c.decodeIfPresent(Bool.self, forKey: .aphantasiaMode) ?? false
        depth = (try? c.decodeIfPresent(Depth.self, forKey: .depth)) ?? .intro
        playback = (try? c.decodeIfPresent(PlaybackSpeed.self, forKey: .playback)) ?? .normal
        mapLayout = (try? c.decodeIfPresent(MapLayout.self, forKey: .mapLayout)) ?? .orbit
    }
}

/// Everything Orbit remembers about one learner. Stored as a small JSON file on device.
public struct LearnerState: Codable, Hashable, Sendable {
    public var visited: [String: Date]
    public var understood: Set<String>
    public var cards: [String: CardState]
    public var settings: LearnerSettings
    public var reviewsDone: Int
    public var onboarded: Bool

    public init() {
        visited = [:]
        understood = []
        cards = [:]
        settings = LearnerSettings()
        reviewsDone = 0
        onboarded = false
    }

    private enum CodingKeys: String, CodingKey { case visited, understood, cards, settings, reviewsDone, onboarded }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        visited = try c.decodeIfPresent([String: Date].self, forKey: .visited) ?? [:]
        understood = try c.decodeIfPresent(Set<String>.self, forKey: .understood) ?? []
        cards = try c.decodeIfPresent([String: CardState].self, forKey: .cards) ?? [:]
        settings = (try? c.decodeIfPresent(LearnerSettings.self, forKey: .settings)) ?? LearnerSettings()
        reviewsDone = try c.decodeIfPresent(Int.self, forKey: .reviewsDone) ?? 0
        onboarded = try c.decodeIfPresent(Bool.self, forKey: .onboarded) ?? false
    }

    public mutating func visit(_ id: String, now: Date) {
        visited[id] = now
    }

    /// "I get it": the topic joins the review queue.
    public mutating func markUnderstood(_ id: String, now: Date) {
        understood.insert(id)
        if cards[id] == nil { cards[id] = .new(now: now) }
    }

    public mutating func unmarkUnderstood(_ id: String) {
        understood.remove(id)
        cards[id] = nil
    }

    public mutating func record(_ id: String, recall: Recall, now: Date) {
        let card = cards[id] ?? .new(now: now)
        cards[id] = Scheduler.review(card, recall: recall, now: now)
        reviewsDone += 1
    }

    /// Topics due for review, most overdue first.
    public func due(now: Date) -> [String] {
        cards.filter { $0.value.due <= now }
            .sorted { lhs, rhs in
                if lhs.value.due != rhs.value.due { return lhs.value.due < rhs.value.due }
                return lhs.key < rhs.key
            }
            .map(\.key)
    }

    /// Upcoming reviews, soonest first.
    public func upcoming(now: Date, limit: Int = 5) -> [(id: String, due: Date)] {
        let later = cards.filter { $0.value.due > now }
            .sorted { $0.value.due < $1.value.due }
            .prefix(limit)
        return later.map { (id: $0.key, due: $0.value.due) }
    }
}

/// Reads and writes `LearnerState` atomically. A missing or corrupt file gives a fresh state.
public struct StateStore: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Orbit", isDirectory: true).appendingPathComponent("learner.json")
    }

    public func load() -> LearnerState {
        guard let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(LearnerState.self, from: data) else {
            return LearnerState()
        }
        return state
    }

    public func save(_ state: LearnerState) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(state).write(to: url, options: .atomic)
    }
}
