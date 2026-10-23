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
}
