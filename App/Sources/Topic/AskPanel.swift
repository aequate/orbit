import SwiftUI
import OrbitKit

/// "Explain like I'm 12", "Give me an analogy" and friends. Answers say where they came from.
struct AskPanel: View {
    @Environment(AppModel.self) private var model
    let topic: Topic

    @State private var status = OnDeviceAI.status
    @State private var asked: String?
    @State private var answer: String?
    @State private var fromAI = false
    @State private var loading = false
    @State private var question = ""
    @State private var note: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FlowLayout(spacing: 8) {
                ForEach(TutorAsk.allCases) { ask in
                    Button(ask.title) {
                        run(ask)
                    }
                    .buttonStyle(ChipButtonStyle(selected: asked == ask.title, tint: model.atlas.hue(of: topic.id)))
                    .disabled(loading)
                }
            }
            if status.isAvailable {
                HStack(spacing: 8) {
                    TextField("Ask your own question", text: $question, axis: .vertical)
                        .font(Theme.body)
                        .lineLimit(1...4)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Theme.line, lineWidth: 1))
                        .submitLabel(.send)
                        .onSubmit(runQuestion)
                    Button(action: runQuestion) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Theme.paper)
                            .frame(width: 44, height: 44)
                            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(loading || question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Ask")
                }
            } else if case .unavailable(let reason) = status {
                Text(reason)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if loading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Thinking on your iPhone…")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
                .surface()
            } else if let answer {
                answerCard(answer)
            }
        }
    }

    private func answerCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let asked {
                Text(asked)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
            Text(text)
                .font(Theme.reading)
                .foregroundStyle(Theme.ink)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            if let note {
                Text(note)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
            Label(fromAI ? "On-device AI · can make mistakes" : "From Orbit's reviewed notes",
                  systemImage: fromAI ? "cpu" : "checkmark.seal")
                .font(Theme.caption)
                .foregroundStyle(Theme.inkSoft)
        }
        .surface()
    }

    private func run(_ ask: TutorAsk) {
        asked = ask.title
        request(prompt: ask.prompt(for: topic), fallback: Tutor.fallback(ask, topic: topic, atlas: model.atlas))
    }

    private func runQuestion() {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !loading else { return }
        asked = text
        question = ""
        request(prompt: text, fallback: topic.levels.core)
    }

    private func request(prompt: String, fallback: String) {
        note = nil
        status = OnDeviceAI.status
        guard status.isAvailable else {
            answer = fallback
            fromAI = false
            return
        }
        loading = true
        let instructions = Tutor.instructions(for: topic, atlas: model.atlas)
        Task {
            do {
                let text = try await OnDeviceAI.respond(to: prompt, instructions: instructions)
                answer = text.trimmingCharacters(in: .whitespacesAndNewlines)
                fromAI = true
            } catch {
                answer = fallback
                fromAI = false
                note = "The on-device model couldn't answer that, so here are the reviewed notes instead."
            }
            loading = false
        }
    }
}
