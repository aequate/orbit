import Foundation

/// How an element of a simulation should be drawn at a given moment.
public enum Mark: String, Codable, Sendable {
    /// Ordinary.
    case idle
    /// The thing being acted on right now.
    case focus
    /// Being compared or waiting in a queue/frontier.
    case compare
    /// Finished, settled, or visited.
    case done
    /// Out of play (e.g. the discarded half in binary search).
    case muted
    /// Just appeared or just changed.
    case fresh
}

public struct SimCell: Hashable, Sendable {
    public var text: String
    public var mark: Mark
    /// Small caption under the cell (place value, index, f(i)…).
    public var note: String?

    public init(_ text: String, _ mark: Mark = .idle, note: String? = nil) {
        self.text = text
        self.mark = mark
        self.note = note
    }
}

public struct SimMarker: Hashable, Sendable {
    public var index: Int
    public var label: String

    public init(_ index: Int, _ label: String) {
        self.index = index
        self.label = label
    }
}

/// A row (or vertical stack) of cells with pointer labels.
public struct ArrayScene: Hashable, Sendable {
    public var cells: [SimCell]
    public var markers: [SimMarker]
    /// Draw bottom-to-top, like a stack of plates.
    public var vertical: Bool
    /// Side note such as "Out: C".
    public var label: String?

    public init(cells: [SimCell], markers: [SimMarker] = [], vertical: Bool = false, label: String? = nil) {
        self.cells = cells
        self.markers = markers
        self.vertical = vertical
        self.label = label
    }
}

/// Hash-table buckets, each holding a short chain.
public struct BucketScene: Hashable, Sendable {
    public var buckets: [[SimCell]]
    public var incoming: String?
    public var target: Int?

    public init(buckets: [[SimCell]], incoming: String? = nil, target: Int? = nil) {
        self.buckets = buckets
        self.incoming = incoming
        self.target = target
    }
}

/// Nodes and edges at fixed positions (0...1 in a 4:3 frame).
public struct GraphScene: Hashable, Sendable {
    public struct Node: Hashable, Sendable {
        public var id: String
        public var label: String
        public var x: Double
        public var y: Double
        public var mark: Mark
        /// Small tag beside the node, e.g. a distance.
        public var badge: String?

        public init(id: String, label: String, x: Double, y: Double, mark: Mark = .idle, badge: String? = nil) {
            self.id = id
            self.label = label
            self.x = x
            self.y = y
            self.mark = mark
            self.badge = badge
        }
    }

    public struct Edge: Hashable, Sendable {
        public var from: String
        public var to: String
        public var label: String?
        public var mark: Mark

        public init(from: String, to: String, label: String? = nil, mark: Mark = .idle) {
            self.from = from
            self.to = to
            self.label = label
            self.mark = mark
        }
    }

    public var nodes: [Node]
    public var edges: [Edge]
    public var directed: Bool
    /// A line of state under the picture, e.g. "Queue: B C".
    public var footer: String?

    public init(nodes: [Node], edges: [Edge], directed: Bool = false, footer: String? = nil) {
        self.nodes = nodes
        self.edges = edges
        self.directed = directed
        self.footer = footer
    }
}

public struct Point2: Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }
}

/// Function plots with an optional moving point, a secant or a tangent.
public struct CurveScene: Hashable, Sendable {
    public struct Curve: Hashable, Sendable {
        public var label: String
        public var points: [Point2]
        public var mark: Mark

        public init(label: String, points: [Point2], mark: Mark = .idle) {
            self.label = label
            self.points = points
            self.mark = mark
        }
    }

    public var curves: [Curve]
    public var xRange: ClosedRange<Double>
    public var yRange: ClosedRange<Double>
    public var point: Point2?
    public var secondPoint: Point2?
    public var trail: [Point2]
    public var tangentSlope: Double?

    public init(
        curves: [Curve], xRange: ClosedRange<Double>, yRange: ClosedRange<Double>,
        point: Point2? = nil, secondPoint: Point2? = nil, trail: [Point2] = [], tangentSlope: Double? = nil
    ) {
        self.curves = curves
        self.xRange = xRange
        self.yRange = yRange
        self.point = point
        self.secondPoint = secondPoint
        self.trail = trail
        self.tangentSlope = tangentSlope
    }
}

public enum SimScene: Hashable, Sendable {
    case array(ArrayScene)
    case buckets(BucketScene)
    case graph(GraphScene)
    case curve(CurveScene)
}

public struct SimFrame: Hashable, Sendable {
    public var caption: String
    public var scene: SimScene

    public init(_ caption: String, _ scene: SimScene) {
        self.caption = caption
        self.scene = scene
    }
}

/// A process you can scrub through like a video, one meaningful step per frame.
public struct Simulation: Hashable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let blurb: String
    public let frames: [SimFrame]

    public init(id: String, title: String, blurb: String, frames: [SimFrame]) {
        self.id = id
        self.title = title
        self.blurb = blurb
        self.frames = frames
    }
}

func fmt(_ value: Double, _ digits: Int = 2) -> String {
    String(format: "%.\(digits)f", value)
}
