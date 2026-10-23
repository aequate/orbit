import Foundation

/// A multiple-choice question generated from the structure of the map, not from trivia:
/// what an idea is, what it needs, what it unlocks, and what sits between two ideas.
public struct QuizQuestion: Identifiable, Hashable, Sendable {
    public enum Kind: String, Sendable, CaseIterable {
        case identify, needs, unlocks, gap
    }

    public let id: String
    public let topicID: String
    public let kind: Kind
    public let prompt: String
    /// A quoted summary or chain shown under the prompt, if any.
    public let detail: String?
    public let choices: [String]
    /// Topic ids parallel to `choices`, so the app can link each answer to its topic.
    public let choiceTopics: [String]
    public let answer: Int
    public let explanation: String
}

public struct QuizMaker: Sendable {
    public let atlas: Atlas

    public init(atlas: Atlas) {
        self.atlas = atlas
    }

    /// One question per topic, in the given order. The seed makes a session reproducible.
    public func session(for topicIDs: [String], seed: UInt64) -> [QuizQuestion] {
        var rng = SplitMix64(seed: seed)
        return topicIDs.compactMap { question(for: $0, rng: &rng) }
    }

    public func question<R: RandomNumberGenerator>(for topicID: String, rng: inout R) -> QuizQuestion? {
        guard let topic = atlas.topic(topicID) else { return nil }
        var kinds: [QuizQuestion.Kind] = [.identify]
        if !topic.requires.isEmpty { kinds.append(.needs) }
        if !atlas.dependents(of: topicID).isEmpty { kinds.append(.unlocks) }
        if gapChain(for: topic) != nil { kinds.append(.gap) }
        kinds.shuffle(using: &rng)
        for kind in kinds {
            if let q = make(kind, topic: topic, rng: &rng) { return q }
        }
        return nil
    }

    func gapChain(for topic: Topic) -> (middle: Topic, start: Topic)? {
        for middle in atlas.prerequisites(of: topic.id) {
            if let start = atlas.prerequisites(of: middle.id).first { return (middle, start) }
        }
        return nil
    }

    private func make<R: RandomNumberGenerator>(_ kind: QuizQuestion.Kind, topic: Topic, rng: inout R) -> QuizQuestion? {
        let upstream = Set(atlas.tunnel(to: topic.id).map(\.id))
        let downstream = atlas.downstream(of: topic.id)
        switch kind {
        case .identify:
            let pool = atlas.topics.filter { $0.id != topic.id }
            return build(kind, topic: topic, correct: topic, pool: pool, rng: &rng,
                         prompt: "Which idea is this?", detail: topic.summary,
                         explanation: topic.title + ": " + topic.summary)
        case .needs:
            guard let correct = atlas.prerequisites(of: topic.id).randomElement(using: &rng) else { return nil }
            let pool = atlas.topics.filter { $0.id != topic.id && !upstream.contains($0.id) && !downstream.contains($0.id) }
            return build(kind, topic: topic, correct: correct, pool: pool, rng: &rng,
                         prompt: "What do you need to understand before " + topic.title + "?", detail: nil,
                         explanation: topic.title + " builds directly on " + correct.title + ".")
        case .unlocks:
            guard let correct = atlas.dependents(of: topic.id).randomElement(using: &rng) else { return nil }
            let pool = atlas.topics.filter { $0.id != topic.id && !upstream.contains($0.id) && !downstream.contains($0.id) }
            return build(kind, topic: topic, correct: correct, pool: pool, rng: &rng,
                         prompt: "Which of these builds directly on " + topic.title + "?", detail: nil,
                         explanation: correct.title + " needs " + topic.title + " first.")
        case .gap:
            guard let chain = gapChain(for: topic) else { return nil }
            let excluded: Set<String> = [topic.id, chain.middle.id, chain.start.id]
            let pool = atlas.topics.filter { !excluded.contains($0.id) && !atlas.topic(topic.id)!.requires.contains($0.id) }
            return build(kind, topic: topic, correct: chain.middle, pool: pool, rng: &rng,
                         prompt: "Fill the gap in this chain.",
                         detail: chain.start.title + "  →  ?  →  " + topic.title,
                         explanation: chain.start.title + " leads to " + chain.middle.title + ", which leads to " + topic.title + ".")
        }
    }

    private func build<R: RandomNumberGenerator>(
        _ kind: QuizQuestion.Kind, topic: Topic, correct: Topic, pool: [Topic], rng: inout R,
        prompt: String, detail: String?, explanation: String
    ) -> QuizQuestion? {
        // Distractors from the same cluster are harder to rule out, so prefer them.
        let candidates = pool.filter { $0.id != correct.id }
        let near = candidates.filter { $0.cluster == correct.cluster }.shuffled(using: &rng)
        let far = candidates.filter { $0.cluster != correct.cluster }.shuffled(using: &rng)
        let distractors = Array((near + far).prefix(3))
        guard distractors.count == 3 else { return nil }
        var options = distractors + [correct]
        options.shuffle(using: &rng)
        guard let answer = options.firstIndex(where: { $0.id == correct.id }) else { return nil }
        return QuizQuestion(
            id: topic.id + "-" + kind.rawValue,
            topicID: topic.id,
            kind: kind,
            prompt: prompt,
            detail: detail,
            choices: options.map(\.title),
            choiceTopics: options.map(\.id),
            answer: answer,
            explanation: explanation
        )
    }
}
