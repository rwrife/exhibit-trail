import Foundation
import Testing
@testable import ExhibitTrailKit

private func visit(_ states: [ViewingState], departure: Double? = 10_000, per: Int = 10, transition: Int = 5) -> Visit {
    Visit(title: "V", stops: states.map { Stop(title: "S", state: $0, viewedAt: $0 == .viewed ? 1 : nil) },
          departureAt: departure, minutesPerStop: per, transitionMinutes: transition)
}
private func at(_ t: Double) -> Date { Date(timeIntervalSince1970: t) }

@Suite struct PaceTests {
    @Test func noDeadlineMeansNoBudget() {
        #expect(VisitPace.evaluate(visit([.unviewed], departure: nil), at: at(0)) == nil)
        #expect(VisitPace.evaluate(visit([.unviewed], departure: .infinity), at: at(0)) == nil)
    }

    @Test func deadlineEqualityIsZeroNotOverdue() {
        // 1 unviewed stop = 15 min = 900 s. now = deadline - 900 -> budget exactly 0.
        let pace = VisitPace.evaluate(visit([.unviewed]), at: at(10_000 - 900))!
        #expect(pace.budgetSeconds == 0)
        #expect(!pace.isOverdue)
        // Now == deadline with empty queue: zero available, zero needed.
        let atDeadline = VisitPace.evaluate(visit([]), at: at(10_000))!
        #expect(atDeadline.budgetSeconds == 0 && !atDeadline.isOverdue)
    }

    @Test func overdueIsNegativeNeverFalseSlack() {
        let late = VisitPace.evaluate(visit([.unviewed, .unviewed]), at: at(10_000 - 899 + 1_000))!
        #expect(late.isOverdue)
        #expect(late.budgetSeconds < 0)
        // Past the deadline with empty queue is overdue by elapsed time only.
        let past = VisitPace.evaluate(visit([]), at: at(10_060))!
        #expect(past.availableSeconds == -60 && past.isOverdue)
    }

    @Test func emptyAndAllViewedQueuesNeedNoTime() {
        let empty = VisitPace.evaluate(visit([]), at: at(9_000))!
        #expect(empty.unviewedCount == 0 && empty.estimatedSeconds == 0 && empty.budgetSeconds == 1_000)
        let done = VisitPace.evaluate(visit([.viewed, .viewed]), at: at(9_000))!
        #expect(done.unviewedCount == 0 && done.budgetSeconds == 1_000)
    }

    @Test func unknownStopsCountAsRemaining() {
        #expect(VisitPace.evaluate(visit([.unknown, .unviewed, .viewed]), at: at(0))!.unviewedCount == 2)
    }

    @Test func undoRestoresBudgetAndReorderDoesNotChangeIt() {
        var v = visit([.unviewed, .unviewed, .unviewed])
        let before = VisitPace.evaluate(v, at: at(8_000))!
        v.stops[0].state = .viewed; v.stops[0].viewedAt = 1
        let viewed = VisitPace.evaluate(v, at: at(8_000))!
        #expect(viewed.budgetSeconds == before.budgetSeconds + 900)
        v.stops[0].state = .unviewed; v.stops[0].viewedAt = nil
        #expect(VisitPace.evaluate(v, at: at(8_000)) == before)
        v.stops.reverse()
        #expect(VisitPace.evaluate(v, at: at(8_000)) == before)
    }

    @Test func resumeAndWallClockJumpsRecomputeFromInjectedNow() {
        let v = visit([.unviewed])
        // Background for 10 minutes: simply evaluate with the later clock.
        let a = VisitPace.evaluate(v, at: at(5_000))!
        let b = VisitPace.evaluate(v, at: at(5_600))!
        #expect(a.budgetSeconds - b.budgetSeconds == 600)
        // Clock set backwards gives more time; forward past the deadline gives overdue. No hidden state.
        #expect(VisitPace.evaluate(v, at: at(4_000))!.budgetSeconds == a.budgetSeconds + 1_000)
        #expect(VisitPace.evaluate(v, at: at(99_999))!.isOverdue)
    }

    @Test func userBuffersChangeEstimate() {
        let v = visit([.unviewed, .unviewed], per: 20, transition: 0)
        #expect(VisitPace.evaluate(v, at: at(0))!.estimatedSeconds == 2_400)
    }

    @Test func paceSettingsPersistAndMigrate() async throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try VisitStore(directory: root)
        let v = visit([.unviewed], departure: 12_345.5, per: 7, transition: 3)
        try await store.save(v)
        #expect(try await VisitStore(directory: root).visits() == [v])
        for bad in [visit([], per: 0), visit([], per: 241), visit([], transition: -1), visit([], departure: .nan)] {
            await #expect(throws: StorageError.self) { try await store.save(bad) }
        }
        #expect(try await store.visits() == [v])
    }

    @Test func legacyJSONWithoutPaceFieldsDecodesWithDefaults() throws {
        let json = #"{"id":"11111111-1111-1111-1111-111111111111","title":"T","createdAt":1,"stops":[]}"#
        let v = try JSONDecoder().decode(Visit.self, from: Data(json.utf8))
        #expect(v.departureAt == nil && v.minutesPerStop == 10 && v.transitionMinutes == 5)
    }
}
