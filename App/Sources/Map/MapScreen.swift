import SwiftUI
import OrbitKit

/// The home screen: every idea as a node in a turnable 3D space.
struct MapScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rig = OrbitRig()
    @State private var selected: String?
    @State private var filter: String?
    @State private var showFind = false
    @State private var canvasSize: CGSize = .zero

    private var scene: MapScene {
        MapScene(atlas: model.atlas, orbit: model.positions(.orbit), tower: model.positions(.tower))
    }

    private var style: MapStyle {
        var style = MapStyle()
        style.selected = selected
        style.filter = filter
        style.understood = model.state.understood
        var hues: [String: Color] = [:]
        for cluster in model.atlas.clusters {
            let colour = Theme.hue(cluster.hue)
            for topic in model.atlas.topics(in: cluster.id) { hues[topic.id] = colour }
        }
        style.hues = hues
        if let selected {
            let before = Set(model.atlas.prerequisites(of: selected).map(\.id))
            let after = Set(model.atlas.dependents(of: selected).map(\.id))
            style.prerequisites = before
            style.neighbours = before.union(after)
        }
        return style
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack(alignment: .bottom) {
                mapCanvas
                VStack(spacing: 12) {
                    HStack {
                        Spacer()
                        controls
                    }
                    bottomCard
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 12)
            }
        }
        .background(Theme.paper)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showFind) {
            FindSheet { id in
                select(id, zoomIn: true)
            }
        }
        .onAppear {
            rig.reduceMotion = reduceMotion
            rig.setLayout(model.settings.mapLayout, animated: false)
            consumeFocusRequest()
        }
        .onChange(of: reduceMotion) { _, value in rig.reduceMotion = value }
        .onChange(of: model.settings.mapLayout) { _, layout in
            rig.setLayout(layout, animated: true)
            if let selected { focus(selected, zoomIn: false) }
        }
        .onChange(of: model.mapFocusRequest) { _, _ in consumeFocusRequest() }
    }

    // MARK: Header

    private var layoutBinding: Binding<MapLayout> {
        Binding(
            get: { model.settings.mapLayout },
            set: { value in model.update { $0.settings.mapLayout = value } }
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Orbit")
                    .font(Theme.title(32))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button {
                    showFind = true
                } label: {
                    Label("Find", systemImage: "magnifyingglass")
                }
                .buttonStyle(ChipButtonStyle())
            }
            Segmented(options: MapLayout.allCases, selection: layoutBinding) { $0.title }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button("All") { filter = nil }
                        .buttonStyle(ChipButtonStyle(selected: filter == nil, tint: Theme.ink))
                    ForEach(model.atlas.clusters) { cluster in
                        Button {
                            filter = filter == cluster.id ? nil : cluster.id
                            if let selected, model.atlas.topic(selected)?.cluster != filter, filter != nil {
                                self.selected = nil
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Circle().fill(Theme.hue(cluster.hue)).frame(width: 8, height: 8)
                                Text(cluster.name)
                            }
                        }
                        .buttonStyle(ChipButtonStyle(selected: filter == cluster.id, tint: Theme.hue(cluster.hue)))
                    }
                }
                .padding(.horizontal, Theme.gutter)
            }
            .padding(.horizontal, -Theme.gutter)
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(Theme.paper)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.line).frame(height: 1)
        }
    }

    // MARK: Canvas

    private var mapCanvas: some View {
        let scene = self.scene
        let style = self.style
        return GeometryReader { geo in
            TimelineView(.animation(minimumInterval: nil, paused: !rig.isMoving)) { timeline in
                Canvas { context, size in
                    rig.step(to: timeline.date)
                    MapRenderer.draw(context, size: size, scene: scene, camera: rig.camera, morph: rig.morph, style: style)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture().onEnded { value in
                    tap(at: value.location, size: geo.size)
                }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in rig.dragChanged(value.translation, at: value.time) }
                    .onEnded { _ in rig.dragEnded() }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in rig.pinchChanged(Double(value.magnification)) }
                    .onEnded { _ in rig.pinchEnded() }
            )
            .onAppear { canvasSize = geo.size }
            .onChange(of: geo.size) { _, size in canvasSize = size }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Map of " + String(model.atlas.topics.count) + " ideas")
        .accessibilityHint("Use Find to browse every idea as a list.")
    }

    private func tap(at location: CGPoint, size: CGSize) {
        let morph = MapRenderer.smooth(rig.morph)
        if let id = scene.hit(location, camera: rig.camera, morph: morph, size: size) {
            select(id, zoomIn: false)
        } else {
            selected = nil
        }
    }

    // MARK: Selection

    private func select(_ id: String, zoomIn: Bool) {
        if let filter, model.atlas.topic(id)?.cluster != filter { self.filter = nil }
        selected = id
        focus(id, zoomIn: zoomIn)
    }

    private func focus(_ id: String, zoomIn: Bool) {
        let target = MapRenderer.smooth(rig.morphTarget)
        rig.focus(on: scene.position(id, morph: target), zoomIn: zoomIn)
    }

    private func consumeFocusRequest() {
        guard let id = model.mapFocusRequest else { return }
        model.mapFocusRequest = nil
        select(id, zoomIn: true)
    }

    // MARK: Overlays

    private var controls: some View {
        VStack(spacing: 8) {
            MapControlButton(symbol: "plus", label: "Zoom in") { rig.zoom(by: 1.3) }
            MapControlButton(symbol: "minus", label: "Zoom out") { rig.zoom(by: 1 / 1.3) }
            MapControlButton(symbol: "scope", label: "Reset view") {
                selected = nil
                rig.resetView()
            }
        }
    }

    @ViewBuilder
    private var bottomCard: some View {
        if let id = selected, let topic = model.atlas.topic(id) {
            SelectionCard(topic: topic) {
                selected = nil
            }
        } else {
            VStack(spacing: 10) {
                if let next = model.nextUp {
                    NextUpCard(next: next)
                }
                HintCard(layout: model.settings.mapLayout, brief: model.nextUp?.kind == .resume)
            }
        }
    }
}

private struct MapControlButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 44, height: 44)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// The idea you tapped, with a way in.
private struct SelectionCard: View {
    @Environment(AppModel.self) private var model
    let topic: Topic
    let close: () -> Void

    var body: some View {
        let needs = model.atlas.prerequisites(of: topic.id).count
        let unlocks = model.atlas.dependents(of: topic.id).count
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ClusterTag(cluster: model.atlas.cluster(topic.cluster))
                if model.isUnderstood(topic.id) {
                    Label("Understood", systemImage: "checkmark")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.good)
                }
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.inkSoft)
                        .frame(width: 32, height: 32)
                        .background(Theme.sunken, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            Text(topic.title)
                .font(Theme.title(25))
                .foregroundStyle(Theme.ink)
            Text(topic.summary)
                .font(Theme.body)
                .foregroundStyle(Theme.inkSoft)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            Text(MapText.counts(needs: needs, unlocks: unlocks))
                .font(Theme.caption)
                .foregroundStyle(Theme.inkSoft)
            Button("Open") {
                model.open(.topic(topic.id))
            }
            .buttonStyle(PrimaryButtonStyle(fill: model.atlas.hue(of: topic.id)))
        }
        .surface()
    }
}

/// Shown when nothing is selected: how to use the map, and what the marks mean.
private struct HintCard: View {
    let layout: MapLayout
    /// Once someone has started, skip the explanation and keep only the legend.
    var brief = false

    private var explanation: String {
        if layout == .tower { return "Foundations sit at the bottom. Each ring up needs the rings below it." }
        return "Ideas that belong together sit together. Lines join an idea to what it builds on."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !brief {
                Text(explanation)
                    .font(Theme.body)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Drag to turn · pinch to zoom · tap an idea")
                .font(Theme.caption)
                .foregroundStyle(Theme.inkSoft)
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Circle().fill(Theme.accent).frame(width: 10, height: 10)
                    Text("Understood")
                }
                HStack(spacing: 6) {
                    Circle().stroke(Theme.accent, lineWidth: 2).frame(width: 10, height: 10)
                    Text("Not yet")
                }
            }
            .font(Theme.caption)
            .foregroundStyle(Theme.inkSoft)
            .accessibilityElement(children: .combine)
        }
        .surface()
    }
}

enum MapText {
    static func counts(needs: Int, unlocks: Int) -> String {
        let left = needs == 0 ? "A starting point" : "Needs " + String(needs)
        let right = unlocks == 0 ? "a destination" : "unlocks " + String(unlocks)
        return left + " · " + right
    }
}
