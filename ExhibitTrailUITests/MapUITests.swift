import XCTest

final class MapUITests: XCTestCase {
    func testMapPinningAndOrderedStopEditing() {
        let app = XCUIApplication()
        app.launchArguments.append("-ExhibitUITestFixture")
        app.launchEnvironment["EXHIBIT_UI_TEST_STORE"] = UUID().uuidString
        app.launch()

        // 1. Start a local visit
        let startButton = app.buttons["Start local visit"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10), "Start local visit button exists")
        startButton.tap()

        // 2. Add an unpinned stop via accessible controls
        let nameField = app.textFields["stop.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Exhibit name field exists")
        nameField.tap()
        nameField.typeText("Ancient Pottery")

        let addStopButton = app.buttons["Add unpinned stop"]
        XCTAssertTrue(addStopButton.exists, "Add unpinned stop button exists")
        addStopButton.tap()

        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Ancient Pottery'")).firstMatch.waitForExistence(timeout: 5),
                      "Unpinned stop appeared in list")

        // 3. Import fixture floor plan
        let importButton = app.buttons["map.fixture"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 5), "Import test fixture map button exists")
        importButton.tap()

        // 4. Zoom buttons exist and respond
        let zoomInButton = app.buttons["Zoom in"]
        XCTAssertTrue(zoomInButton.waitForExistence(timeout: 10), "Zoom in button exists")
        zoomInButton.tap()

        let zoomOutButton = app.buttons["Zoom out"]
        XCTAssertTrue(zoomOutButton.exists, "Zoom out button exists")
        zoomOutButton.tap()

        // 5. Select stop, then tap floor plan to place pin
        // In SwiftUI, Form/List lazy rows scroll off-screen when the floor plan renders above them.
        for _ in 0..<3 {
            if app.buttons.matching(NSPredicate(format: "label CONTAINS 'Ancient Pottery'")).firstMatch.exists { break }
            app.swipeUp()
        }
        let unpinnedRow = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Ancient Pottery'")).firstMatch
        XCTAssertTrue(unpinnedRow.waitForExistence(timeout: 5), "Unpinned stop row exists")
        unpinnedRow.tap()

        // Scroll back up to the floor plan canvas
        for _ in 0..<3 {
            if app.images.firstMatch.isHittable { break }
            app.swipeDown()
        }

        // Tap the floor plan image area to place pin
        let planImage = app.images.firstMatch
        XCTAssertTrue(planImage.waitForExistence(timeout: 5), "Floor plan image exists")
        planImage.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        // Pin button should now exist
        let pin = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Pin 1'")).firstMatch
        XCTAssertTrue(pin.waitForExistence(timeout: 5), "Pin 1 exists on map")

        // Scroll down to check list row now reflects pinned state
        for _ in 0..<3 {
            if app.buttons.matching(NSPredicate(format: "label CONTAINS 'pinned'")).firstMatch.exists { break }
            app.swipeUp()
        }
        let pinnedRow = app.buttons.matching(NSPredicate(format: "label CONTAINS 'pinned'")).firstMatch
        XCTAssertTrue(pinnedRow.waitForExistence(timeout: 5), "Row reflects pinned state")

        // Scroll back up to place second stop directly via map tap
        for _ in 0..<3 {
            if app.images.firstMatch.isHittable { break }
            app.swipeDown()
        }
        planImage.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.25)).tap()
        let pin2 = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Pin 2'")).firstMatch
        XCTAssertTrue(pin2.waitForExistence(timeout: 5), "Pin 2 placed via direct tap")

        // Scroll to reorder controls
        for _ in 0..<3 {
            if app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Move up'")).firstMatch.exists { break }
            app.swipeUp()
        }
        let moveUp = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Move up'")).firstMatch
        if moveUp.waitForExistence(timeout: 3) {
            moveUp.tap()
        }

        // Verify no unexpected error
        XCTAssertFalse(app.staticTexts["visit.error"].exists, "No storage or validation error")
    }
}
