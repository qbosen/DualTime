import AppKit
import XCTest
@testable import DualTime

final class TimeFormattingTests: XCTestCase {
    private let epoch = Date(timeIntervalSince1970: 0)
    private let utc = TimeZone(secondsFromGMT: 0)!

    func testEnglishFormatUses24HourClock() {
        XCTAssertEqual(
            TimeFormatting.string(from: epoch, timeZone: utc, language: .english),
            "Thu Jan 1 00:00"
        )
    }

    func testChineseFormat() {
        let shanghai = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        XCTAssertEqual(
            TimeFormatting.string(from: epoch, timeZone: shanghai, language: .chinese),
            "1月1日 周四 08:00"
        )
    }

    func testDateAndWeekdayCanBeHiddenIndependently() {
        XCTAssertEqual(
            TimeFormatting.string(from: epoch, timeZone: utc, language: .english, showDate: false),
            "Thu 00:00"
        )
        XCTAssertEqual(
            TimeFormatting.string(from: epoch, timeZone: utc, language: .english, showWeekday: false),
            "Jan 1 00:00"
        )
        XCTAssertEqual(
            TimeFormatting.string(from: epoch, timeZone: utc, language: .english, showDate: false, showWeekday: false),
            "00:00"
        )
    }

    func testSecondsCanBeDisplayed() {
        let date = Date(timeIntervalSince1970: 45)
        XCTAssertEqual(
            TimeFormatting.string(from: date, timeZone: utc, language: .english, showSeconds: true),
            "Thu Jan 1 00:00:45"
        )
    }

    func testSeparatorsCanBeHidden() {
        XCTAssertEqual(
            TimeFormatting.string(from: epoch, timeZone: utc, language: .english, separatorsVisible: false),
            "Thu Jan 1 00 00"
        )
    }

    func testSecondsKeepHourMinuteSeparatorVisibleWhenFlashing() {
        let date = Date(timeIntervalSince1970: 45)
        XCTAssertEqual(
            TimeFormatting.string(from: date, timeZone: utc, language: .english, showSeconds: true, separatorsVisible: false),
            "Thu Jan 1 00:00 45"
        )
    }

    func testMaximumDisplayWidthCoversVisibleAndHiddenSeparators() {
        let width = TimeFormatting.maximumDisplayWidth(
            timeZone: utc,
            language: .english,
            showDate: true,
            showWeekday: true,
            showSeconds: true,
            font: TimeFormatting.statusBarFont
        )
        let visible = TimeFormatting.string(from: epoch, timeZone: utc, language: .english, showSeconds: true, separatorsVisible: true)
        let hidden = TimeFormatting.string(from: epoch, timeZone: utc, language: .english, showSeconds: true, separatorsVisible: false)
        let visibleWidth = (visible as NSString).size(withAttributes: [.font: TimeFormatting.statusBarFont]).width
        let hiddenWidth = (hidden as NSString).size(withAttributes: [.font: TimeFormatting.statusBarFont]).width
        XCTAssertGreaterThanOrEqual(width, max(visibleWidth, hiddenWidth))
    }

    func testNextSecondBoundary() {
        let date = Date(timeIntervalSince1970: 65.25)
        XCTAssertEqual(TimeFormatting.nextSecondBoundary(after: date).timeIntervalSince1970, 66, accuracy: 0.001)
    }

    func testNextMinuteBoundary() {
        let date = Date(timeIntervalSince1970: 65)
        XCTAssertEqual(TimeFormatting.nextMinuteBoundary(after: date).timeIntervalSince1970, 120, accuracy: 0.001)
    }
}
