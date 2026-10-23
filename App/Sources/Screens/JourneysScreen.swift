import SwiftUI
import OrbitKit

/// Curated paths through the map, for when you don't know where to start.
struct JourneysScreen: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Journeys")
                        .font(Theme.title(32))
                        .foregroundStyle(Theme.ink)
                    Text("Guided routes through the map. Each step builds on the one before.")
                        .font(Theme.body)
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 4)
                ForEach(model.atlas.journeys) { journey in
                    JourneyCard(journey: journey)
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 12)
        }
        .background(Theme.paper)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct JourneyCard: View {
    @Environment(AppModel.self) private var model
    let journey: Journey

    var body: some View {
        let progress = journey.progress(understood: model.state.understood)
        let hue = journey.topics.first.map { model.atlas.hue(of: $0) } ?? Theme.accent
        Button {
            model.open(.journey(journey.id))
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text(journey.title)
                    .font(Theme.title(22))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                Text(journey.blurb)
                    .font(Theme.body)
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                ProgressLine(fraction: progress.fraction, tint: hue)
                HStack {
                    Text(JourneyText.status(progress))
                        .font(Theme.caption)
                        .foregroundStyle(Theme.inkSoft)
                    Spacer()
                    Text(JourneyText.action(progress))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(hue)
                }
            }
            .surface()
        }
        .buttonStyle(.plain)
    }
}

enum JourneyText {
    static func action(_ progress: Journey.Progress) -> String {
        if progress.isComplete { return "Review" }
        return progress.isStarted ? "Continue" : "Start"
    }

    static func status(_ progress: Journey.Progress) -> String {
        if progress.isComplete { return "All " + String(progress.total) + " steps understood" }
        return String(progress.done) + " of " + String(progress.total) + " steps understood"
    }
}

/// One journey as a numbered path, with the next step called out.
struct JourneyScreen: View {
    @Environment(AppModel.self) private var model
    let journeyID: String

    var body: some View {
        if let journey = model.atlas.journey(journeyID) {
            content(journey)
        } else {
            ContentUnavailableView("Journey not found", systemImage: "questionmark.circle")
        }
    }

    private func content(_ journey: Journey) -> some View {
        let progress = journey.progress(understood: model.state.understood)
        let steps = journey.topics.compactMap { model.atlas.topic($0) }
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(journey.title)
                    .font(Theme.title(32))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(journey.blurb)
                    .font(Theme.reading)
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 8) {
                    ProgressLine(fraction: progress.fraction)
                    Text(JourneyText.status(progress))
                        .font(Theme.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
                VStack(spacing: 0) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { pair in
                        JourneyStepRow(
                            topic: pair.element,
                            number: pair.offset + 1,
                            isNext: pair.element.id == progress.next,
                            isLast: pair.offset == steps.count - 1
                        )
                    }
                }
                if progress.isComplete {
                    Text("Journey complete. Your understood ideas will come back in Review at growing intervals.")
                        .font(Theme.body)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .surface(Theme.sunken)
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 12)
        }
        .background(Theme.paper)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if let next = progress.next, let topic = model.atlas.topic(next) {
                VStack(spacing: 0) {
                    Rectangle().fill(Theme.line).frame(height: 1)
                    Button {
                        model.open(.topic(next))
                    } label: {
                        Text((progress.isStarted ? "Continue: " : "Start: ") + topic.title)
                            .lineLimit(1)
                    }
                    .buttonStyle(PrimaryButtonStyle(fill: model.atlas.hue(of: next)))
                    .padding(.horizontal, Theme.gutter)
                    .padding(.vertical, 10)
                }
                .background(Theme.paper)
            }
        }
    }
}

private struct JourneyStepRow: View {
    @Environment(AppModel.self) private var model
    let topic: Topic
    let number: Int
    let isNext: Bool
    let isLast: Bool

    var body: some View {
        let understood = model.isUnderstood(topic.id)
        let hue = model.atlas.hue(of: topic.id)
        Button {
            model.open(.topic(topic.id))
        } label: {
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(understood ? hue : Theme.surface)
                            .overlay(Circle().stroke(isNext || understood ? hue : Theme.line, lineWidth: 2))
                        if understood {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Theme.paper)
                        } else {
                            Text(String(number))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(isNext ? hue : Theme.inkSoft)
                        }
                    }
                    .frame(width: 34, height: 34)
                    if !isLast {
                        Rectangle()
                            .fill(understood ? hue : Theme.line)
                            .frame(width: 2)
                            .frame(minHeight: 28, maxHeight: .infinity)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(topic.title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        if isNext {
                            Text("NEXT")
                                .font(Theme.label)
                                .foregroundStyle(Theme.paper)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(hue, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                        }
                    }
                    Text(topic.summary)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 5)
                .padding(.bottom, isLast ? 0 : 18)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Words.join(["Step ", String(number), ": ", topic.title]))
        .accessibilityValue(understood ? "Understood" : (isNext ? "Next" : "Not yet"))
    }
}
