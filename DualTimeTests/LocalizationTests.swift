import Foundation
import XCTest
@testable import DualTime

final class LocalizationTests: XCTestCase {
    override func setUp() {
        super.setUp()
        L10n.bundle = Bundle(for: LocalizationTests.self)
    }

    override func tearDown() {
        L10n.bundle = .main
        super.tearDown()
    }

    func testEnglishSettingsStrings() {
        let locale = Locale(identifier: "en")
        XCTAssertEqual(L10n.string("settings.title", locale: locale), "DualTime Settings")
        XCTAssertEqual(L10n.string("settings.display.showSeconds", locale: locale), "Display the time with seconds")
        XCTAssertEqual(L10n.string("menu.openSettings", locale: locale), "Open Settings")
    }

    func testChineseSettingsStrings() {
        let locale = Locale(identifier: "zh-Hans")
        XCTAssertEqual(L10n.string("settings.title", locale: locale), "DualTime 设置")
        XCTAssertEqual(L10n.string("settings.display.showSeconds", locale: locale), "显示秒")
        XCTAssertEqual(L10n.string("menu.openSettings", locale: locale), "打开设置")
    }
}
