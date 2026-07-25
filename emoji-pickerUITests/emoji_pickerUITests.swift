//
//  emoji_pickerUITests.swift
//  emoji-pickerUITests
//
//  Created by Jakub Gradzewicz on 31/10/2025.
//

import XCTest

final class emoji_pickerUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
    }

    @MainActor
    func testLaunchPerformance() throws {
        let app = XCUIApplication()
        app.launchEnvironment["EMOJI_PICKER_TEST_MODE"] = "1"
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
        }
    }
}
