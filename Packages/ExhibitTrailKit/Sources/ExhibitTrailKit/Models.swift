import Foundation

public enum StorageError: Error, Equatable {
    case invalidData, unsafePath, unsupportedType, oversizedAsset, missingAttachment, injectedFailure
}
public enum Priority: String, Codable, Sendable { case mustSee, interested, bonus }
public enum ViewingState: String, Codable, Sendable { case unknown, unviewed, viewed }
public struct Pin: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}
public struct Stop: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var priority: Priority
    public var pin: Pin?
    public var note: String
    public var state: ViewingState
    public var viewedAt: Double?
    public init(id: String = UUID().uuidString.lowercased(), title: String, priority: Priority = .interested,
                pin: Pin? = nil, note: String = "", state: ViewingState = .unknown, viewedAt: Double? = nil) {
        self.id = id; self.title = title; self.priority = priority; self.pin = pin
        self.note = note; self.state = state; self.viewedAt = viewedAt
    }
}
public struct Visit: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var createdAt: Double
    /// Array position is the persisted order; priority never silently reorders it.
    public var stops: [Stop]
    public init(id: String = UUID().uuidString.lowercased(), title: String, createdAt: Double = Date().timeIntervalSince1970, stops: [Stop] = []) {
        self.id = id; self.title = title; self.createdAt = createdAt; self.stops = stops
    }
}
public enum AssetType: String, Sendable { case pdf, png, jpeg }
public struct Attachment: Equatable, Sendable {
    public let id: String
    public let visitID: String
    public let stopID: String?
    public let type: AssetType
    public let byteCount: Int
    public let width: Double?
    public let height: Double?
    // Only controlled basenames are ever stored, never provider URLs.
    let filename: String
}
func validID(_ value: String) -> Bool {
    UUID(uuidString: value)?.uuidString.lowercased() == value
}
func validate(_ visit: Visit) throws {
    guard validID(visit.id), visit.createdAt.isFinite, visit.stops.count <= 10_000,
          Set(visit.stops.map(\.id)).count == visit.stops.count else { throw StorageError.invalidData }
    for stop in visit.stops {
        guard validID(stop.id), stop.viewedAt?.isFinite != false,
              (stop.state == .viewed) == (stop.viewedAt != nil) else { throw StorageError.invalidData }
        if let pin = stop.pin {
            guard pin.x.isFinite, pin.y.isFinite, (0...1).contains(pin.x), (0...1).contains(pin.y) else { throw StorageError.invalidData }
        }
    }
}
