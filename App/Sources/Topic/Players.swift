import SwiftUI
import OrbitKit

/// Steps through a diagram. In aphantasia mode every caption so far stays on screen,
/// numbered, so nothing has to be held in memory.
struct DiagramPlayer: View {
    let diagram: Diagram
    let hue: Color
    let keepCaptions: Bool
    @State private var step = 0

    private var last: Int { max(0, diagram.steps.count - 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DiagramCanvas(diagram: diagram, step: step, hue: hue)
                .surface(padding: 8)
            HStack {
                Text(Words.join(["Step ", String(step + 1), " of ", String(diagram.steps.count)]))
                    .font(Theme.label)
                    .foregroundStyle(Theme.inkSoft)
                Spacer()
                ProgressLine(fraction: diagram.steps.isEmpty ? 0 : Double(step + 1) / Double(diagram.steps.count), tint: hue)
                    .frame(width: 120)
            }
            captions
            controls
        }
    }

    @ViewBuilder
    private var captions: some View {
        if keepCaptions {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(0...min(step, last), id: \.self) { index in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(String(index + 1))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(index == step ? Theme.paper : Theme.inkSoft)
                            .frame(width: 24, height: 24)
                            .background(index == step ? hue : Theme.sunken, in: Circle())
                        Text(diagram.steps[index].caption)
                            .font(index == step ? Theme.reading : Theme.body)
                            .foregroundStyle(index == step ? Theme.ink : Theme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        } else if diagram.steps.indices.contains(step) {
            Text(diagram.steps[step].caption)
                .font(Theme.reading)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .id(step)
        }
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button {
                step = max(0, step - 1)
            } label: {
                Label("Back", systemImage: "chevron.left")
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(step == 0)
            .opacity(step == 0 ? 0.5 : 1)

            if step < last {
                Button {
                    step += 1
                } label: {
                    Label("Next step", systemImage: "chevron.right")
                }
                .buttonStyle(PrimaryButtonStyle(fill: hue))
            } else {
                Button {
                    step = 0
                } label: {
                    Label("Start over", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }
}

/// Plays a simulation like a short video you can scrub, pause and step through.
struct SimPlayer: View {
    let base: Simulation
    let hue: Color
    let secondsPerFrame: Double
    @State private var frame = 0
    @State private var playing = false
    @State private var values: SimValues = [:]
    @State private var custom: Simulation?

    init(simulation: Simulation, hue: Color, secondsPerFrame: Double) {
        self.base = simulation
        self.hue = hue
        self.secondsPerFrame = secondsPerFrame
    }

    private var simulation: Simulation { custom ?? base }
    private var controls: [SimControl] { Simulations.controls(for: base.id) }
    private var last: Int { max(0, simulation.frames.count - 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if simulation.frames.indices.contains(frame) {
                SimSceneView(scene: simulation.frames[frame].scene, hue: hue)
                    .surface(padding: 8)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(simulation.frames[frame].caption)
                Text(simulation.frames[frame].caption)
                    .font(Theme.reading)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 70, alignment: .topLeading)
            }
            scrubber
            controls
            if !controls.isEmpty {
                TryItPanel(controls: controls, values: values, hue: hue, onChange: apply, onReset: reset)
                    .id("tryit")
            }
        }
        .onAppear {
            #if DEBUG
            let defaults = UserDefaults.standard
            if let tried = defaults.string(forKey: "orbitTry") {
                for pair in tried.split(separator: ",") {
                    let bits = pair.split(separator: "=").map(String.init)
                    if bits.count == 2, let number = Double(bits[1]) { values[bits[0]] = number }
                }
                custom = Simulations.make(base.id, values: values)
            }
            if defaults.object(forKey: "orbitFrame") != nil {
                frame = min(last, max(0, defaults.integer(forKey: "orbitFrame")))
            }
            #endif
        }
        .task(id: playing) {
            guard playing else { return }
            while playing && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(secondsPerFrame))
                guard playing, !Task.isCancelled else { return }
                if frame < last {
                    frame += 1
                }
                if frame >= last {
                    playing = false
                }
            }
        }
        .onDisappear { playing = false }
    }

    private func apply(_ id: String, _ value: Double) {
        values[id] = value
        custom = Simulations.make(base.id, values: values)
        playing = false
        frame = 0
    }

    private func reset() {
        values = [:]
        custom = nil
        playing = false
        frame = 0
    }

    private var frameBinding: Binding<Double> {
        Binding(
            get: { Double(frame) },
            set: { value in
                playing = false
                frame = min(last, max(0, Int(value.rounded())))
            }
        )
    }

    private var scrubber: some View {
        HStack(spacing: 12) {
            Text(String(frame + 1) + " / " + String(simulation.frames.count))
                .font(.system(.subheadline, weight: .semibold).monospacedDigit())
                .foregroundStyle(Theme.inkSoft)
                .frame(minWidth: 54, alignment: .leading)
            if last > 0 {
                Slider(value: frameBinding, in: 0...Double(last), step: 1)
                    .tint(hue)
                    .accessibilityLabel("Frame")
            }
        }
    }

    private var playTitle: String {
        if playing { return "Pause" }
        return frame >= last ? "Replay" : "Play"
    }

    private var playSymbol: String {
        if playing { return "pause.fill" }
        return frame >= last ? "arrow.counterclockwise" : "play.fill"
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button {
                playing = false
                frame = max(0, frame - 1)
            } label: {
                Image(systemName: "backward.frame")
            }
            .buttonStyle(SecondaryButtonStyle())
            .frame(width: 72)
            .accessibilityLabel("Previous frame")

            Button {
                if !playing && frame >= last { frame = 0 }
                playing.toggle()
            } label: {
                Label(playTitle, systemImage: playSymbol)
            }
            .buttonStyle(PrimaryButtonStyle(fill: hue))

            Button {
                playing = false
                frame = min(last, frame + 1)
            } label: {
                Image(systemName: "forward.frame")
            }
            .buttonStyle(SecondaryButtonStyle())
            .frame(width: 72)
            .accessibilityLabel("Next frame")
        }
    }
}

/// The "Try it" controls under a simulation. Changing anything re-runs the algorithm from the start.
private struct TryItPanel: View {
    let controls: [SimControl]
    let values: SimValues
    let hue: Color
    let onChange: (String, Double) -> Void
    let onReset: () -> Void

    private func value(_ control: SimControl) -> Double {
        values[control.id] ?? control.initial
    }

    private var changed: Bool {
        controls.contains { control in value(control) != control.initial }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Try it", systemImage: "slider.horizontal.3")
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                if changed {
                    Button("Reset", action: onReset)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(hue)
                }
            }
            ForEach(controls) { control in
                row(control)
            }
            Text("Change a value and the run starts again with it.")
                .font(Theme.caption)
                .foregroundStyle(Theme.inkSoft)
        }
        .surface(Theme.sunken)
    }

    @ViewBuilder
    private func row(_ control: SimControl) -> some View {
        switch control.kind {
        case .slider(let range, let step, _):
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(control.label)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                    Spacer()
                    Text(control.display(value(control)))
                        .font(.system(.body, weight: .bold).monospacedDigit())
                        .foregroundStyle(Theme.ink)
                }
                Slider(value: binding(control), in: range, step: step)
                    .tint(hue)
                    .accessibilityLabel(control.label)
                    .accessibilityValue(control.display(value(control)))
            }
        case .choice(let options):
            VStack(alignment: .leading, spacing: 8) {
                Text(control.label)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                FlowLayout(spacing: 8) {
                    ForEach(options) { option in
                        Button(option.label) { onChange(control.id, option.value) }
                            .buttonStyle(ChipButtonStyle(selected: option.value == value(control), tint: hue))
                    }
                }
            }
        }
    }

    private func binding(_ control: SimControl) -> Binding<Double> {
        Binding(
            get: { value(control) },
            set: { newValue in
                let snapped = control.clamp(newValue)
                if snapped != value(control) { onChange(control.id, snapped) }
            }
        )
    }
}
