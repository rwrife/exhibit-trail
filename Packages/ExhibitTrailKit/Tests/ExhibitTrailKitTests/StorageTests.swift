import Foundation
import Testing
import GRDB
@testable import ExhibitTrailKit

private func directory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
    // Diagnose the Apple CI entry failure without normalizing paths passed to the store.
    do {
        try VisitStore.safe(url)
    } catch {
        recordSafeBoundaryFailure(url, phase: "created-test-root")
        // Probe only the trusted fixture root; continue to fail on the original URL.
        let resolved = url.resolvingSymlinksInPath()
        let resolvedIsSafe = (try? VisitStore.safe(resolved)) != nil
        Issue.record("safe boundary phase=post-create-resolution accepted=\(resolvedIsSafe)")
        if !resolvedIsSafe { recordSafeBoundaryFailure(resolved, phase: "post-create-resolution") }
        try? FileManager.default.removeItem(at: url)
        throw error
    }
    return url
}
private func recordSafeBoundaryFailure(_ url: URL, phase: String) {
    // Never include component names, full URLs, or Foundation error descriptions.
    let hostAllowed = url.host == nil || url.host == "" || url.host == "localhost"
    let components = url.pathComponents
    var current = URL(fileURLWithPath: "/", isDirectory: true)
    var types: [String] = []
    for (index, component) in components.dropFirst().enumerated() {
        current.appendPathComponent(component)
        let attributes = try? FileManager.default.attributesOfItem(atPath: current.path)
        let type = attributes?[.type] as? FileAttributeType
        let label: String
        switch type {
        case .typeSymbolicLink: label = "symlink"
        case .typeDirectory: label = "directory"
        case .typeRegular: label = "regular"
        case nil: label = "unavailable"
        default: label = "other"
        }
        types.append("\(index + 1):\(label)")
    }
    Issue.record("safe boundary phase=\(phase) fileURL=\(url.isFileURL) hostAllowed=\(hostAllowed) dot=\(components.contains(".")) dotDot=\(components.contains("..")) nul=\(url.path.contains("\0")) components=[\(types.joined(separator: ","))]")
}
private func source(_ directory: URL, _ data: Data = Data([137,80,78,71,13,10,26,10,1,2,3])) throws -> URL {
    let url = directory.appendingPathComponent(UUID().uuidString)
    try data.write(to: url)
    return url
}
private func rejects(_ body: () async throws -> Void) async {
    do { try await body(); Issue.record("Expected rejection") } catch { }
}

@Suite struct StorageTests {
    @Test func roundTripOrderingEmptyAndRestart() async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let store = try VisitStore(directory: root)
        #expect(try await store.visits().isEmpty)
        var visit = Visit(title: "Museum", stops: [Stop(title: "A", priority: .bonus, pin: Pin(x: 0, y: 1)), Stop(title: "B", priority: .mustSee, note: "private")])
        try await store.save(visit)
        visit.stops.reverse()
        try await store.save(visit)
        visit.stops[0].state = .viewed; visit.stops[0].viewedAt = 12
        visit.stops[1].state = .unviewed
        try await store.save(visit)
        let reopened = try VisitStore(directory: root)
        #expect(try await reopened.visits() == [visit])
        #expect(try await reopened.attachments(visitID: visit.id).isEmpty)
        visit.stops = []
        try await store.save(visit)
        #expect(try await store.visits() == [visit])
        try await store.deleteVisit(id: visit.id)
        #expect(try await store.visits().isEmpty)
    }

    @Test func realV1FixtureMigration() async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let visit = Visit(id: "11111111-1111-1111-1111-111111111111", title: "Historical", createdAt: 123, stops: [Stop(id: "22222222-2222-2222-2222-222222222222", title: "No completion evidence", priority: .mustSee)])
        let destination = root.appendingPathComponent("visits.sqlite")
        // Missing fixture is a test failure, never a generated substitute.
        let fixture = try #require(Bundle.module.url(forResource: "v1", withExtension: "sqlite"))
        try FileManager.default.copyItem(at: fixture, to: destination)
        let store = try VisitStore(directory: root)
        #expect(try await store.visits() == [visit])
        #expect(try await store.visits()[0].stops[0].state == .unknown)
        let reopened = try VisitStore(directory: root)
        #expect(try await reopened.visits() == [visit])
    }

    @Test func invalidDomainAndReferencesPreserveState() async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let store = try VisitStore(directory: root)
        let old = Visit(title: "old", stops: [Stop(title: "A")])
        try await store.save(old)
        for coordinate in [Double.nan, .infinity, -.infinity, -0.001, 1.001] {
            var invalid = old; invalid.stops[0].pin = Pin(x: coordinate, y: 0.5)
            await rejects { try await store.save(invalid) }
            invalid.stops[0].pin = Pin(x: 0.5, y: coordinate)
            await rejects { try await store.save(invalid) }
        }
        for badID in ["", "../outside", UUID().uuidString.uppercased(), String(repeating: "x", count: 36)] {
            var invalid = old; invalid.id = badID
            await rejects { try await store.save(invalid) }
            invalid = old; invalid.stops[0].id = badID
            await rejects { try await store.save(invalid) }
        }
        var invalid = old; invalid.stops.append(invalid.stops[0])
        await rejects { try await store.save(invalid) }
        for time in [Double.nan, .infinity, -.infinity] {
            invalid = old; invalid.createdAt = time
            await rejects { try await store.save(invalid) }
            invalid = old; invalid.stops[0].state = .viewed; invalid.stops[0].viewedAt = time
            await rejects { try await store.save(invalid) }
        }
        invalid = old; invalid.stops[0].state = .viewed
        await rejects { try await store.save(invalid) }
        invalid = old; invalid.stops[0].viewedAt = 1
        await rejects { try await store.save(invalid) }
        invalid = Visit(title: "Other", stops: old.stops)
        await rejects { try await store.save(invalid) }
        #expect(try await store.visits() == [old])
        var changed = old; changed.title = "new"; changed.stops[0].note = "new"
        await store.failNext(.databaseWrite)
        await rejects { try await store.save(changed) }
        #expect(try await store.visits() == [old])
    }

    @Test func schemaRejectsEnumsCoordinatesOrderAndBrokenReferences() async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let store = try VisitStore(directory: root)
        let visit = Visit(title: "v", stops: [Stop(title: "a"), Stop(title: "b")])
        try await store.save(visit)
        let queue = try DatabaseQueue(path: root.appendingPathComponent("visits.sqlite").path)
        for sql in ["UPDATE stops SET id='xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'", "UPDATE stops SET priority='invalid'", "UPDATE stops SET state='invalid'", "UPDATE stops SET x=2,y=0", "UPDATE stops SET x=NULL,y=0", "UPDATE stops SET position=-1", "UPDATE stops SET position=0.5", "UPDATE visits SET createdAt='bad'", "UPDATE stops SET x='bad',y=0", "UPDATE stops SET position=0", "UPDATE stops SET visitID='missing'", "UPDATE stops SET viewedAt=1"] {
            #expect(throws: (any Error).self) { try queue.write { try $0.execute(sql: sql) } }
        }
        #expect(try await store.visits() == [visit])
        // A gap can be present in a corrupt external DB: the loader rejects it.
        try await queue.write { try $0.execute(sql: "UPDATE stops SET position=4 WHERE position=1") }
        await rejects { _ = try await store.visits() }
    }

    @Test func assetsAtomicReplacementMissingAndDeletion() async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let store = try VisitStore(directory: root.appendingPathComponent("store"))
        let visit = Visit(title: "v", stops: [Stop(title: "a")])
        try await store.save(visit)
        let file = try source(root)
        let old = try await store.importAsset(from: file, visitID: visit.id, stopID: visit.stops[0].id, type: .png, width: 1, height: 2)
        let oldData = try await store.attachmentData(id: old.id)
        let reopened = try VisitStore(directory: root.appendingPathComponent("store"))
        #expect(try await reopened.attachments(visitID: visit.id) == [old])
        #expect(try await reopened.attachmentData(id: old.id) == oldData)
        for failure in [VisitStore.Failure.fileWrite, .databaseWrite] {
            await store.failNext(failure)
            await rejects { _ = try await store.importAsset(from: file, id: old.id, visitID: visit.id, stopID: visit.stops[0].id, type: .png) }
            #expect(try await store.attachments(visitID: visit.id) == [old])
            #expect(try await store.attachmentData(id: old.id) == oldData)
            let names = try FileManager.default.subpathsOfDirectory(atPath: root.appendingPathComponent("store/assets").path)
            #expect(names == [old.filename])
        }
        await store.failNext(.databaseWrite)
        await rejects { try await store.deleteAttachment(id: old.id) }
        #expect(try await store.attachmentData(id: old.id) == oldData)
        var replacement = try await store.importAsset(from: file, id: old.id, visitID: visit.id, stopID: visit.stops[0].id, type: .png)
        #expect(replacement.filename != old.filename)
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("store/assets/" + old.filename).path))
        let retired = replacement
        await store.failNext(.cleanup)
        replacement = try await store.importAsset(from: file, id: old.id, visitID: visit.id, stopID: visit.stops[0].id, type: .png)
        #expect(try await store.attachments(visitID: visit.id) == [replacement])
        #expect(try await store.attachmentData(id: old.id) == oldData)
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("store/assets/" + retired.filename).path))
        try await reopened.cleanup()
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("store/assets/" + retired.filename).path))
        try FileManager.default.removeItem(at: root.appendingPathComponent("store/assets/" + replacement.filename))
        do { _ = try await store.attachmentData(id: old.id); Issue.record("missing file accepted") }
        catch { #expect(error as? StorageError == .missingAttachment) }
        #expect(try await store.visits()[0].stops[0].state == .unknown)
        try await store.deleteAttachment(id: old.id)
        #expect(try await store.attachments(visitID: visit.id).isEmpty)
        let stopAsset = try await store.importAsset(from: file, visitID: visit.id, stopID: visit.stops[0].id, type: .png)
        var withoutStops = visit; withoutStops.stops = []
        await store.failNext(.databaseWrite)
        await rejects { try await store.save(withoutStops) }
        #expect(try await store.attachmentData(id: stopAsset.id) == oldData)
        #expect(try await store.visits() == [visit])
        try await store.save(withoutStops)
        #expect(try await store.attachments(visitID: visit.id).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("store/assets/" + stopAsset.filename).path))
        let added = try await store.importAsset(from: file, visitID: visit.id, type: .png)
        await store.failNext(.cleanup)
        try await store.deleteVisit(id: visit.id)
        #expect(try await store.visits().isEmpty)
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("store/assets/" + added.filename).path))
        let restarted = try VisitStore(directory: root.appendingPathComponent("store"))
        try await restarted.cleanup()
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("store/assets/" + added.filename).path))
    }

    @Test func corruptAttachmentPathsAndSymlinksNeverDeleteOutside() async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let storeRoot = root.appendingPathComponent("store")
        let store = try VisitStore(directory: storeRoot)
        let visit = Visit(title: "v")
        try await store.save(visit)
        let outside = try source(root)
        let asset = try await store.importAsset(from: outside, visitID: visit.id, type: .png)
        let owned = storeRoot.appendingPathComponent("assets/" + asset.filename)
        try FileManager.default.removeItem(at: owned)
        try FileManager.default.createSymbolicLink(at: owned, withDestinationURL: outside)
        await rejects { _ = try await store.attachmentData(id: asset.id) }
        try await store.deleteAttachment(id: asset.id)
        #expect(FileManager.default.fileExists(atPath: outside.path))
        // DB deletion committed; cleanup rejects the symlink and remains retryable.
        await rejects { try await store.cleanup() }
        try FileManager.default.removeItem(at: owned)
        try await store.cleanup()
        let newAsset = try await store.importAsset(from: outside, visitID: visit.id, type: .png)
        let queue = try DatabaseQueue(path: storeRoot.appendingPathComponent("visits.sqlite").path)
        try await queue.write { db in
            try db.execute(sql: "UPDATE attachments SET filename=? WHERE id=?", arguments: ["../../" + outside.lastPathComponent, newAsset.id])
        }
        await rejects { _ = try await store.attachmentData(id: newAsset.id) }
        try await store.deleteAttachment(id: newAsset.id)
        #expect(FileManager.default.fileExists(atPath: outside.path))
        await rejects { try await store.cleanup() }
    }

    @Test func adversarialAssetTypesSizesDimensionsAndPaths() async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let store = try VisitStore(directory: root.appendingPathComponent("store"))
        let visit = Visit(title: "v")
        try await store.save(visit)
        let file = try source(root)
        for data in [Data(), Data("not an image".utf8), Data([255,216]), Data(repeating: 1, count: VisitStore.maximumAssetBytes + 1)] {
            let bad = try source(root, data)
            await rejects { _ = try await store.importAsset(from: bad, visitID: visit.id, type: .png) }
        }
        await rejects { _ = try await store.importAsset(from: file, visitID: visit.id, type: .pdf) }
        for (width, height) in [(Double.nan, 1.0), (.infinity, 1), (0, 1), (1, -1), (100_001, 1)] {
            await rejects { _ = try await store.importAsset(from: file, visitID: visit.id, type: .png, width: width, height: height) }
        }
        await rejects { _ = try await store.importAsset(from: file, visitID: visit.id, type: .png, width: 1) }
        await rejects { _ = try await store.importAsset(from: file, visitID: UUID().uuidString.lowercased(), type: .png) }
        await rejects { _ = try await store.importAsset(from: file, visitID: visit.id, stopID: UUID().uuidString.lowercased(), type: .png) }
        let link = root.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        await rejects { _ = try await store.importAsset(from: link, visitID: visit.id, type: .png) }
        let dirLink = root.appendingPathComponent("dirlink")
        try FileManager.default.createSymbolicLink(at: dirLink, withDestinationURL: root)
        await rejects { _ = try await store.importAsset(from: dirLink.appendingPathComponent(file.lastPathComponent), visitID: visit.id, type: .png) }
        await rejects { _ = try await store.importAsset(from: root.appendingPathComponent("../" + root.lastPathComponent + "/" + file.lastPathComponent), visitID: visit.id, type: .png) }
        await rejects { _ = try await store.importAsset(from: root, visitID: visit.id, type: .png) }
        for text in ["\"ftp://example.invalid/asset\"", "\"file://example.invalid/asset\""] {
            let remote = try JSONDecoder().decode(URL.self, from: Data(text.utf8))
            await rejects { _ = try await store.importAsset(from: remote, visitID: visit.id, type: .png) }
        }
        #expect(throws: StorageError.unsafePath) { _ = try VisitStore(directory: dirLink.appendingPathComponent("db")) }
        #expect(try await store.attachments(visitID: visit.id).isEmpty)
        #expect(try FileManager.default.subpathsOfDirectory(atPath: root.appendingPathComponent("store/assets").path).isEmpty)
        for (type, data) in [(AssetType.pdf, Data("%PDF-1.7\n".utf8)), (.jpeg, Data([255,216,255,224]))] {
            let selected = try source(root, data)
            let asset = try await store.importAsset(from: selected, visitID: visit.id, type: type)
            #expect(try await store.attachmentData(id: asset.id) == data)
            try await store.deleteAttachment(id: asset.id)
        }
    }
}
