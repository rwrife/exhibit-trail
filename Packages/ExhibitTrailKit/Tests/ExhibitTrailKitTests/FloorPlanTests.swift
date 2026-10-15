import Foundation
import Testing
@testable import ExhibitTrailKit

@Suite struct FloorPlanTests {
    @Test func coordinatesAreScaleIndependentAndBounded() {
        #expect(MapCoordinate.pin(x: 150, y: 75, width: 300, height: 150) == Pin(x: 0.5, y: 0.5))
        #expect(MapCoordinate.pin(x: 600, y: 300, width: 1200, height: 600) == Pin(x: 0.5, y: 0.5))
        // After rotation the canvas size changes, normalized placement remains stable.
        #expect(MapCoordinate.pin(x: 100, y: 200, width: 200, height: 400) == Pin(x: 0.5, y: 0.5))
        for (x, y, w, h) in [(-1.0, 0.0, 20.0, 20.0), (21.0, 0.0, 20.0, 20.0), (.nan, 0.0, 20.0, 20.0),
                              (1.0, .infinity, 20.0, 20.0), (1.0, 1.0, 0.0, 20.0)] {
            #expect(MapCoordinate.pin(x: x, y: y, width: w, height: h) == nil)
        }
    }

    @Test func floorPlanPersistsPageDimensionsAndRetainsStops() async throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try VisitStore(directory: root.appendingPathComponent("store"))
        var visit = Visit(title: "Museum", stops: [Stop(title: "A", pin: Pin(x: 0.25, y: 0.75))])
        try await store.save(visit)
        let file = root.appendingPathComponent("map.pdf")
        try Data("%PDF-1.7\n".utf8).write(to: file)
        let asset = try await store.importAsset(from: file, visitID: visit.id, type: .pdf, width: 800, height: 600)
        let first = FloorPlan(attachmentID: asset.id, page: 2, width: 800, height: 600)
        try await store.setFloorPlan(first, visitID: visit.id)
        let reopened = try VisitStore(directory: root.appendingPathComponent("store"))
        #expect(try await reopened.floorPlan(visitID: visit.id) == first)
        visit.stops.reverse()
        try await store.save(visit)
        #expect(try await reopened.visits() == [visit])
        let changed = FloorPlan(attachmentID: asset.id, page: 3, width: 800, height: 600)
        try await store.setFloorPlan(changed, visitID: visit.id)
        #expect(try await reopened.floorPlan(visitID: visit.id) == changed)
        for wrong in [FloorPlan(attachmentID: asset.id, page: 100, width: 800, height: 600),
                      FloorPlan(attachmentID: asset.id, page: 1, width: .nan, height: 600),
                      FloorPlan(attachmentID: UUID().uuidString.lowercased(), page: 1, width: 800, height: 600)] {
            do { try await store.setFloorPlan(wrong, visitID: visit.id); Issue.record("invalid plan accepted") }
            catch { }
            #expect(try await store.floorPlan(visitID: visit.id) == changed)
        }
        await store.failNext(.databaseWrite)
        do { try await store.setFloorPlan(first, visitID: visit.id); Issue.record("failed transaction committed") }
        catch { }
        #expect(try await store.floorPlan(visitID: visit.id) == changed)
        try await store.deleteAttachment(id: asset.id)
        #expect(try await store.floorPlan(visitID: visit.id) == nil)
    }
}
