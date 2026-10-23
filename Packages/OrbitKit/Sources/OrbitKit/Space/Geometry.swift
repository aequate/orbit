import Foundation

public struct Vec3: Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double

    public init(_ x: Double, _ y: Double, _ z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    public static let zero = Vec3(0, 0, 0)

    public static func + (a: Vec3, b: Vec3) -> Vec3 { Vec3(a.x + b.x, a.y + b.y, a.z + b.z) }
    public static func - (a: Vec3, b: Vec3) -> Vec3 { Vec3(a.x - b.x, a.y - b.y, a.z - b.z) }
    public static func * (a: Vec3, s: Double) -> Vec3 { Vec3(a.x * s, a.y * s, a.z * s) }
    public static func += (a: inout Vec3, b: Vec3) { a = a + b }
    public static func -= (a: inout Vec3, b: Vec3) { a = a - b }

    public func dot(_ o: Vec3) -> Double { x * o.x + y * o.y + z * o.z }
    public var length: Double { dot(self).squareRoot() }
    public var isFinite: Bool { x.isFinite && y.isFinite && z.isFinite }

    public func lerp(to other: Vec3, _ t: Double) -> Vec3 {
        self + (other - self) * t
    }
}

/// A point after the camera has rotated and projected it onto the screen.
public struct Projected: Hashable, Sendable {
    public var x: Double
    public var y: Double
    /// Perspective size factor: about 1 at the centre of the scene, bigger when closer.
    public var scale: Double
    /// Rotated z: +1 is nearest the viewer, -1 furthest away.
    public var depth: Double
}

/// An orbiting camera: yaw spins the scene around its vertical axis, pitch tilts it.
public struct Camera: Hashable, Sendable {
    public var yaw: Double
    public var pitch: Double
    public var zoom: Double
    public var distance: Double

    public static let pitchLimit = 1.35
    public static let zoomRange: ClosedRange<Double> = 0.6...3.5

    public init(yaw: Double = 0.6, pitch: Double = 0.3, zoom: Double = 1, distance: Double = 3.4) {
        self.yaw = yaw
        self.pitch = pitch
        self.zoom = zoom
        self.distance = distance
    }

    /// Rotate around the vertical axis by yaw, then around the horizontal axis by pitch.
    public func rotate(_ p: Vec3) -> Vec3 {
        let cy = cos(yaw), sy = sin(yaw)
        let x1 = p.x * cy + p.z * sy
        let z1 = -p.x * sy + p.z * cy
        let cp = cos(pitch), sp = sin(pitch)
        let y2 = p.y * cp - z1 * sp
        let z2 = p.y * sp + z1 * cp
        return Vec3(x1, y2, z2)
    }

    /// Projects a point in map space (roughly the unit sphere) into a width × height view.
    public func project(_ p: Vec3, width: Double, height: Double) -> Projected {
        let r = rotate(p)
        let s = distance / max(0.2, distance - r.z)
        let unit = min(width, height) * 0.4 * zoom
        return Projected(
            x: width / 2 + r.x * s * unit,
            y: height / 2 - r.y * s * unit,
            scale: s,
            depth: r.z
        )
    }

    /// Yaw and pitch that bring `p` to the front-centre of the view.
    public static func facing(_ p: Vec3) -> (yaw: Double, pitch: Double) {
        let yaw = atan2(-p.x, p.z)
        let flat = (p.x * p.x + p.z * p.z).squareRoot()
        let pitch = atan2(p.y, flat)
        return (yaw, min(pitchLimit, max(-pitchLimit, pitch)))
    }

    /// The signed smallest rotation from one angle to another, in -π...π.
    public static func shortestTurn(from a: Double, to b: Double) -> Double {
        var d = (b - a).truncatingRemainder(dividingBy: 2 * .pi)
        if d > .pi { d -= 2 * .pi }
        if d < -.pi { d += 2 * .pi }
        return d
    }
}
