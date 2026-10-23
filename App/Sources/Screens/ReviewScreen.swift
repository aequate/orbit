import SwiftUI
import OrbitKit

/// Spaced review: ideas you marked "I get it" come back as short questions about how they connect.
struct ReviewScreen: View {
    @Environment(AppModel.self) private var model
    @State private var session: [QuizQuestion]?

    var body: some View {
        Group {
            if let session {
                ReviewSession(questions: session) {
                    self.session = nil
                }
            } else {
                overview
            }
        }
        .background(Theme.paper)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var overview: some View {
        let now = Date()
        let due = model.state.due(now: now)
        let upcoming = model.state.upcoming(now: now, limit: 6).map { UpcomingItem(id: $0.id, due: $0.due) }
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Review")
                    .font(Theme.title(32))
                    .foregroundStyle(Theme.ink)
                if model.state.cards.isEmpty {
                    emptyState
                } else if due.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("All caught up")
                            .font(Theme.title(22))
                            .foregroundStyle(Theme.ink)
                        Text("Each idea comes back just before you'd forget it. The better you know it, the longer the gap.")
                            .font(Theme.body)
                            .foregroundStyle(Theme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .surface()
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(ReviewText.ready(due.count))
                            .font(Theme.title(22))
                            .foregroundStyle(Theme.ink)
                        Text("Questions about what each idea is, what it needs and what it leads to.")
                            .font(Theme.body)
                            .foregroundStyle(Theme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Start review") { start(due) }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                    .surface()
                }
                if !upcoming.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel("Coming up")
                        VStack(spacing: 0) {
                            ForEach(upcoming) { item in
                                HStack {
                                    Circle().fill(model.atlas.hue(of: item.id)).frame(width: 8, height: 8)
                                    Text(model.atlas.topic(item.id)?.title ?? item.id)
                                        .font(Theme.body)
                                        .foregroundStyle(Theme.ink)
                                    Spacer()
                                    Text(item.due, format: .relative(presentation: .named))
                                        .font(Theme.caption)
                                        .foregroundStyle(Theme.inkSoft)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                            }
                        }
                        .surface(padding: 0)
                    }
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 12)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 28))
                .foregroundStyle(Theme.inkSoft)
            Text("Nothing to review yet")
                .font(Theme.title(22))
                .foregroundStyle(Theme.ink)
            Text("When an idea clicks, tap \u{201C}I get it\u{201D}. It will come back here a day later, then three, then further apart as it sticks.")
                .font(Theme.body)
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Button("Explore the map") { model.tab = .map }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.top, 4)
        }
        .surface()
    }

    private func start(_ due: [String]) {
        let seed = UInt64(Date().timeIntervalSince1970)
        let questions = QuizMaker(atlas: model.atlas).session(for: Array(due.prefix(10)), seed: seed)
        session = questions.isEmpty ? nil : questions
    }
}

private struct UpcomingItem: Identifiable {
    let id: String
    let due: Date
}

enum ReviewText {
    static func ready(_ count: Int) -> String {
        count == 1 ? "1 idea ready" : String(count) + " ideas ready"
    }
}

/// One question at a time. Answering right pushes the idea further out; wrong brings it back soon.
private struct ReviewSession: View {
    @Environment(AppModel.self) private var model
    let questions: [QuizQuestion]
    let finish: () -> Void

    @State private var index = 0
    @State private var chosen: Int?
    @State private var correct = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Button("End") { finish() }
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    if index < questions.count {
                        Text(String(index + 1) + " of " + String(questions.count))
                            .font(Theme.caption)
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                ProgressLine(fraction: Double(index + (chosen == nil ? 0 : 1)) / Double(max(1, questions.count)))
                if index < questions.count {
                    question(questions[index])
                } else {
                    summary
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 12)
        }
    }

    private func question(_ q: QuizQuestion) -> some View {
        let hue = model.atlas.hue(of: q.topicID)
        return VStack(alignment: .leading, spacing: 14) {
            Text(q.prompt)
                .font(Theme.title(24))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let detail = q.detail {
                Text(detail)
                    .font(Theme.reading)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .surface(Theme.sunken)
            }
            VStack(spacing: 10) {
                ForEach(Array(q.choices.indices), id: \.self) { i in
                    ChoiceButton(
                        text: q.choices[i],
                        state: choiceState(i, q: q),
                        hue: hue
                    ) {
                        answer(i, q: q)
                    }
                    .disabled(chosen != nil)
                }
            }
            if let chosen {
                feedback(q, right: chosen == q.answer)
            }
        }
    }

    private func choiceState(_ i: Int, q: QuizQuestion) -> ChoiceButton.Phase {
        guard let chosen else { return .open }
        if i == q.answer { return .right }
        if i == chosen { return .wrong }
        return .faded
    }

    private func feedback(_ q: QuizQuestion, right: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(right ? "Correct" : "Not quite", systemImage: right ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(right ? Theme.good : Theme.bad)
            Text(q.explanation)
                .font(Theme.body)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button("Open idea") { model.open(.topic(q.topicID)) }
                    .buttonStyle(SecondaryButtonStyle())
                Button(index + 1 < questions.count ? "Next" : "Finish") {
                    chosen = nil
                    index += 1
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .surface()
    }

    private func answer(_ i: Int, q: QuizQuestion) {
        guard chosen == nil else { return }
        chosen = i
        let right = i == q.answer
        if right { correct += 1 }
        model.update { $0.record(q.topicID, recall: right ? .solid : .forgot, now: Date()) }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Done")
                .font(Theme.title(28))
                .foregroundStyle(Theme.ink)
            Text(Words.join(["You got ", String(correct), " of ", String(questions.count), ". Ideas you missed will come back in about ten minutes; the rest are scheduled further out."]))
                .font(Theme.body)
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Button("Back to Review") { finish() }
                .buttonStyle(PrimaryButtonStyle())
        }
        .surface()
    }
}

private struct ChoiceButton: View {
    enum Phase { case open, right, wrong, faded }

    let text: String
    let state: Phase
    let hue: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                Spacer()
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(state == .right ? Theme.good : Theme.bad)
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(border, lineWidth: state == .open ? 1 : 2))
            .opacity(state == .faded ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityValue(accessibilityState)
    }

    private var symbol: String? {
        switch state {
        case .right: return "checkmark"
        case .wrong: return "xmark"
        default: return nil
        }
    }

    private var fill: Color {
        switch state {
        case .right: return Theme.good.opacity(0.12)
        case .wrong: return Theme.bad.opacity(0.12)
        default: return Theme.surface
        }
    }

    private var border: Color {
        switch state {
        case .right: return Theme.good
        case .wrong: return Theme.bad
        default: return Theme.line
        }
    }

    private var accessibilityState: String {
        switch state {
        case .right: return "Correct answer"
        case .wrong: return "Your answer, incorrect"
        default: return ""
        }
    }
}
