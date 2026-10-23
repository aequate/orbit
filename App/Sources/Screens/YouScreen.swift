import SwiftUI
import OrbitKit

/// Progress and preferences.
struct YouScreen: View {
    @Environment(AppModel.self) private var model
    @State private var confirmReset = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Text("You")
                    .font(Theme.title(32))
                    .foregroundStyle(Theme.ink)
                stats
                ReadySection()
                clusters
                settings
                about
                Button("Reset progress", role: .destructive) { confirmReset = true }
                    .font(.system(.callout, weight: .semibold))
                    .foregroundStyle(Theme.bad)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 12)
        }
        .background(Theme.paper)
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("Reset all progress?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset progress", role: .destructive) {
                model.update { state in
                    let settings = state.settings
                    state = LearnerState()
                    state.settings = settings
                    state.onboarded = true
                }
            }
        } message: {
            Text("This clears what you've understood and your review schedule. Your settings stay.")
        }
    }

    // MARK: Progress

    private var stats: some View {
        HStack(spacing: 10) {
            StatTile(value: model.state.understood.count, label: "understood")
            StatTile(value: model.state.visited.count, label: "explored")
            StatTile(value: model.state.reviewsDone, label: "reviews")
        }
    }

    private var clusters: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("By area")
            VStack(alignment: .leading, spacing: 16) {
                ForEach(model.atlas.clusters) { cluster in
                    let topics = model.atlas.topics(in: cluster.id)
                    let done = topics.filter { model.isUnderstood($0.id) }.count
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            ClusterTag(cluster: cluster)
                            Spacer()
                            Text(String(done) + " / " + String(topics.count))
                                .font(.system(.footnote, weight: .semibold).monospacedDigit())
                                .foregroundStyle(Theme.inkSoft)
                        }
                        ProgressLine(fraction: topics.isEmpty ? 0 : Double(done) / Double(topics.count), tint: Theme.hue(cluster.hue))
                    }
                }
            }
            .surface()
        }
    }

    // MARK: Settings

    private var settings: some View {
        let aphantasia = Binding<Bool>(
            get: { model.settings.aphantasiaMode },
            set: { value in model.update { $0.settings.aphantasiaMode = value } }
        )
        let depth = Binding<Depth>(
            get: { model.settings.depth },
            set: { value in model.update { $0.settings.depth = value } }
        )
        let playback = Binding<PlaybackSpeed>(
            get: { model.settings.playback },
            set: { value in model.update { $0.settings.playback = value } }
        )
        let layout = Binding<MapLayout>(
            get: { model.settings.mapLayout },
            set: { value in model.update { $0.settings.mapLayout = value } }
        )
        return VStack(alignment: .leading, spacing: 10) {
            SectionLabel("How Orbit shows things")
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: aphantasia) {
                        Text("Aphantasia mode")
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                    }
                    .tint(Theme.accent)
                    Text("For people who can't picture things in their mind. Ideas open on the step-by-step build, every caption so far stays on screen, and the tutor never asks you to imagine anything.")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Divider().overlay(Theme.line)
                setting("Explanation depth") {
                    Segmented(options: Depth.allCases, selection: depth) { $0.title }
                }
                setting("Simulation speed") {
                    Segmented(options: PlaybackSpeed.allCases, selection: playback) { $0.title }
                }
                setting("Map shape") {
                    Segmented(options: MapLayout.allCases, selection: layout) { $0.title }
                }
            }
            .surface()
        }
    }

    private func setting<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
            content()
        }
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("About the content")
            VStack(alignment: .leading, spacing: 10) {
                Text(Words.join([String(model.atlas.topics.count), " ideas across ", String(model.atlas.clusters.count), " areas, written by hand and linked to their sources."]))
                    .font(Theme.body)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Simulations run the real algorithm, step by step. Answers from the Ask panel are labelled: reviewed notes, or Apple's on-device model, which can make mistakes. Nothing you do leaves your iPhone.")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .surface()
        }
    }
}

private struct StatTile: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(String(value))
                .font(Theme.title(28).monospacedDigit())
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(Theme.caption)
                .foregroundStyle(Theme.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .surface(padding: 14)
        .accessibilityElement(children: .combine)
    }
}
