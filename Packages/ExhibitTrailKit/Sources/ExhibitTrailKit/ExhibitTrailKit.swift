/// ExhibitTrailKit — pure-Swift visit domain for Exhibit Trail.
///
/// Issue #1 (M1) ships only the skeleton namespace so CI has a real,
/// testable target. Issue #2 (M2) lands the visit/stop/order/priority
/// schema and store here, issue #4 the deterministic pacing reducer —
/// all pure functions with no UIKit imports.
public enum ExhibitTrailKit {
    /// Namespace marker for the domain layer.
    public static let domain = "ExhibitTrailKit"

    /// Current build/CI milestone marker consumed by the app's debug surface.
    public static let milestone = "M1-skeleton"
}
