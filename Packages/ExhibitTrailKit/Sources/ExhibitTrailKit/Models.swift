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
    /// User-entered wall-clock departure, never inferred venue closing time.
    public var departureAt: Double?
    public var minutesPerStop: Int
    /// User estimate for each unviewed stop, including approach to the first.
    public var transitionMinutes: Int
    public init(id: String = UUID().uuidString.lowercased(), title: String, createdAt: Double = Date().timeIntervalSince1970,
                stops: [Stop] = [], departureAt: Double? = nil, minutesPerStop: Int = 10, transitionMinutes: Int = 5) {
        self.id = id; self.title = title; self.createdAt = createdAt; self.stops = stops
        self.departureAt = departureAt; self.minutesPerStop = minutesPerStop; self.transitionMinutes = transitionMinutes
    }
    private enum CodingKeys: String, CodingKey { case id, title, createdAt, stops, departureAt, minutesPerStop, transitionMinutes }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try values.decode(String.self, forKey: .id),
                  title: try values.decode(String.self, forKey: .title),
                  createdAt: try values.decode(Double.self, forKey: .createdAt),
                  stops: try values.decode([Stop].self, forKey: .stops),
                  departureAt: try values.decodeIfPresent(Double.self, forKey: .departureAt),
                  minutesPerStop: try values.decodeIfPresent(Int.self, forKey: .minutesPerStop) ?? 10,
                  transitionMinutes: try values.decodeIfPresent(Int.self, forKey: .transitionMinutes) ?? 5)
    }
}

/// Pure wall-clock snapshot. Recalculate on each foreground render; no timers or routing claims.
public struct VisitPace: Equatable, Sendable {
    public let unviewedCount: Int
    public let availableSeconds: Double
    public let estimatedSeconds: Double
    public let budgetSeconds: Double
    public var isOverdue: Bool { budgetSeconds < 0 }
    public static func evaluate(_ visit: Visit, at now: Date) -> VisitPace? {
        guard let deadline = visit.departureAt, deadline.isFinite else { return nil }
        let count = visit.stops.filter { $0.state != .viewed }.count
        let available = deadline - now.timeIntervalSince1970
        let estimated = Double(count) * Double(visit.minutesPerStop + visit.transitionMinutes) * 60
        return VisitPace(unviewedCount: count, availableSeconds: available,
                         estimatedSeconds: estimated, budgetSeconds: available - estimated)
    }
}
/// Coordinate space is the displayed, orientation-corrected page, independent of view size and zoom.
public struct FloorPlan: Equatable, Sendable {
    public let attachmentID: String
    public let page: Int // Zero-based PDF page; image page is 0.
    public let width: Double
    public let height: Double
    public init(attachmentID: String, page: Int, width: Double, height: Double) {
        self.attachmentID = attachmentID; self.page = page; self.width = width; self.height = height
    }
}
public enum MapCoordinate {
    /// Use displayed image bounds, not the surrounding scroll view. Zoom transforms the whole canvas.
    public static func pin(x: Double, y: Double, width: Double, height: Double) -> Pin? {
        guard x.isFinite, y.isFinite, width.isFinite, height.isFinite,
              width > 0, height > 0, (0...width).contains(x), (0...height).contains(y) else { return nil }
        return Pin(x: x / width, y: y / height)
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
          visit.departureAt?.isFinite != false,
          (1...240).contains(visit.minutesPerStop), (0...240).contains(visit.transitionMinutes),
          Set(visit.stops.map(\.id)).count == visit.stops.count else { throw StorageError.invalidData }
    for stop in visit.stops {
        guard validID(stop.id), stop.viewedAt?.isFinite != false,
              (stop.state == .viewed) == (stop.viewedAt != nil) else { throw StorageError.invalidData }
        if let pin = stop.pin {
            guard pin.x.isFinite, pin.y.isFinite, (0...1).contains(pin.x), (0...1).contains(pin.y) else { throw StorageError.invalidData }
        }
    }
}
