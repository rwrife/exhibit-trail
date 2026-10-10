import Foundation
import GRDB

/// One actor owns both the database and owned files. Callers must use one store per directory.
public actor VisitStore {
    public static let maximumAssetBytes = 20 * 1024 * 1024
    private let db: DatabaseQueue
    private let assets: URL
    // Internal deterministic failure points exercise the real transaction/file rollback paths.
    enum Failure: Sendable { case fileWrite, databaseWrite, cleanup }
    var failure: Failure?
    func failNext(_ point: Failure) { failure = point }
    private func checkpoint(_ point: Failure) throws {
        if failure == point { failure = nil; throw StorageError.injectedFailure }
    }

    public init(directory: URL) throws {
        try Self.safe(directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        assets = directory.appendingPathComponent("assets", isDirectory: true)
        try Self.safe(assets)
        try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
        let database = directory.appendingPathComponent("visits.sqlite")
        try Self.safe(database)
        for suffix in ["-wal", "-shm", "-journal"] { try Self.safe(URL(fileURLWithPath: database.path + suffix)) }
        db = try DatabaseQueue(path: database.path)
        try Self.migrator().migrate(db)
    }

    static func migrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1-visits-stops") { db in
            try db.execute(sql: """
                CREATE TABLE visits (
                    id TEXT PRIMARY KEY NOT NULL CHECK(length(id)=36 AND id=lower(id) AND substr(id,9,1)='-' AND substr(id,14,1)='-' AND substr(id,19,1)='-' AND substr(id,24,1)='-' AND length(replace(id,'-',''))=32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*'),
                    title TEXT NOT NULL, createdAt REAL NOT NULL CHECK(typeof(createdAt) IN ('integer','real') AND abs(createdAt)<=1.7976931348623157e308));
                CREATE TABLE stops (
                    id TEXT PRIMARY KEY NOT NULL CHECK(length(id)=36 AND id=lower(id) AND substr(id,9,1)='-' AND substr(id,14,1)='-' AND substr(id,19,1)='-' AND substr(id,24,1)='-' AND length(replace(id,'-',''))=32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*'),
                    visitID TEXT NOT NULL REFERENCES visits(id) ON DELETE CASCADE,
                    position INTEGER NOT NULL CHECK(typeof(position)='integer' AND position>=0), title TEXT NOT NULL,
                    priority TEXT NOT NULL CHECK(priority IN ('mustSee','interested','bonus')),
                    x REAL, y REAL,
                    CHECK((x IS NULL AND y IS NULL) OR (x IS NOT NULL AND y IS NOT NULL AND typeof(x) IN ('integer','real') AND typeof(y) IN ('integer','real') AND x>=0 AND x<=1 AND y>=0 AND y<=1)),
                    UNIQUE(visitID,position), UNIQUE(visitID,id));
                """)
        }
        migrator.registerMigration("v2-notes-attachments") { db in
            // Absence of historical completion is unknown, never viewed.
            try db.execute(sql: """
                ALTER TABLE stops ADD COLUMN note TEXT NOT NULL DEFAULT '';
                ALTER TABLE stops ADD COLUMN state TEXT NOT NULL DEFAULT 'unknown' CHECK(state IN ('unknown','unviewed','viewed'));
                ALTER TABLE stops ADD COLUMN viewedAt REAL CHECK(
                    (state='viewed' AND viewedAt IS NOT NULL AND typeof(viewedAt) IN ('integer','real') AND abs(viewedAt)<=1.7976931348623157e308)
                    OR (state!='viewed' AND viewedAt IS NULL));
                CREATE TABLE attachments (
                    id TEXT PRIMARY KEY NOT NULL CHECK(length(id)=36 AND id=lower(id) AND substr(id,9,1)='-' AND substr(id,14,1)='-' AND substr(id,19,1)='-' AND substr(id,24,1)='-' AND length(replace(id,'-',''))=32 AND replace(id,'-','') NOT GLOB '*[^0-9a-f]*'),
                    visitID TEXT NOT NULL REFERENCES visits(id) ON DELETE CASCADE,
                    stopID TEXT, filename TEXT NOT NULL UNIQUE,
                    type TEXT NOT NULL CHECK(type IN ('pdf','png','jpeg')),
                    byteCount INTEGER NOT NULL CHECK(typeof(byteCount)='integer' AND byteCount>0 AND byteCount<=20971520),
                    width REAL, height REAL,
                    CHECK((width IS NULL AND height IS NULL) OR
                        (width IS NOT NULL AND height IS NOT NULL AND typeof(width) IN ('integer','real') AND typeof(height) IN ('integer','real') AND width>0 AND height>0 AND width<=100000 AND height<=100000)),
                    FOREIGN KEY(visitID,stopID) REFERENCES stops(visitID,id) ON DELETE CASCADE);
                CREATE TABLE garbage (filename TEXT PRIMARY KEY NOT NULL);
                CREATE TRIGGER attachment_cleanup AFTER DELETE ON attachments BEGIN
                    INSERT OR IGNORE INTO garbage VALUES (OLD.filename);
                END;
                """)
        }
        return migrator
    }

    public func visits() throws -> [Visit] {
        try db.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM visits ORDER BY createdAt,id").map { row in
                let id: String = row["id"]
                let rows = try Row.fetchAll(db, sql: "SELECT * FROM stops WHERE visitID=? ORDER BY position", arguments: [id])
                let stops = try rows.enumerated().map { position, row -> Stop in
                    guard row["position"] as Int == position,
                          let priority = Priority(rawValue: row["priority"]),
                          let state = ViewingState(rawValue: row["state"]) else { throw StorageError.invalidData }
                    let x: Double? = row["x"], y: Double? = row["y"]
                    guard (x == nil) == (y == nil) else { throw StorageError.invalidData }
                    return Stop(id: row["id"], title: row["title"], priority: priority,
                                pin: x.map { Pin(x: $0, y: y!) }, note: row["note"], state: state, viewedAt: row["viewedAt"])
                }
                let visit = Visit(id: id, title: row["title"], createdAt: row["createdAt"], stops: stops)
                try validate(visit)
                return visit
            }
        }
    }

    public func save(_ visit: Visit) throws {
        try validate(visit)
        try db.write { db in
            try db.execute(sql: "INSERT INTO visits VALUES (?,?,?) ON CONFLICT(id) DO UPDATE SET title=excluded.title,createdAt=excluded.createdAt", arguments: [visit.id, visit.title, visit.createdAt])
            let old = try String.fetchAll(db, sql: "SELECT id FROM stops WHERE visitID=?", arguments: [visit.id])
            for id in old where !visit.stops.contains(where: { $0.id == id }) {
                try db.execute(sql: "DELETE FROM stops WHERE id=?", arguments: [id])
            }
            // Move retained rows out of the range before applying a permutation.
            try db.execute(sql: "UPDATE stops SET position=position+10000 WHERE visitID=?", arguments: [visit.id])
            for (position, stop) in visit.stops.enumerated() {
                let owner = try String.fetchOne(db, sql: "SELECT visitID FROM stops WHERE id=?", arguments: [stop.id])
                guard owner == nil || owner == visit.id else { throw StorageError.invalidData }
                try db.execute(sql: """
                    INSERT INTO stops (id,visitID,position,title,priority,x,y,note,state,viewedAt) VALUES (?,?,?,?,?,?,?,?,?,?)
                    ON CONFLICT(id) DO UPDATE SET position=excluded.position,title=excluded.title,priority=excluded.priority,
                    x=excluded.x,y=excluded.y,note=excluded.note,state=excluded.state,viewedAt=excluded.viewedAt
                    """, arguments: [stop.id, visit.id, position, stop.title, stop.priority.rawValue, stop.pin?.x, stop.pin?.y, stop.note, stop.state.rawValue, stop.viewedAt])
            }
            try checkpoint(.databaseWrite)
        }
        // After commit, cleanup failure stays queued; it cannot turn success into a write error.
        try? cleanup()
    }

    public func deleteVisit(id: String) throws {
        guard validID(id) else { throw StorageError.invalidData }
        try db.write { db in
            try db.execute(sql: "DELETE FROM visits WHERE id=?", arguments: [id])
            try checkpoint(.databaseWrite)
        }
        // After commit, cleanup failure stays queued; it cannot turn success into a write error.
        try? cleanup()
    }

    public func attachments(visitID: String) throws -> [Attachment] {
        guard validID(visitID) else { throw StorageError.invalidData }
        return try db.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM attachments WHERE visitID=? ORDER BY id", arguments: [visitID]).map(Self.attachment)
        }
    }
    private static func attachment(_ row: Row) throws -> Attachment {
        let id: String = row["id"], visit: String = row["visitID"], stop: String? = row["stopID"]
        let filename: String = row["filename"], size: Int = row["byteCount"]
        let width: Double? = row["width"], height: Double? = row["height"]
        guard validID(id), validID(visit), stop.map(validID) != false, validFilename(filename),
              let type = AssetType(rawValue: row["type"]), size > 0, size <= maximumAssetBytes else { throw StorageError.invalidData }
        try dimensions(width, height)
        return Attachment(id: id, visitID: visit, stopID: stop, type: type, byteCount: size, width: width, height: height, filename: filename)
    }

    /// Replacing an attachment writes a new immutable file first; rollback removes only that new file.
    @discardableResult
    public func importAsset(from source: URL, id: String = UUID().uuidString.lowercased(), visitID: String,
                            stopID: String? = nil, type: AssetType, width: Double? = nil, height: Double? = nil) throws -> Attachment {
        guard validID(id), validID(visitID), stopID.map(validID) != false else { throw StorageError.invalidData }
        try Self.dimensions(width, height)
        try Self.safe(source)
        let values = try source.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true else { throw StorageError.unsafePath }
        guard let size = values.fileSize, size > 0, size <= Self.maximumAssetBytes else { throw StorageError.oversizedAsset }
        try Self.safe(assets)
        let filename = UUID().uuidString.lowercased() + ".asset"
        let destination = assets.appendingPathComponent(filename)
        try Self.safe(destination)
        guard !FileManager.default.fileExists(atPath: destination.path),
              FileManager.default.createFile(atPath: destination.path, contents: nil) else { throw StorageError.unsafePath }
        var committed = false
        defer { if !committed { try? FileManager.default.removeItem(at: destination) } }
        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }
        guard let output = OutputStream(url: destination, append: false) else { throw StorageError.unsafePath }
        output.open()
        defer { output.close() }
        var count = 0
        var prefix = Data()
        while let chunk = try input.read(upToCount: 64 * 1024), !chunk.isEmpty {
            count += chunk.count
            guard count <= Self.maximumAssetBytes else { throw StorageError.oversizedAsset }
            if prefix.count < 16 { prefix.append(chunk.prefix(16 - prefix.count)) }
            try chunk.withUnsafeBytes { buffer in
                guard let bytes = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { throw StorageError.invalidData }
                var offset = 0
                while offset < chunk.count {
                    let written = output.write(bytes.advanced(by: offset), maxLength: chunk.count - offset)
                    guard written > 0 else { throw CocoaError(.fileWriteUnknown) }
                    offset += written
                }
            }
            try checkpoint(.fileWrite)
        }
        guard count == size, Self.matches(prefix, type) else { throw StorageError.unsupportedType }
        guard output.streamStatus != .error else { throw CocoaError(.fileWriteUnknown) }
        output.close()
        // Flush the completed local file before making its reference durable.
        let completed = try FileHandle(forWritingTo: destination)
        defer { try? completed.close() }
        try completed.synchronize()
        try completed.close()
        try db.write { db in
            // DELETE triggers cleanup, but only once this transaction commits.
            if let old = try Row.fetchOne(db, sql: "SELECT * FROM attachments WHERE id=?", arguments: [id]) {
                guard old["visitID"] as String == visitID, old["stopID"] as String? == stopID else { throw StorageError.invalidData }
                try db.execute(sql: "DELETE FROM attachments WHERE id=?", arguments: [id])
            }
            try db.execute(sql: "INSERT INTO attachments VALUES (?,?,?,?,?,?,?,?)", arguments: [id, visitID, stopID, filename, type.rawValue, count, width, height])
            try checkpoint(.databaseWrite)
        }
        committed = true
        // After commit, cleanup failure stays queued; it cannot turn success into a write error.
        try? cleanup()
        return Attachment(id: id, visitID: visitID, stopID: stopID, type: type, byteCount: count, width: width, height: height, filename: filename)
    }

    /// Missing files are an explicit error. Reading never mutates viewing state.
    public func attachmentData(id: String) throws -> Data {
        guard validID(id) else { throw StorageError.invalidData }
        let attachment = try db.read { db -> Attachment in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM attachments WHERE id=?", arguments: [id]) else { throw StorageError.missingAttachment }
            return try Self.attachment(row)
        }
        let url = assets.appendingPathComponent(attachment.filename)
        try Self.safe(url)
        guard FileManager.default.fileExists(atPath: url.path) else { throw StorageError.missingAttachment }
        guard try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { throw StorageError.unsafePath }
        let input = try FileHandle(forReadingFrom: url)
        defer { try? input.close() }
        var data = Data()
        while let chunk = try input.read(upToCount: min(64 * 1024, Self.maximumAssetBytes + 1 - data.count)), !chunk.isEmpty {
            data.append(chunk)
            guard data.count <= Self.maximumAssetBytes else { throw StorageError.oversizedAsset }
        }
        guard data.count == attachment.byteCount, Self.matches(data, attachment.type) else { throw StorageError.invalidData }
        return data
    }

    public func deleteAttachment(id: String) throws {
        guard validID(id) else { throw StorageError.invalidData }
        try db.write { db in
            try db.execute(sql: "DELETE FROM attachments WHERE id=?", arguments: [id])
            try checkpoint(.databaseWrite)
        }
        // After commit, cleanup failure stays queued; it cannot turn success into a write error.
        try? cleanup()
    }
    /// Durable cleanup can be retried after restart. Failure means DB deletion committed, cleanup pending.
    public func cleanup() throws {
        for filename in try db.read({ try String.fetchAll($0, sql: "SELECT filename FROM garbage") }) {
            guard Self.validFilename(filename) else { throw StorageError.unsafePath }
            let file = assets.appendingPathComponent(filename)
            try Self.safe(file)
            try checkpoint(.cleanup)
            if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
            try db.write { try $0.execute(sql: "DELETE FROM garbage WHERE filename=?", arguments: [filename]) }
        }
    }
    private static func dimensions(_ width: Double?, _ height: Double?) throws {
        guard (width == nil) == (height == nil) else { throw StorageError.invalidData }
        if let width, let height {
            guard width.isFinite, height.isFinite, width > 0, height > 0, width <= 100_000, height <= 100_000 else { throw StorageError.invalidData }
        }
    }
    private static func matches(_ data: Data, _ type: AssetType) -> Bool {
        switch type {
        case .pdf: data.starts(with: Array("%PDF-".utf8))
        case .png: data.starts(with: [137,80,78,71,13,10,26,10])
        case .jpeg: data.starts(with: [255,216,255])
        }
    }
    private static func validFilename(_ name: String) -> Bool {
        name.hasSuffix(".asset") && validID(String(name.dropLast(6)))
    }
    static func safe(_ url: URL) throws {
        guard url.isFileURL, url.host == nil || url.host == "" || url.host == "localhost",
              !url.pathComponents.contains(".."), !url.pathComponents.contains("."), !url.path.contains("\0") else { throw StorageError.unsafePath }
        var current = URL(fileURLWithPath: "/", isDirectory: true)
        for component in url.pathComponents.dropFirst() {
            current.appendPathComponent(component)
            if let attributes = try? FileManager.default.attributesOfItem(atPath: current.path),
               attributes[.type] as? FileAttributeType == .typeSymbolicLink {
                #if os(macOS) || os(iOS)
                // Foundation collapses /private/var to /var even after resolving symlinks.
                // Only this OS-owned root alias is accepted; user/asset links remain rejected.
                guard current.path == "/var" else { throw StorageError.unsafePath }
                let target = try FileManager.default.destinationOfSymbolicLink(atPath: current.path)
                guard target == "private/var" || target == "/private/var" else { throw StorageError.unsafePath }
                current = URL(fileURLWithPath: "/private/var", isDirectory: true)
                #else
                throw StorageError.unsafePath
                #endif
            }
        }
    }
}
