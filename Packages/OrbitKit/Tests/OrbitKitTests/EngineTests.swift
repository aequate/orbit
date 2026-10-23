import XCTest
@testable import OrbitKit

final class EngineTests: XCTestCase {
    var atlas: Atlas { AtlasTests.atlas }

    // MARK: Layout and camera

    func testLayoutsAreFiniteNormalisedAndDeterministic() {
        for layout in MapLayout.allCases {
            let a = GraphLayout.positions(for: atlas, layout: layout)
            let b = GraphLayout.positions(for: atlas, layout: layout)
            XCTAssertEqual(a.count, atlas.topics.count)
            for (id, p) in a {
                XCTAssertTrue(p.isFinite, id)
                XCTAssertLessThanOrEqual(p.length, 1.4, id)
                XCTAssertEqual(p, b[id], id)
            }
        }
    }

    func testOrbitNodesDoNotOverlap() {
        let positions = GraphLayout.positions(for: atlas, layout: .orbit)
        let points = Array(positions.values)
        var closest = Double.infinity
        for i in points.indices {
            for j in points.indices where j > i {
                closest = min(closest, (points[i] - points[j]).length)
            }
        }
        XCTAssertGreaterThan(closest, 0.03)
    }

    func testOrbitClustersStayTogether() {
        let positions = GraphLayout.positions(for: atlas, layout: .orbit)
        func centre(_ cluster: String) -> Vec3 {
            let members = atlas.topics(in: cluster).compactMap { positions[$0.id] }
            var sum = Vec3(0, 0, 0)
            for p in members { sum += p }
            return sum * (1 / Double(members.count))
        }
        // On average, a topic is nearer its own cluster's centre than other clusters' centres.
        var nearOwn = 0
        for topic in atlas.topics {
            let p = positions[topic.id]!
            let own = (p - centre(topic.cluster)).length
            let others = atlas.clusters.filter { $0.id != topic.cluster }.map { (p - centre($0.id)).length }
            if own < others.min()! { nearOwn += 1 }
        }
        XCTAssertGreaterThan(Double(nearOwn) / Double(atlas.topics.count), 0.8)
    }

    func testTowerHeightFollowsDepth() {
        let positions = GraphLayout.positions(for: atlas, layout: .tower)
        XCTAssertLessThan(positions["binary"]!.y, positions["llm"]!.y)
        XCTAssertEqual(GraphLayout.towerHeight(depth: 0, maxDepth: 10), -0.78, accuracy: 1e-9)
        XCTAssertEqual(GraphLayout.towerHeight(depth: 10, maxDepth: 10), 0.78, accuracy: 1e-9)
    }

    func testFacingBringsPointToFront() {
        let points = [Vec3(0.7, 0.2, -0.5), Vec3(-0.3, -0.8, 0.4), Vec3(0, 0.1, -0.9), Vec3(0.5, 0.5, 0.5)]
        for p in points {
            let turn = Camera.facing(p)
            let camera = Camera(yaw: turn.yaw, pitch: turn.pitch)
            let r = camera.rotate(p)
            XCTAssertEqual(r.x, 0, accuracy: 1e-6)
            XCTAssertEqual(r.y, 0, accuracy: 1e-6)
            XCTAssertGreaterThan(r.z, 0)
            let projected = camera.project(p, width: 400, height: 300)
            XCTAssertEqual(projected.x, 200, accuracy: 1e-6)
            XCTAssertEqual(projected.y, 150, accuracy: 1e-6)
        }
    }

    func testShortestTurn() {
        XCTAssertEqual(Camera.shortestTurn(from: 0.1, to: 0.3), 0.2, accuracy: 1e-9)
        XCTAssertEqual(abs(Camera.shortestTurn(from: 3.0, to: -3.0)), 2 * Double.pi - 6, accuracy: 1e-9)
    }

    // MARK: Simulations do what the algorithms really do

    private func lastArray(_ id: String) -> ArrayScene? {
        guard case .array(let scene)? = Simulations.make(id)?.frames.last?.scene else { return nil }
        return scene
    }

    private func lastGraph(_ id: String) -> GraphScene? {
        guard case .graph(let scene)? = Simulations.make(id)?.frames.last?.scene else { return nil }
        return scene
    }

    func testInsertionSortSorts() {
        let values = lastArray("insertionSort")!.cells.map { Int($0.text)! }
        XCTAssertEqual(values, [1, 2, 3, 5, 8, 9])
    }

    func testBinarySearchFindsTarget() {
        let scene = lastArray("binarySearch")!
        let found = scene.cells.firstIndex { $0.mark == .done }
        XCTAssertEqual(found, 9)
        XCTAssertTrue(Simulations.make("binarySearch")!.frames.last!.caption.contains("4 checks"))
    }

    func testGraphSearchOrders() {
        XCTAssertEqual(lastGraph("bfs")!.footer, "Order: A B C D E F G")
        XCTAssertEqual(lastGraph("dfs")!.footer, "Order: A B D E F C G")
    }

    func testDijkstraFindsCheapestRoute() {
        let sim = Simulations.make("dijkstra")!
        XCTAssertTrue(sim.frames.last!.caption.contains("S → B → A → C → T, total 11"))
        let badges = Dictionary(uniqueKeysWithValues: lastGraph("dijkstra")!.nodes.map { ($0.id, $0.badge ?? "") })
        XCTAssertEqual(badges, ["S": "0", "A": "3", "B": "1", "C": "8", "D": "9", "T": "11"])
    }

    func testHeapKeepsMinimumOnTop() {
        let scene = lastGraph("heapInsert")!
        XCTAssertEqual(scene.nodes.first { $0.id == "i0" }?.label, "1")
        XCTAssertEqual(scene.footer, "Array: [1, 3, 2, 5, 6, 8]")
    }

    func testHashTableChains() {
        guard case .buckets(let scene)? = Simulations.make("hashInsert")?.frames.last?.scene else { return XCTFail() }
        let buckets = scene.buckets.map { $0.map(\.text) }
        XCTAssertEqual(buckets, [["bee"], [], ["cat"], ["owl", "ant", "fox"], ["dog"]])
    }

    func testFibonacciAndFactorial() {
        XCTAssertEqual(lastArray("fibTable")!.cells.last?.text, "55")
        XCTAssertTrue(lastArray("factorialStack")!.cells.isEmpty)
        XCTAssertEqual(lastArray("factorialStack")!.label, "Result: 24")
    }

    func testStackAndQueueOrder() {
        let stackOuts = Simulations.make("stackOps")!.frames.compactMap { frame -> String? in
            if case .array(let s) = frame.scene { return s.label }
            return nil
        }
        XCTAssertEqual(stackOuts, ["Out: C", "Out: D", "Out: B"])
        let queueOuts = Simulations.make("queueOps")!.frames.compactMap { frame -> String? in
            if case .array(let s) = frame.scene { return s.label }
            return nil
        }
        XCTAssertEqual(queueOuts, ["Out: A", "Out: B", "Out: C"])
    }

    func testGradientDescentConverges() {
        guard case .curve(let good)? = Simulations.make("gradientDescent")?.frames.last?.scene,
              case .curve(let bad)? = Simulations.make("gradientOvershoot")?.frames.last?.scene else { return XCTFail() }
        XCTAssertEqual(good.point!.x, 1, accuracy: 0.1)
        XCTAssertGreaterThan(abs(bad.point!.x - 1), abs(good.point!.x - 1))
    }

    // MARK: Diagrams

    func testDiagramVisibilityAndHiding() {
        let list = atlas.topic("linked-list")!.diagram!
        let last = list.steps.count - 1
        let visible = list.visible(through: last)
        XCTAssertTrue(visible.contains("b>n"))
        XCTAssertFalse(visible.contains("b>c"))
        XCTAssertTrue(list.fresh(at: 0).contains("a"))
        XCTAssertEqual(list.visible(through: -1), [])
    }

    // MARK: Learning

    func testSchedulerSpacesReviews() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        var card = CardState.new(now: now)
        card = Scheduler.review(card, recall: .solid, now: now)
        XCTAssertEqual(card.interval, 1)
        card = Scheduler.review(card, recall: .solid, now: now)
        XCTAssertEqual(card.interval, 3)
        card = Scheduler.review(card, recall: .solid, now: now)
        XCTAssertGreaterThan(card.interval, 7)
        let lapsed = Scheduler.review(card, recall: .forgot, now: now)
        XCTAssertEqual(lapsed.reps, 0)
        XCTAssertEqual(lapsed.lapses, 1)
        XCTAssertEqual(lapsed.due.timeIntervalSince(now), 600, accuracy: 1)
        XCTAssertGreaterThanOrEqual(lapsed.ease, 1.3)
    }

    func testQuizQuestionsAreValid() {
        let maker = QuizMaker(atlas: atlas)
        let session = maker.session(for: atlas.topics.map(\.id), seed: 42)
        XCTAssertEqual(session.count, atlas.topics.count)
        for q in session {
            XCTAssertEqual(q.choices.count, 4, q.id)
            XCTAssertEqual(Set(q.choices).count, 4, q.id)
            XCTAssertTrue(q.choices.indices.contains(q.answer), q.id)
            let correct = q.choiceTopics[q.answer]
            switch q.kind {
            case .identify: XCTAssertEqual(correct, q.topicID)
            case .needs: XCTAssertTrue(atlas.topic(q.topicID)!.requires.contains(correct))
            case .unlocks: XCTAssertTrue(atlas.topic(correct)!.requires.contains(q.topicID))
            case .gap: XCTAssertTrue(atlas.topic(q.topicID)!.requires.contains(correct))
            }
        }
        XCTAssertEqual(session, maker.session(for: atlas.topics.map(\.id), seed: 42))
    }

    func testLearnerStateRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = StateStore(url: dir.appendingPathComponent("learner.json"))
        XCTAssertEqual(store.load(), LearnerState())
        let now = Date(timeIntervalSince1970: 2_000_000)
        var state = LearnerState()
        state.visit("tcp", now: now)
        state.markUnderstood("tcp", now: now)
        state.settings.aphantasiaMode = true
        state.settings.mapLayout = .tower
        XCTAssertEqual(state.due(now: now), ["tcp"])
        state.record("tcp", recall: .solid, now: now)
        XCTAssertEqual(state.due(now: now), [])
        try store.save(state)
        XCTAssertEqual(store.load(), state)
        try Data("not json".utf8).write(to: store.url)
        XCTAssertEqual(store.load(), LearnerState())
        state.unmarkUnderstood("tcp")
        XCTAssertTrue(state.cards.isEmpty)
    }

    func testSettingsDecodeLeniently() throws {
        let json = Data(#"{"aphantasiaMode":true,"depth":"bogus"}"#.utf8)
        let settings = try JSONDecoder().decode(LearnerSettings.self, from: json)
        XCTAssertTrue(settings.aphantasiaMode)
        XCTAssertEqual(settings.depth, .intro)
        XCTAssertEqual(settings.playback, .normal)
    }
}
