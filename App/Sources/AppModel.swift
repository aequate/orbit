import SwiftUI
import Observation
import OrbitKit

enum AppTab: Hashable {
    case map, journeys, review, you
}

/// Places you can navigate to from anywhere.
enum Route: Hashable {
    case topic(String)
    case compare(String)
    case journey(String)
}

struct NextUp: Hashable {
    enum Kind: Hashable { case resume, ready }
    let topic: Topic
    let kind: Kind

    var kicker: String {
        switch kind {
        case .resume: return "Pick up where you left off"
        case .ready: return "Ready to learn next"
        }
    }
}

/// App-wide state: the content, the learner's progress, and navigation.
@MainActor
@Observable
final class AppModel {
    let atlas: Atlas
    let loadError: String?
    private(set) var state: LearnerState

    var tab: AppTab = .map
    var mapPath = NavigationPath()
    var journeysPath = NavigationPath()
    var reviewPath = NavigationPath()
    var youPath = NavigationPath()

    /// Set by "Show on map"; the map consumes it and focuses that topic.
    var mapFocusRequest: String?

    @ObservationIgnored private let store: StateStore
    @ObservationIgnored private var simulations: [String: Simulation] = [:]
    @ObservationIgnored private var layouts: [MapLayout: [String: Vec3]] = [:]

    init(store: StateStore = StateStore(url: StateStore.defaultURL())) {
        self.store = store
        do {
            atlas = try Atlas.bundled()
            loadError = nil
        } catch {
            atlas = Atlas(clusters: [], topics: [])
            loadError = String(describing: error)
        }
        state = store.load()
        #if DEBUG
        applyLaunchOptions(UserDefaults.standard)
        #endif
    }

    // MARK: State

    func update(_ change: (inout LearnerState) -> Void) {
        change(&state)
        try? store.save(state)
    }

    var settings: LearnerSettings { state.settings }

    func isUnderstood(_ id: String) -> Bool {
        state.understood.contains(id)
    }

    func toggleUnderstood(_ id: String) {
        update { state in
            if state.understood.contains(id) {
                state.unmarkUnderstood(id)
            } else {
                state.markUnderstood(id, now: Date())
            }
        }
    }

    func dueCount(now: Date = Date()) -> Int {
        state.due(now: now).count
    }

    // MARK: What to learn next

    /// The best single suggestion: pick up the idea you were last on, or start one that's within reach.
    var nextUp: NextUp? {
        if let topic = atlas.unfinished(understood: state.understood, visited: state.visited) {
            return NextUp(topic: topic, kind: .resume)
        }
        if let topic = atlas.ready(understood: state.understood, limit: 1).first {
            return NextUp(topic: topic, kind: .ready)
        }
        return nil
    }

    func readyTopics(limit: Int) -> [Topic] {
        atlas.ready(understood: state.understood, limit: limit)
    }

    // MARK: Cached content

    func simulation(_ id: String) -> Simulation? {
        if let cached = simulations[id] { return cached }
        let made = Simulations.make(id)
        simulations[id] = made
        return made
    }

    func positions(_ layout: MapLayout) -> [String: Vec3] {
        if let cached = layouts[layout] { return cached }
        let made = GraphLayout.positions(for: atlas, layout: layout)
        layouts[layout] = made
        return made
    }

    // MARK: Navigation

    func open(_ route: Route) {
        switch tab {
        case .map: mapPath.append(route)
        case .journeys: journeysPath.append(route)
        case .review: reviewPath.append(route)
        case .you: youPath.append(route)
        }
    }

    func showOnMap(_ id: String) {
        tab = .map
        mapPath = NavigationPath()
        mapFocusRequest = id
    }

    // MARK: Screenshot hooks

    #if DEBUG
    /// Debug-only launch arguments used by CI to take screenshots, e.g.
    /// `-orbitSeed YES -orbitScreen topic:dijkstra -orbitMode play -orbitFrame 6`.
    private func applyLaunchOptions(_ defaults: UserDefaults) {
        if defaults.bool(forKey: "orbitOnboarding") {
            update { $0 = LearnerState() }
        } else if defaults.bool(forKey: "orbitSeed") {
            seedSampleProgress()
        }
        if defaults.bool(forKey: "orbitTower") {
            update { $0.settings.mapLayout = .tower }
        }
        guard let screen = defaults.string(forKey: "orbitScreen") else { return }
        let parts = screen.split(separator: ":", maxSplits: 1).map(String.init)
        let argument = parts.count > 1 ? parts[1] : ""
        switch parts.first ?? "" {
        case "topic":
            tab = .map
            mapPath.append(Route.topic(argument))
        case "compare":
            tab = .map
            mapPath.append(Route.compare(argument))
        case "journeys":
            tab = .journeys
        case "journey":
            tab = .journeys
            journeysPath.append(Route.journey(argument))
        case "review":
            tab = .review
        case "you":
            tab = .you
        default:
            tab = .map
            if !argument.isEmpty { mapFocusRequest = argument }
        }
    }

    /// A believable learner a few days in: foundations understood, some reviews due, one idea in progress.
    private func seedSampleProgress() {
        let atlas = self.atlas
        let now = Date()
        update { state in
            var fresh = LearnerState()
            fresh.onboarded = true
            fresh.reviewsDone = 7
            let foundations = atlas.topics.filter { $0.requires.isEmpty }.map(\.id)
            for (index, id) in foundations.prefix(8).enumerated() {
                let when = now.addingTimeInterval(-Double(index + 2) * 86_400)
                fresh.visit(id, now: when)
                fresh.markUnderstood(id, now: when)
            }
            for id in foundations.prefix(4) {
                fresh.record(id, recall: .solid, now: now.addingTimeInterval(-86_400))
            }
            if let next = atlas.ready(understood: fresh.understood, limit: 1).first {
                fresh.visit(next.id, now: now.addingTimeInterval(-3_600))
            }
            state = fresh
        }
    }
    #endif
}
