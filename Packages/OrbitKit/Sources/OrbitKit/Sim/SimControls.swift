import Foundation

/// The values a learner has chosen for a simulation's controls, keyed by control id.
public typealias SimValues = [String: Double]

/// Something the learner can change in a simulation ("Try it"). Every control holds a number;
/// a choice control maps each option to a number.
public struct SimControl: Hashable, Sendable, Identifiable {
    public struct Option: Hashable, Sendable, Identifiable {
        public let value: Double
        public let label: String
        public var id: Double { value }

        public init(_ value: Double, _ label: String) {
            self.value = value
            self.label = label
        }
    }

    public enum Kind: Hashable, Sendable {
        case slider(range: ClosedRange<Double>, step: Double, digits: Int)
        case choice([Option])
    }

    public let id: String
    public let label: String
    public let kind: Kind
    public let initial: Double

    public init(id: String, label: String, kind: Kind, initial: Double) {
        self.id = id
        self.label = label
        self.kind = kind
        self.initial = initial
    }

    public static func slider(_ id: String, _ label: String, _ range: ClosedRange<Double>, step: Double = 1, digits: Int = 0, initial: Double) -> SimControl {
        SimControl(id: id, label: label, kind: .slider(range: range, step: step, digits: digits), initial: initial)
    }

    public static func choice(_ id: String, _ label: String, _ options: [Option], initial: Double) -> SimControl {
        SimControl(id: id, label: label, kind: .choice(options), initial: initial)
    }

    /// Keeps a value inside the control's range or option set.
    public func clamp(_ value: Double) -> Double {
        switch kind {
        case .slider(let range, let step, _):
            let snapped = range.lowerBound + ((value - range.lowerBound) / step).rounded() * step
            // Round away float noise so 0.05 × 7 reads back as exactly 0.35.
            let tidy = (snapped * 1_000_000).rounded() / 1_000_000
            return min(range.upperBound, max(range.lowerBound, tidy))
        case .choice(let options):
            if options.contains(where: { $0.value == value }) { return value }
            return initial
        }
    }

    /// How the current value reads on screen.
    public func display(_ value: Double) -> String {
        switch kind {
        case .slider(_, _, let digits):
            return fmt(value, digits)
        case .choice(let options):
            return options.first { $0.value == value }?.label ?? ""
        }
    }

    /// A short list of values that covers the control, for tests and previews.
    public var samples: [Double] {
        switch kind {
        case .slider(let range, let step, _):
            let count = Int(((range.upperBound - range.lowerBound) / step).rounded())
            let picks = Set([0, count / 4, count / 2, (3 * count) / 4, count])
            return picks.sorted().map { clamp(range.lowerBound + Double($0) * step) }
        case .choice(let options):
            return options.map(\.value)
        }
    }
}

extension Simulations {
    /// The controls a simulation offers. Empty when it only plays one fixed example.
    public static func controls(for id: String) -> [SimControl] {
        switch id {
        case "binaryCounter":
            return [.choice("bits", "Bits", [.init(3, "3 bits"), .init(4, "4 bits"), .init(5, "5 bits")], initial: 4)]
        case "halving":
            return [.choice("start", "Start with", [.init(16, "16"), .init(64, "64"), .init(100, "100"), .init(1000, "1,000")], initial: 64)]
        case "binarySearch":
            return [.slider("target", "Look for", 1...75, initial: 52)]
        case "insertionSort":
            return [.choice("list", "Starting list", [.init(0, "Mixed"), .init(1, "Nearly sorted"), .init(2, "Reversed")], initial: 0)]
        case "hashInsert":
            return [.choice("size", "Buckets", [.init(3, "3"), .init(5, "5"), .init(7, "7"), .init(11, "11")], initial: 5)]
        case "bfs", "dfs":
            let options = searchGraph.order.enumerated().map { SimControl.Option(Double($0.offset), $0.element) }
            return [.choice("start", "Start at", options, initial: 0)]
        case "bstInsert":
            return [.choice("order", "Insert order", [.init(0, "Mixed"), .init(1, "Sorted"), .init(2, "Zig-zag")], initial: 0)]
        case "heapInsert":
            return [.choice("order", "Insert order", [.init(0, "Mixed"), .init(1, "Largest first"), .init(2, "Smallest first")], initial: 0)]
        case "dijkstra":
            return [.slider("sa", "Cost of road S–A", 1...9, initial: 4)]
        case "fibTable":
            return [.slider("n", "Up to f(n), n =", 4...12, initial: 10)]
        case "factorialStack":
            return [.slider("n", "factorial(n), n =", 2...6, initial: 4)]
        case "gradientDescent", "gradientOvershoot":
            let rate = id == "gradientDescent" ? 0.35 : 1.8
            return [
                .slider("rate", "Learning rate", 0.05...2.2, step: 0.05, digits: 2, initial: rate),
                .slider("start", "Start at x =", -3.5...5.5, step: 0.5, digits: 1, initial: -3),
            ]
        case "secantTangent":
            return [.slider("at", "Point at x =", 0...3, step: 0.5, digits: 1, initial: 2)]
        default:
            return []
        }
    }

    /// The starting values for a simulation's controls.
    public static func defaults(for id: String) -> SimValues {
        var values: SimValues = [:]
        for control in controls(for: id) { values[control.id] = control.initial }
        return values
    }

    /// Builds a simulation with the learner's chosen values. Missing or out-of-range values
    /// fall back to the defaults, so the result is always a valid run.
    public static func make(_ id: String, values: SimValues) -> Simulation? {
        var v = defaults(for: id)
        for control in controls(for: id) {
            if let chosen = values[control.id] { v[control.id] = control.clamp(chosen) }
        }
        func num(_ key: String) -> Double { v[key] ?? 0 }
        func int(_ key: String) -> Int { Int(num(key).rounded()) }

        switch id {
        case "binaryCounter": return binaryCounter(bits: int("bits"))
        case "halving": return halving(start: int("start"))
        case "binarySearch": return binarySearch(target: int("target"))
        case "insertionSort": return insertionSort(list: int("list"))
        case "hashInsert": return hashInsert(size: int("size"))
        case "bfs": return breadthFirst(start: searchGraph.order[int("start")])
        case "dfs": return depthFirst(start: searchGraph.order[int("start")])
        case "bstInsert": return bstInsert(order: int("order"))
        case "heapInsert": return heapInsert(order: int("order"))
        case "dijkstra": return dijkstra(roadSA: int("sa"))
        case "fibTable": return fibTable(n: int("n"))
        case "factorialStack": return factorialStack(n: int("n"))
        case "gradientDescent", "gradientOvershoot":
            let rate = num("rate")
            let start = num("start")
            let isDefault = abs(rate - controls(for: id)[0].initial) < 1e-9 && abs(start + 3) < 1e-9
            if isDefault { return make(id) }
            return descent(id: id, title: "Your step size", rate: rate, start: start, steps: 10, blurb: "Gradient descent with the learning rate you chose.", outro: nil)
        case "secantTangent": return secantTangent(at: num("at"))
        default: return make(id)
        }
    }
}
