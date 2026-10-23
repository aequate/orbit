import SwiftUI
import OrbitKit

enum TopicMode: String, CaseIterable, Hashable {
    case read, build, play

    var title: String {
        switch self {
        case .read: return "Read"
        case .build: return "Build"
        case .play: return "Play"
        }
    }
}

/// One idea, seen several ways: words, a step-by-step build, and a simulation to play with.
struct TopicScreen: View {
    @Environment(AppModel.self) private var model
    let topicID: String

    @State private var mode: TopicMode?
    @State private var showConnections = false
    @State private var simIndex = 0

    var body: some View {
        if let topic = model.atlas.topic(topicID) {
            content(topic)
        } else {
            ContentUnavailableView("Idea not found", systemImage: "questionmark.circle")
        }
    }

    private func content(_ topic: Topic) -> some View {
        let hue = model.atlas.hue(of: topic.id)
        return ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                TopicHeader(topic: topic)
                modeSection(topic, hue: hue)
                TunnelSection(topic: topic)
                LeadsSection(topic: topic)
                CompareSection(topic: topic)
                if !topic.realWorld.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel("In the real world")
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(topic.realWorld, id: \.self) { item in
                                HStack(alignment: .firstTextBaseline, spacing: 10) {
                                    Rectangle().fill(hue).frame(width: 6, height: 6)
                                    Text(item)
                                        .font(Theme.body)
                                        .foregroundStyle(Theme.ink)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .surface()
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel("Ask")
                    AskPanel(topic: topic)
                }
                SourcesSection(topic: topic)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Theme.paper)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    model.showOnMap(topic.id)
                } label: {
                    Label("Show on map", systemImage: "circle.hexagongrid")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            UnderstoodBar(topic: topic)
        }
        .onAppear {
            model.update { $0.visit(topic.id, now: Date()) }
        }
    }

    // MARK: Modes

    private func modes(for topic: Topic) -> [TopicMode] {
        topic.simulations.isEmpty ? [.read, .build] : [.read, .build, .play]
    }

    private func currentMode(_ topic: Topic) -> TopicMode {
        if let mode, modes(for: topic).contains(mode) { return mode }
        return model.settings.aphantasiaMode ? .build : .read
    }

    private func modeSection(_ topic: Topic, hue: Color) -> some View {
        let current = currentMode(topic)
        let binding = Binding<TopicMode>(get: { current }, set: { mode = $0 })
        return VStack(alignment: .leading, spacing: 16) {
            Segmented(options: modes(for: topic), selection: binding) { $0.title }
            switch current {
            case .read:
                ReadView(topic: topic)
            case .build:
                buildView(topic, hue: hue)
            case .play:
                playView(topic, hue: hue)
            }
        }
    }

    @ViewBuilder
    private func buildView(_ topic: Topic, hue: Color) -> some View {
        let aphantasia = model.settings.aphantasiaMode
        if let diagram = topic.diagram {
            VStack(alignment: .leading, spacing: 14) {
                Segmented(options: [false, true], selection: $showConnections) { $0 ? "Connections" : "How it works" }
                if showConnections {
                    connections(topic, hue: hue, keep: aphantasia)
                } else {
                    DiagramPlayer(diagram: diagram, hue: hue, keepCaptions: aphantasia)
                        .id(topic.id + "-diagram")
                }
            }
        } else {
            connections(topic, hue: hue, keep: aphantasia)
        }
    }

    @ViewBuilder
    private func connections(_ topic: Topic, hue: Color, keep: Bool) -> some View {
        if let diagram = model.atlas.contextDiagram(for: topic.id) {
            DiagramPlayer(diagram: diagram, hue: hue, keepCaptions: keep)
                .id(topic.id + "-context")
        }
    }

    @ViewBuilder
    private func playView(_ topic: Topic, hue: Color) -> some View {
        let sims = topic.simulations.compactMap { model.simulation($0) }
        let index = min(simIndex, max(0, sims.count - 1))
        VStack(alignment: .leading, spacing: 14) {
            if sims.count > 1 {
                FlowLayout(spacing: 8) {
                    ForEach(Array(sims.indices), id: \.self) { i in
                        Button(sims[i].title) { simIndex = i }
                            .buttonStyle(ChipButtonStyle(selected: i == index, tint: hue))
                    }
                }
            }
            if sims.indices.contains(index) {
                let sim = sims[index]
                Text(sim.blurb)
                    .font(Theme.body)
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                SimPlayer(simulation: sim, hue: hue, secondsPerFrame: model.settings.playback.secondsPerFrame)
                    .id(sim.id)
            }
        }
    }
}

// MARK: - Header

private struct TopicHeader: View {
    @Environment(AppModel.self) private var model
    let topic: Topic

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ClusterTag(cluster: model.atlas.cluster(topic.cluster))
                Spacer()
                if model.isUnderstood(topic.id) {
                    Label("Understood", systemImage: "checkmark")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.good)
                }
            }
            Text(topic.title)
                .font(Theme.title(34))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(topic.summary)
                .font(Theme.reading)
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Read

private struct ReadView: View {
    @Environment(AppModel.self) private var model
    let topic: Topic

    var body: some View {
        let depth = Binding<Depth>(
            get: { model.settings.depth },
            set: { value in model.update { $0.settings.depth = value } }
        )
        VStack(alignment: .leading, spacing: 16) {
            Segmented(options: Depth.allCases, selection: depth) { $0.title }
            Text(topic.levels.text(for: model.settings.depth))
                .font(Theme.reading)
                .lineSpacing(5)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let analogy = topic.analogy {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("Analogy")
                    Text(analogy)
                        .font(Theme.body)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .surface(Theme.sunken)
            }
        }
    }
}

// MARK: - Before this

private struct TunnelSection: View {
    @Environment(AppModel.self) private var model
    let topic: Topic

    var body: some View {
        let tunnel = model.atlas.tunnel(to: topic.id)
        let done = tunnel.filter { model.isUnderstood($0.id) }.count
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Before this")
            if tunnel.isEmpty {
                Text("Nothing. This is a starting point: you can begin here.")
                    .font(Theme.body)
                    .foregroundStyle(Theme.inkSoft)
                    .surface()
            } else {
                Text("Everything this builds on, in order. Read top to bottom and nothing is assumed. "
                     + String(done) + " of " + String(tunnel.count) + " understood.")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 0) {
                    ForEach(Array(tunnel.enumerated()), id: \.element.id) { pair in
                        TopicRow(topic: pair.element, number: pair.offset + 1)
                        if pair.offset < tunnel.count - 1 {
                            Divider().overlay(Theme.line).padding(.leading, 52)
                        }
                    }
                }
                .surface(padding: 0)
            }
        }
    }
}

/// A tappable row: number (or check), title and summary.
struct TopicRow: View {
    @Environment(AppModel.self) private var model
    let topic: Topic
    var number: Int?
    var tag: String?

    var body: some View {
        let understood = model.isUnderstood(topic.id)
        let hue = model.atlas.hue(of: topic.id)
        Button {
            model.open(.topic(topic.id))
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(understood ? hue : Theme.surface)
                        .overlay(Circle().stroke(hue, lineWidth: 2))
                    if understood {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.paper)
                    } else if let number {
                        Text(String(number))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.ink)
                    }
                }
                .frame(width: 26, height: 26)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(topic.title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        if let tag {
                            Text(tag)
                                .font(Theme.label)
                                .foregroundStyle(hue)
                        }
                    }
                    Text(topic.summary)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.inkSoft)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(understood ? "Understood" : "Not yet")
    }
}

// MARK: - Where this leads

private struct LeadsSection: View {
    @Environment(AppModel.self) private var model
    let topic: Topic

    var body: some View {
        let path = Array(model.atlas.whyPath(from: topic.id).dropFirst())
        let direct = model.atlas.dependents(of: topic.id)
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Where this leads")
            if path.isEmpty {
                Text("Nothing on this map builds on it yet. It's one of the places the other ideas lead to.")
                    .font(Theme.body)
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .surface()
            } else {
                Text("Why learn this? Follow it forward:")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.inkSoft)
                VStack(alignment: .leading, spacing: 0) {
                    chainStart
                    ForEach(path) { step in
                        chainLink
                        TopicRow(topic: step)
                    }
                }
                .surface(padding: 0)
                let others = direct.filter { d in !path.contains(where: { $0.id == d.id }) }
                if !others.isEmpty {
                    Text("It also leads directly to")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.inkSoft)
                        .padding(.top, 4)
                    FlowLayout(spacing: 8) {
                        ForEach(others) { other in
                            Button(other.title) { model.open(.topic(other.id)) }
                                .buttonStyle(ChipButtonStyle())
                        }
                    }
                }
            }
        }
    }

    private var chainStart: some View {
        HStack(spacing: 12) {
            Circle().fill(Theme.ink).frame(width: 10, height: 10).frame(width: 26)
            Text(topic.title + " (here)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
    }

    private var chainLink: some View {
        Image(systemName: "arrow.down")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Theme.inkSoft)
            .frame(width: 26)
            .padding(.leading, 14)
            .padding(.top, 6)
            .accessibilityHidden(true)
    }
}

// MARK: - Compare

private struct CompareSection: View {
    @Environment(AppModel.self) private var model
    let topic: Topic

    var body: some View {
        let comparisons = model.atlas.comparisons(involving: topic.id)
        if !comparisons.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel("Compare")
                ForEach(comparisons) { comparison in
                    Button {
                        model.open(.compare(comparison.id))
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.split.2x1")
                                .foregroundStyle(model.atlas.hue(of: topic.id))
                            Text(comparison.title)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.inkSoft)
                        }
                        .surface()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Sources

private struct SourcesSection: View {
    let topic: Topic

    var body: some View {
        if !topic.sources.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel("Sources")
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(topic.sources, id: \.url) { source in
                        if let url = URL(string: source.url) {
                            Link(destination: url) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(source.title)
                                        .font(Theme.body)
                                        .multilineTextAlignment(.leading)
                                    Spacer(minLength: 8)
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                            }
                        }
                    }
                }
                .surface()
                Text("Explanations are written by hand and checked against these sources.")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }
}

// MARK: - I get it

private struct UnderstoodBar: View {
    @Environment(AppModel.self) private var model
    let topic: Topic

    var body: some View {
        let understood = model.isUnderstood(topic.id)
        VStack(spacing: 0) {
            Rectangle().fill(Theme.line).frame(height: 1)
            Group {
                if understood {
                    Button {
                        model.toggleUnderstood(topic.id)
                    } label: {
                        Label("Understood · tap to undo", systemImage: "checkmark")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                } else {
                    Button {
                        model.toggleUnderstood(topic.id)
                    } label: {
                        Text("I get it")
                    }
                    .buttonStyle(PrimaryButtonStyle(fill: model.atlas.hue(of: topic.id)))
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 10)
        }
        .background(Theme.paper)
        .sensoryFeedback(.success, trigger: understood) { _, now in now }
    }
}
