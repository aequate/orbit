import Foundation

/// Ready-made questions a learner can ask about any topic.
public enum TutorAsk: String, CaseIterable, Sendable, Identifiable {
    case simpler, analogy, why, steps, example

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .simpler: return "Explain like I'm 12"
        case .analogy: return "Give me an analogy"
        case .why: return "Why does this matter?"
        case .steps: return "Break it into steps"
        case .example: return "A real example"
        }
    }

    public func prompt(for topic: Topic) -> String {
        switch self {
        case .simpler:
            return "Explain " + topic.title + " to a curious 12-year-old in under 120 words."
        case .analogy:
            return "Give one everyday analogy for " + topic.title + ", then say in one sentence where the analogy breaks down."
        case .why:
            return "Why is " + topic.title + " worth learning? Name two things it makes possible."
        case .steps:
            return "Lay out " + topic.title + " as a numbered sequence of at most 6 short steps, saying what is on the page after each step."
        case .example:
            return "Walk through one concrete, real-world example of " + topic.title + " with actual numbers or names."
        }
    }
}

/// Grounding for the on-device model, plus reviewed fallbacks when no model is available.
public enum Tutor {
    /// System instructions: the topic's reviewed notes and how to talk to visual learners.
    public static func instructions(for topic: Topic, atlas: Atlas) -> String {
        let before = atlas.prerequisites(of: topic.id).map(\.title)
        let after = atlas.dependents(of: topic.id).map(\.title)
        var lines: [String] = [
            "You are Orbit, a patient tutor for visual learners, including people with aphantasia who cannot picture things in their mind.",
            "Never ask the learner to imagine or picture anything. Instead describe structure explicitly: name each part, say where it sits relative to the others, and the order in which things happen.",
            "Use plain text. Short paragraphs or numbered steps. Stay under 160 words.",
            "Stay grounded in the reference notes below. If a question goes beyond them, say what you are unsure about rather than guessing.",
            "",
            "Reference notes on " + topic.title + ":",
            topic.levels.intro,
            topic.levels.core,
            topic.levels.deep,
        ]
        if let analogy = topic.analogy { lines.append("Analogy: " + analogy) }
        if !before.isEmpty { lines.append("It builds on: " + before.joined(separator: ", ") + ".") }
        if !after.isEmpty { lines.append("It leads to: " + after.joined(separator: ", ") + ".") }
        if !topic.realWorld.isEmpty { lines.append("Real-world uses: " + topic.realWorld.joined(separator: "; ") + ".") }
        return lines.joined(separator: "\n")
    }

    /// A reviewed answer built from the hand-written content, used when on-device AI isn't available.
    public static func fallback(_ ask: TutorAsk, topic: Topic, atlas: Atlas) -> String {
        switch ask {
        case .simpler:
            return topic.levels.intro
        case .analogy:
            if let analogy = topic.analogy { return analogy }
            return topic.levels.intro
        case .why:
            let path = atlas.whyPath(from: topic.id).map(\.title)
            var text = topic.title + " is a building block."
            if path.count > 1 {
                text = "Follow it forward: " + path.joined(separator: " → ") + "."
            }
            if !topic.realWorld.isEmpty {
                text += " You meet it in: " + topic.realWorld.joined(separator: "; ") + "."
            }
            return text
        case .steps:
            let diagram = topic.diagram ?? atlas.contextDiagram(for: topic.id)
            let steps = diagram?.steps ?? []
            return steps.enumerated().map { pair in String(pair.offset + 1) + ". " + pair.element.caption }.joined(separator: "\n")
        case .example:
            if topic.realWorld.isEmpty { return topic.levels.core }
            return topic.realWorld.map { "• " + $0 }.joined(separator: "\n")
        }
    }
}
