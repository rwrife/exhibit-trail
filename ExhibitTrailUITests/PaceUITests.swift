import XCTest

final class PaceUITests: XCTestCase {
    /// Foreground pacing journey: user-set deadline, honest budget, edit persists across restart.
    /// Leaf controls only (no Section-level identifiers — SwiftUI identifier cascade pitfall).
    func testDepartureDeadlinePacePersists() {
        let app = XCUIApplication()
        app.launchArguments.append("-ExhibitUITestFixture")
        app.launchEnvironment["EXHIBIT_UI_TEST_STORE"] = UUID().uuidString
        app.launch()

        app.buttons["Start local visit"].tap()
        let toggle = app.switches.matching(NSPredicate(format: "label CONTAINS 'departure deadline'")).firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "Departure-deadline toggle exists")
        toggle.switches.firstMatch.tap()

        let budget = app.staticTexts["pace.budget"]
        XCTAssertTrue(budget.waitForExistence(timeout: 5), "Budget appears once deadline is set")
        XCTAssertTrue(budget.label.contains("minutes"), "Budget speaks in minutes: \(budget.label)")
        XCTAssertTrue(app.staticTexts["pace.estimate"].label.contains("0 stops left"),
                      "Empty queue needs no estimated time: \(app.staticTexts["pace.estimate"].label)")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'No inferred transit'")).firstMatch.exists,
                      "Budget is labeled as user-input estimate, not verified travel")

        let stepper = app.steppers.matching(NSPredicate(format: "label CONTAINS 'Minutes per stop'")).firstMatch
        XCTAssertTrue(stepper.waitForExistence(timeout: 5), "Minutes-per-stop stepper exists")
        // Budget counts down as the user's own estimate grows: +1 minute per stop, empty queue => unchanged?
        // (0 stops => estimate stays 0; assert the readable line remains budget text, edit still persists.)
        stepper.buttons["Increment"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Minutes per stop: 11'")).firstMatch.waitForExistence(timeout: 5),
                      "Estimate edit changes the visible value")

        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Minutes per stop: 11'")).firstMatch.waitForExistence(timeout: 15),
                      "Edited estimate persisted across restart")
        XCTAssertTrue(budget.waitForExistence(timeout: 5), "Budget still shows after restart")
        XCTAssertFalse(app.staticTexts["visit.error"].exists, "No storage or validation error")
    }
}
