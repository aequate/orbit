import XCTest
@testable import OrbitKit

final class AtlasTests: XCTestCase {
    static let atlas: Atlas = {
        do { return try Atlas.bundled() } catch { fatalError("Atlas failed to load: \(error)") }
    }()

    var atlas: Atlas { Self.atlas }

    func testContentLoadsAndIsClean() {
        XCTAssertEqual(atlas.clusters.count, 6)
        XCTAssertGreaterThanOrEqual(atlas.topics.count, 50)
        XCTAssertEqual(atlas.issues(), [])
    }

    func testEverySimulationIsReferencedAndBuilds() {
        let used = Set(atlas.topics.flatMap(\.simulations))
        XCTAssertEqual(used, Set(Simulations.ids))
        for id in Simulations.ids {
            guard let sim = Simulations.make(id) else { return XCTFail("missing sim \(id)") }
            XCTAssertGreaterThanOrEqual(sim.frames.count, 3, id)
            for frame in sim.frames {
                XCTAssertFalse(frame.caption.isEmpty, id)
                if case .graph(let scene) = frame.scene {
                    for node in scene.nodes {
                        XCTAssertTrue((0...1).contains(node.x) && (0...1).contains(node.y), id)
                    }
                    let ids = Set(scene.nodes.map(\.id))
                    for edge in scene.edges {
                        XCTAssertTrue(ids.contains(edge.from) && ids.contains(edge.to), id)
                    }
                }
            }
        }
    }

    func testTunnelIsTopologicallyOrdered() {
        let tunnel = atlas.tunnel(to: "llm").map(\.id)
        XCTAssertFalse(tunnel.contains("llm"))
        XCTAssertTrue(tunnel.contains("derivative"))
        XCTAssertTrue(tunnel.contains("function"))
        for (index, id) in tunnel.enumerated() {
            for prereq in atlas.topic(id)!.requires {
                guard let at = tunnel.firstIndex(of: prereq) else { return XCTFail("\(prereq) missing from tunnel") }
                XCTAssertLessThan(at, index, "\(prereq) should come before \(id)")
            }
        }
        XCTAssertEqual(atlas.tunnel(to: "binary").count, 0)
    }

    func testWhyPathLeadsToADestination() {
        let path = atlas.whyPath(from: "derivative").map(\.id)
        XCTAssertEqual(path.first, "derivative")
        XCTAssertGreaterThan(path.count, 2)
        XCTAssertTrue(atlas.topic(path.last!)!.destination)
        for i in 1..<path.count {
            XCTAssertTrue(atlas.topic(path[i])!.requires.contains(path[i - 1]))
        }
    }

    func testDownstreamAndDepth() {
        XCTAssertTrue(atlas.downstream(of: "binary").contains("tls"))
        XCTAssertFalse(atlas.downstream(of: "tls").contains("binary"))
        XCTAssertEqual(atlas.depth(of: "binary"), 0)
        XCTAssertGreaterThan(atlas.depth(of: "llm"), atlas.depth(of: "transformer"))
    }

    func testSearch() {
        XCTAssertEqual(atlas.search("tcp").first?.id, "tcp")
        XCTAssertEqual(atlas.search("Hash").first?.id, "hash-table")
        XCTAssertEqual(atlas.search("dictionary").first?.id, "hash-table")
        XCTAssertTrue(atlas.search("").isEmpty)
        XCTAssertTrue(atlas.search("zzzzqq").isEmpty)
    }

    func testContextDiagramIsValid() {
        for topic in atlas.topics {
            let diagram = atlas.contextDiagram(for: topic.id)
            XCTAssertNotNil(diagram, topic.id)
            XCTAssertEqual(diagram?.issues() ?? ["nil"], [], topic.id)
        }
    }

    func testComparisonsAndJourneys() {
        XCTAssertGreaterThanOrEqual(atlas.comparisons.count, 8)
        XCTAssertEqual(atlas.comparisons(involving: "tcp").map(\.id), ["tcp-udp"])
        let journey = atlas.journey("internet")!
        let none = journey.progress(understood: [])
        XCTAssertEqual(none.next, "binary")
        XCTAssertFalse(none.isStarted)
        let all = journey.progress(understood: Set(journey.topics))
        XCTAssertTrue(all.isComplete)
        XCTAssertEqual(all.fraction, 1)
    }

    func testListFormatting() {
        XCTAssertEqual(Atlas.list([]), "")
        XCTAssertEqual(Atlas.list(["A"]), "A")
        XCTAssertEqual(Atlas.list(["A", "B"]), "A and B")
        XCTAssertEqual(Atlas.list(["A", "B", "C"]), "A, B and C")
    }

    func testTutorFallbacksAreNeverEmpty() {
        for topic in atlas.topics {
            for ask in TutorAsk.allCases {
                XCTAssertFalse(Tutor.fallback(ask, topic: topic, atlas: atlas).isEmpty, topic.id + " " + ask.rawValue)
            }
            XCTAssertTrue(Tutor.instructions(for: topic, atlas: atlas).contains(topic.levels.core))
        }
    }
}
