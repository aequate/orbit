import Foundation

/// How well a learner recalled something.
public enum Recall: String, Codable, Sendable, CaseIterable {
    case forgot, shaky, solid
}

/// Spaced-repetition state for one topic.
public struct CardState: Codable, Hashable, Sendable {
    public var due: Date
    /// Days until the next review after a successful one.
    public var interval: Double
    public var ease: Double
    public var reps: Int
    public var lapses: Int
    public var lastReviewed: Date?

    public init(due: Date, interval: Double = 0, ease: Double = 2.5, reps: Int = 0, lapses: Int = 0, lastReviewed: Date? = nil) {
        self.due = due
        self.interval = interval
        self.ease = ease
        self.reps = reps
        self.lapses = lapses
        self.lastReviewed = lastReviewed
    }

    /// A brand-new card is due straight away.
    public static func new(now: Date) -> CardState {
        CardState(due: now)
    }
}

/// A small SM-2-style scheduler: reviews spread out as recall gets stronger.
public enum Scheduler {
    static let day: TimeInterval = 86_400
    static let minimumEase = 1.3
    static let maximumEase = 3.0

    public static func review(_ card: CardState, recall: Recall, now: Date) -> CardState {
        var next = card
        next.lastReviewed = now
        switch recall {
        case .solid:
            next.reps += 1
            switch next.reps {
            case 1: next.interval = 1
            case 2: next.interval = 3
            default: next.interval = max(card.interval, 1) * card.ease
            }
            next.ease = min(maximumEase, card.ease + 0.05)
            next.due = now.addingTimeInterval(next.interval * day)
        case .shaky:
            next.reps += 1
            next.interval = max(1, card.interval * 1.2)
            next.ease = max(minimumEase, card.ease - 0.15)
            next.due = now.addingTimeInterval(next.interval * day)
        case .forgot:
            next.reps = 0
            next.lapses += 1
            next.interval = 0
            next.ease = max(minimumEase, card.ease - 0.2)
            next.due = now.addingTimeInterval(10 * 60)
        }
        return next
    }
}
