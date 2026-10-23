import SwiftUI
import OrbitKit

/// One clear suggestion of what to open next, so nobody has to decide where to start.
struct NextUpCard: View {
    @Environment(AppModel.self) private var model
    let next: NextUp

    var body: some View {
        let hue = model.atlas.hue(of: next.topic.id)
        Button {
            model.open(.topic(next.topic.id))
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(hue)
                    .frame(width: 6)
                    .frame(maxHeight: .infinity)
                VStack(alignment: .leading, spacing: 3) {
                    Text(next.kicker)
                        .font(Theme.label)
                        .foregroundStyle(Theme.inkSoft)
                    Text(next.topic.title)
                        .font(Theme.title(20))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.right")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(hue)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(14)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.line, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Words.join([next.kicker, ": ", next.topic.title]))
        .accessibilityHint("Opens the idea")
    }
}

/// Ideas whose groundwork is all done, foundations first.
struct ReadySection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let ready = model.readyTopics(limit: 4)
        if !ready.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel("Ready to learn")
                Text(readyNote)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(ready) { topic in
                        TopicRow(topic: topic)
                    }
                }
                .surface()
            }
        }
    }

    private var readyNote: String {
        if model.state.understood.isEmpty {
            return "Nothing is needed before these. Mark an idea as understood and new ones open up."
        }
        return "You already have everything these build on."
    }
}
