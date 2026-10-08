import Testing
@testable import ExhibitTrailKit

@Suite("Skeleton placeholder")
struct PlaceholderTests {
    @Test("domain namespace is reachable")
    func domainNamespace() {
        #expect(ExhibitTrailKit.domain == "ExhibitTrailKit")
    }

    @Test("milestone marker is set for M1")
    func milestoneMarker() {
        #expect(ExhibitTrailKit.milestone == "M1-skeleton")
    }
}
