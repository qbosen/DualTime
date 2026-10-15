import XCTest
@testable import DualTime

final class TimeFormattingTests: XCTestCase {
    func testEnglishFormatUses24HourClock() {
        let date = Date(timeIntervalSince1970: 0)
        let timeZone = TimeZone(secondsFromGMT: 0)!
        XCTAssertEqual(TimeFormatting.string(from: date, timeZone: timeZone, language: .english), "Thu Jan 1 00:00")
    }

    func testChineseFormat() {
        let date = Date(timeIntervalSince1970: 0)
        let timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        XCTAssertEqual(TimeFormatting.string(from: date, timeZone: timeZone, language: .chinese), "1月1日 周四 08:00")
    }

    func testNextMinuteBoundary() {
        let date = Date(timeIntervalSince1970: 65)
        XCTAssertEqual(TimeFormatting.nextMinuteBoundary(after: date).timeIntervalSince1970, 120, accuracy: 0.001)
    }
}
