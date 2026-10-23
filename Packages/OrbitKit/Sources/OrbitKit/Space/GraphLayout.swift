import Foundation

/// The two shapes the map can take.
public enum MapLayout: String, Codable, CaseIterable, Sendable, Identifiable {
    /// Clusters float as neighbourhoods around a sphere, linked by prerequisites.
    case orbit
    /// A cylinder: foundations at the bottom, advanced ideas at the top, one column per cluster.
    case tower

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .orbit: return "Orbit"
        case .tower: return "Tower"
        }
    }
}

/// Deterministic 3D positions for every topic. Same content in, same map out,
/// so the learner's spatial memory of where things live is never disturbed.
public enum GraphLayout {
    public static func positions(for atlas: Atlas, layout: MapLayout) -> [String: Vec3] {
        switch layout {
        case .orbit: return orbit(atlas)
        case .tower: return tower(atlas)
        }
    }

    /// Height of a tower ring for a given prerequisite depth.
    public static func towerHeight(depth: Int, maxDepth: Int) -> Double {
        maxDepth == 0 ? 0 : -0.78 + 1.56 * Double(depth) / Double(maxDepth)
    }

    public static let towerRadius = 0.78

    // MARK: Orbit (force-directed, clustered)

    static func clusterCenters(count: Int) -> [Vec3] {
        // Points spread evenly over a sphere (Fibonacci lattice).
        let golden = Double.pi * (3 - 5.0.squareRoot())
        return (0..<count).map { i in
            let y = 1 - (Double(i) + 0.5) / Double(count) * 2
            let r = (1 - y * y).squareRoot()
            let theta = golden * Double(i)
            return Vec3(cos(theta) * r, y, sin(theta) * r) * 0.9
        }
    }

    static func orbit(_ atlas: Atlas) -> [String: Vec3] {
        let topics = atlas.topics
        let n = topics.count
        guard n > 0 else { return [:] }
        let centers = clusterCenters(count: max(1, atlas.clusters.count))
        var index: [String: Int] = [:]
        for (i, topic) in topics.enumerated() { index[topic.id] = i }
        let home = topics.map { centers[min(atlas.clusterPosition($0.cluster), centers.count - 1)] }

        var pos: [Vec3] = []
        for (i, topic) in topics.enumerated() {
            var rng = SplitMix64(seed: stableHash(topic.id))
            let jitter = Vec3(rng.unit() - 0.5, rng.unit() - 0.5, rng.unit() - 0.5) * 0.5
            pos.append(home[i] + jitter)
        }
        let springs: [(Int, Int)] = atlas.links.compactMap { link in
            guard let a = index[link.from], let b = index[link.to] else { return nil }
            return (a, b)
        }

        // Fruchterman–Reingold with an extra pull toward each cluster's home.
        let k = 0.8 * pow(4.19 / Double(n), 1.0 / 3.0)
        let iterations = 500
        for step in 0..<iterations {
            var disp = [Vec3](repeating: .zero, count: n)
            for i in 0..<n {
                for j in (i + 1)..<n {
                    let delta = pos[i] - pos[j]
                    let d = max(delta.length, 0.01)
                    let push = delta * ((k * k) / (d * d))
                    disp[i] += push
                    disp[j] -= push
                }
            }
            for (a, b) in springs {
                let delta = pos[a] - pos[b]
                let d = max(delta.length, 0.01)
                let pull = delta * (d / k)
                disp[a] -= pull
                disp[b] += pull
            }
            for i in 0..<n {
                let delta = pos[i] - home[i]
                disp[i] -= delta * (2.0 * delta.length / k)
            }
            let temperature = 0.1 * (1 - Double(step) / Double(iterations)) + 0.002
            for i in 0..<n {
                let d = disp[i].length
                guard d > 0, d.isFinite else { continue }
                pos[i] += disp[i] * (min(d, temperature) / d)
            }
        }

        // Centre on the origin and fit inside the unit sphere.
        let mean = pos.reduce(Vec3.zero, +) * (1 / Double(n))
        pos = pos.map { $0 - mean }
        let radius = pos.map(\.length).max() ?? 1
        let fit = radius > 0 ? 1 / radius : 1
        var result: [String: Vec3] = [:]
        for (i, topic) in topics.enumerated() { result[topic.id] = pos[i] * fit }
        return result
    }

    // MARK: Tower (prerequisite depth)

    static func tower(_ atlas: Atlas) -> [String: Vec3] {
        let clusterCount = max(1, atlas.clusters.count)
        let sector = 2 * Double.pi / Double(clusterCount)
        let maxDepth = atlas.maxDepth
        var result: [String: Vec3] = [:]
        var groups: [String: [Topic]] = [:]
        for topic in atlas.topics {
            groups["\(atlas.depth(of: topic.id))|\(topic.cluster)", default: []].append(topic)
        }
        for (_, group) in groups {
            let members = group.sorted { $0.title < $1.title }
            let first = members[0]
            let depth = atlas.depth(of: first.id)
            let centerAngle = sector * Double(atlas.clusterPosition(first.cluster))
            let gap = members.count > 1 ? min(0.3, sector * 0.8 / Double(members.count - 1)) : 0
            let y = towerHeight(depth: depth, maxDepth: maxDepth)
            for (j, topic) in members.enumerated() {
                let angle = centerAngle + (Double(j) - Double(members.count - 1) / 2) * gap
                result[topic.id] = Vec3(sin(angle) * towerRadius, y, cos(angle) * towerRadius)
            }
        }
        return result
    }

    /// FNV-1a: a hash that is the same on every run and platform (unlike `Hasher`).
    public static func stableHash(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return hash
    }
}

/// Small, fast, seedable random numbers, so layouts and quizzes are reproducible.
public struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A Double in 0..<1.
    public mutating func unit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }
}
