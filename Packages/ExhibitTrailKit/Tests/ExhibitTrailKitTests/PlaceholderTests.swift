import Testing
@testable import ExhibitTrailKit

@Suite("Package identity")
struct PlaceholderTests {
    @Test("domain namespace is reachable")
    func domainNamespace() {
        #expect(ExhibitTrailKit.domain == "ExhibitTrailKit")
    }

    @Test("milestone marker is set for M2")
    func milestoneMarker() {
        #expect(ExhibitTrailKit.milestone == "M2-local-storage")
    }
}
