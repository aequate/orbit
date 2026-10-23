import XCTest
import OrbitKit
@testable import Orbit

final class OrbitTests: XCTestCase {
    func testContentLoadsFromTheAppBundle() throws {
        let atlas = try Atlas.bundled()
        XCTAssertGreaterThanOrEqual(atlas.topics.count, 50)
        XCTAssertEqual(atlas.issues(), [])
    }

    @MainActor
    func testModelSavesProgress() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("learner.json")
        let model = AppModel(store: StateStore(url: url))
        XCTAssertNil(model.loadError)
        let id = try XCTUnwrap(model.atlas.topics.first?.id)

        model.toggleUnderstood(id)
        XCTAssertTrue(model.isUnderstood(id))
        XCTAssertEqual(model.dueCount(), 1)

        let reloaded = AppModel(store: StateStore(url: url))
        XCTAssertTrue(reloaded.isUnderstood(id))
    }

    @MainActor
    func testEverySimulationAndLayoutBuilds() throws {
        let model = AppModel(store: StateStore(url: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")))
        for topic in model.atlas.topics {
            for id in topic.simulations {
                XCTAssertNotNil(model.simulation(id), id)
            }
        }
        for layout in MapLayout.allCases {
            XCTAssertEqual(model.positions(layout).count, model.atlas.topics.count)
        }
    }

    func testMapHitPrefersTheNearestNode() {
        let atlas = Atlas(
            clusters: [Cluster(id: "c", name: "C", blurb: "", hue: "blue")],
            topics: [
                Topic(id: "a", title: "A", cluster: "c", summary: "", levels: Levels(intro: "", core: "", deep: "")),
            ]
        )
        let scene = MapScene(atlas: atlas, orbit: ["a": Vec3(0, 0, 0)], tower: ["a": Vec3(0, 0, 0)])
        let size = CGSize(width: 300, height: 300)
        XCTAssertEqual(scene.hit(CGPoint(x: 150, y: 150), camera: Camera(), morph: 0, size: size), "a")
        XCTAssertNil(scene.hit(CGPoint(x: 10, y: 10), camera: Camera(), morph: 0, size: size))
    }
}
