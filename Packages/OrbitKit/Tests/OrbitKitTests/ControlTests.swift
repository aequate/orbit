import XCTest
@testable import OrbitKit

/// "Try it" controls: every choice must still be a valid, truthful run of the algorithm.
final class ControlTests: XCTestCase {
    var atlas: Atlas { AtlasTests.atlas }

    private func make(_ id: String, _ values: SimValues) -> Simulation {
        Simulations.make(id, values: values)!
    }

    private func lastArray(_ sim: Simulation) -> ArrayScene? {
        guard case .array(let scene)? = sim.frames.last?.scene else { return nil }
        return scene
    }

    private func lastGraph(_ sim: Simulation) -> GraphScene? {
        guard case .graph(let scene)? = sim.frames.last?.scene else { return nil }
        return scene
    }

    func testDefaultsMatchTheFixedExamples() {
        for id in Simulations.ids {
            XCTAssertEqual(Simulations.make(id, values: [:]), Simulations.make(id), id)
            XCTAssertEqual(Simulations.make(id, values: Simulations.defaults(for: id)), Simulations.make(id), id)
        }
    }

    func testMostSimulationsHaveControls() {
        let withControls = Simulations.ids.filter { !Simulations.controls(for: $0).isEmpty }
        XCTAssertGreaterThanOrEqual(withControls.count, 14)
        for id in withControls {
            for control in Simulations.controls(for: id) {
                XCTAssertEqual(control.clamp(control.initial), control.initial, id + "." + control.id)
                XCTAssertFalse(control.display(control.initial).isEmpty, id)
            }
        }
    }

    func testEverySampleBuildsAValidRun() {
        for id in Simulations.ids {
            for control in Simulations.controls(for: id) {
                for value in control.samples {
                    let sim = make(id, [control.id: value])
                    let tag = id + " " + control.id + "=" + String(value)
                    XCTAssertGreaterThanOrEqual(sim.frames.count, 3, tag)
                    for frame in sim.frames {
                        XCTAssertFalse(frame.caption.isEmpty, tag)
                        switch frame.scene {
                        case .graph(let scene):
                            for node in scene.nodes {
                                XCTAssertTrue((0...1).contains(node.x) && (0...1).contains(node.y), tag)
                            }
                        case .curve(let scene):
                            if let p = scene.point { XCTAssertTrue(scene.xRange.contains(p.x), tag) }
                            if let q = scene.secondPoint { XCTAssertTrue(scene.yRange.contains(q.y), tag) }
                        case .buckets(let scene):
                            XCTAssertFalse(scene.buckets.isEmpty, tag)
                        case .array:
                            break
                        }
                    }
                }
            }
        }
    }

    func testClampSnapsAndBounds() {
        let rate = Simulations.controls(for: "gradientDescent")[0]
        XCTAssertEqual(rate.clamp(0.351), 0.35)
        XCTAssertEqual(rate.clamp(9), 2.2)
        XCTAssertEqual(rate.clamp(-1), 0.05)
        let size = Simulations.controls(for: "hashInsert")[0]
        XCTAssertEqual(size.clamp(4), size.initial)
    }

    func testBinarySearchMissingTarget() {
        let sim = make("binarySearch", ["target": 53])
        XCTAssertTrue(sim.frames.last!.caption.contains("not in the list"))
        let found = make("binarySearch", ["target": 3])
        XCTAssertEqual(lastArray(found)!.cells.firstIndex { $0.mark == .done }, 0)
    }

    func testInsertionSortCountsSwaps() {
        let reversed = make("insertionSort", ["list": 2])
        XCTAssertEqual(lastArray(reversed)!.cells.map(\.text), ["1", "2", "3", "5", "8", "9"])
        XCTAssertTrue(reversed.frames.last!.caption.hasPrefix("Sorted with 15 swaps"))
        XCTAssertTrue(make("insertionSort", ["list": 1]).frames.last!.caption.hasPrefix("Sorted with 1 swap."))
    }

    func testGraphSearchFromAnotherStart() {
        XCTAssertEqual(lastGraph(make("bfs", ["start": 3]))!.footer, "Order: D B A E C F G")
        XCTAssertTrue(lastGraph(make("dfs", ["start": 6]))!.footer!.hasPrefix("Order: G C"))
    }

    func testCheapRoadChangesTheRoute() {
        let sim = make("dijkstra", ["sa": 1])
        XCTAssertTrue(sim.frames.last!.caption.contains("S → A → C → T, total 9"), sim.frames.last!.caption)
        XCTAssertTrue(sim.frames.last!.caption.contains("worth taking"))
    }

    func testSortedInsertsMakeAStick() {
        let sim = make("bstInsert", ["order": 1])
        XCTAssertTrue(sim.frames.last!.caption.contains("stick"))
        XCTAssertEqual(lastGraph(sim)!.nodes.count, 8)
        XCTAssertFalse(make("bstInsert", [:]).frames.last!.caption.contains("stick"))
    }

    func testHeapOrders() {
        XCTAssertTrue(make("heapInsert", ["order": 2]).frames.last!.caption.hasPrefix("No swaps"))
        XCTAssertEqual(lastGraph(make("heapInsert", ["order": 1]))!.nodes.first { $0.id == "i0" }?.label, "1")
    }

    func testTablesAndStacksScale() {
        let fib = make("fibTable", ["n": 12])
        XCTAssertEqual(lastArray(fib)!.cells.last?.text, "144")
        XCTAssertTrue(fib.frames.last!.caption.contains("465 calls"))
        XCTAssertEqual(lastArray(make("factorialStack", ["n": 6]))!.label, "Result: 720")
        XCTAssertEqual(lastArray(make("binaryCounter", ["bits": 3]))!.label, "= 7")
        XCTAssertEqual(make("binaryCounter", ["bits": 5]).frames.count, 33)
        XCTAssertTrue(make("halving", ["start": 1000]).frames.last!.caption.hasPrefix("9 halvings"))
    }

    func testHashTableSize() {
        guard case .buckets(let scene)? = make("hashInsert", ["size": 7]).frames.last?.scene else { return XCTFail() }
        XCTAssertEqual(scene.buckets.count, 7)
        XCTAssertEqual(scene.buckets.joined().count, 6)
    }

    func testLearningRates() {
        let wild = make("gradientDescent", ["rate": 2.2])
        XCTAssertTrue(wild.frames.last!.caption.contains("blows up"))
        let exact = make("gradientDescent", ["rate": 1])
        guard case .curve(let one) = exact.frames[1].scene else { return XCTFail() }
        XCTAssertEqual(one.point!.x, 1, accuracy: 1e-9)
        let still = make("gradientDescent", ["start": 1])
        XCTAssertTrue(still.frames.last!.caption.contains("never moves"))
        let slow = make("gradientDescent", ["rate": 0.05])
        XCTAssertTrue(slow.frames.last!.caption.contains("slow"))
    }

    func testTangentSlopeFollowsThePoint() {
        let sim = make("secantTangent", ["at": 3])
        guard case .curve(let scene)? = sim.frames.last?.scene else { return XCTFail() }
        XCTAssertEqual(scene.tangentSlope!, 1.5, accuracy: 1e-9)
        XCTAssertTrue(sim.frames.last!.caption.contains("exactly 1.5"))
        XCTAssertEqual(Simulations.short(-3), "\u{2212}3")
        XCTAssertEqual(Simulations.short(0.25), "0.25")
    }

    // MARK: What to learn next

    func testReadyStartsWithFoundations() {
        let ready = atlas.ready(understood: [], limit: 100)
        XCTAssertFalse(ready.isEmpty)
        XCTAssertTrue(ready.allSatisfy { $0.requires.isEmpty })
    }

    func testReadyUnlocksDependents() {
        let foundations = Set(atlas.topics.filter { $0.requires.isEmpty }.map(\.id))
        let ready = atlas.ready(understood: foundations, limit: 100)
        XCTAssertFalse(ready.isEmpty)
        for topic in ready {
            XCTAssertFalse(foundations.contains(topic.id))
            XCTAssertTrue(topic.requires.allSatisfy { foundations.contains($0) })
        }
        let everything = Set(atlas.topics.map(\.id))
        XCTAssertTrue(atlas.ready(understood: everything).isEmpty)
        XCTAssertEqual(atlas.ready(understood: [], limit: 2).count, 2)
    }

    func testUnfinishedIsMostRecentNotUnderstood() {
        let now = Date()
        let visited: [String: Date] = [
            "binary": now.addingTimeInterval(-50),
            "tcp": now.addingTimeInterval(-10),
            "derivative": now.addingTimeInterval(-30),
        ]
        XCTAssertEqual(atlas.unfinished(understood: [], visited: visited)?.id, "tcp")
        XCTAssertEqual(atlas.unfinished(understood: ["tcp"], visited: visited)?.id, "derivative")
        XCTAssertNil(atlas.unfinished(understood: ["tcp", "derivative", "binary"], visited: visited))
    }
}
