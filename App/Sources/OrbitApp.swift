import SwiftUI
import OrbitKit

@main
struct OrbitApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(Theme.accent)
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.tab) {
            NavigationStack(path: $model.mapPath) {
                MapScreen()
                    .orbitDestinations()
            }
            .tabItem { Label("Map", systemImage: "circle.hexagongrid") }
            .tag(AppTab.map)

            NavigationStack(path: $model.journeysPath) {
                JourneysScreen()
                    .orbitDestinations()
            }
            .tabItem { Label("Journeys", systemImage: "point.topleft.down.to.point.bottomright.curvepath") }
            .tag(AppTab.journeys)

            NavigationStack(path: $model.reviewPath) {
                ReviewScreen()
                    .orbitDestinations()
            }
            .tabItem { Label("Review", systemImage: "rectangle.stack") }
            .badge(model.dueCount())
            .tag(AppTab.review)

            NavigationStack(path: $model.youPath) {
                YouScreen()
                    .orbitDestinations()
            }
            .tabItem { Label("You", systemImage: "person.crop.circle") }
            .tag(AppTab.you)
        }
        .sheet(isPresented: Binding(
            get: { !model.state.onboarded && model.loadError == nil },
            set: { _ in }
        )) {
            OnboardingSheet()
                .interactiveDismissDisabled()
        }
        .overlay {
            if let error = model.loadError {
                ContentUnavailableView("Content failed to load", systemImage: "exclamationmark.triangle", description: Text(error))
                    .background(Theme.paper)
            }
        }
    }
}

extension View {
    func orbitDestinations() -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .topic(let id): TopicScreen(topicID: id)
            case .compare(let id): CompareScreen(comparisonID: id)
            case .journey(let id): JourneyScreen(journeyID: id)
            }
        }
    }
}
