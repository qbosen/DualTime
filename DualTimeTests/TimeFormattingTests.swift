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

    func testWorldClockNamesFollowLanguageAndPreserveCustomNames() {
        var clock = WorldClock(timeZoneIdentifier: "Asia/Shanghai")
        XCTAssertEqual(clock.name(style: .full, language: .chinese), "上海")
        XCTAssertEqual(clock.name(style: .full, language: .english), "Shanghai")
        XCTAssertEqual(clock.name(style: .abbreviation, language: .chinese), "SH")
        XCTAssertEqual(clock.name(style: .abbreviation, language: .english), "SH")
        clock.customName = "Home"
        XCTAssertEqual(clock.name(style: .custom, language: .chinese), "Home")
        XCTAssertEqual(clock.name(style: .custom, language: .english), "Home")
        clock.customName = "  "
        XCTAssertEqual(clock.name(style: .custom, language: .chinese), "上海")
        let la = WorldClock(timeZoneIdentifier: "America/Los_Angeles")
        XCTAssertEqual(la.name(style: .full, language: .chinese), "洛杉矶")
        XCTAssertEqual(la.name(style: .full, language: .english), "Los Angeles")
        XCTAssertEqual(la.name(style: .abbreviation, language: .english), "LOS")
        let paris = WorldClock(timeZoneIdentifier: "Europe/Paris")
        XCTAssertEqual(paris.name(style: .full, language: .chinese), "巴黎")
        XCTAssertEqual(paris.name(style: .full, language: .english), "Paris")
    }

    func testClockListShowsLocalDatesAcrossYearBoundary() {
        let shanghai = TimeZone(identifier: "Asia/Shanghai")!
        let la = TimeZone(identifier: "America/Los_Angeles")!
        let format = ClockListFormat()
        XCTAssertEqual(format.dateText(at: epoch, in: shanghai, language: .english), "01/01 Thu")
        XCTAssertEqual(format.timeText(at: epoch, in: shanghai, language: .english), "08:00")
        XCTAssertEqual(format.dateText(at: epoch, in: la, language: .chinese), "12/31 周三")
        XCTAssertEqual(format.timeText(at: epoch, in: la, language: .english), "16:00")
    }

    func testClockListRespectsFormatsAndDaylightSaving() {
        let la = TimeZone(identifier: "America/Los_Angeles")!
        let date = ISO8601DateFormatter().date(from: "2026-07-01T20:15:30Z")!
        var format = ClockListFormat()
        format.use24Hour = false
        format.showSeconds = true
        format.dateStyle = .iso
        XCTAssertEqual(format.dateText(at: date, in: la, language: .english), "2026-07-01 Wed")
        XCTAssertEqual(format.timeText(at: date, in: la, language: .english), "1:15:30 PM")
        format.dateStyle = .dayMonth
        format.showWeekday = false
        XCTAssertEqual(format.dateText(at: date, in: la, language: .english), "01/07")
    }

    @MainActor
    func testClockListSettingsPersistIndependentlyOfMenuBar() {
        let suite = "DualTimeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("UTC", forKey: "timeZoneIdentifier")
        let model = AppModel(defaults: defaults)
        XCTAssertEqual(model.worldClocks.map(\.timeZoneIdentifier), ["Asia/Shanghai", "America/Los_Angeles"])
        model.worldClocks.reverse()
        model.worldClocks[0].customName = "Office"
        model.clockListFormat.nameStyle = .custom
        model.clockListFormat.showSeconds = true
        let reloaded = AppModel(defaults: defaults)
        XCTAssertEqual(reloaded.worldClocks, model.worldClocks)
        XCTAssertEqual(reloaded.clockListFormat, model.clockListFormat)
        XCTAssertEqual(reloaded.timeZoneIdentifier, "UTC")
    }

    func testPointerExitDelaysAndImmediateClose() {
        for delay in PointerExitDelay.allCases where delay != .never {
            var countdown = PointerExitCountdown()
            let seconds = delay.seconds!
            XCTAssertEqual(countdown.shouldClose(pointerInside: false, at: 10, delay: delay), seconds == 0)
            if seconds > 0 {
                XCTAssertFalse(countdown.shouldClose(pointerInside: false, at: 10 + seconds - 0.01, delay: delay))
                XCTAssertTrue(countdown.shouldClose(pointerInside: false, at: 10 + seconds, delay: delay))
            }
        }
    }

    func testReturningToPanelCancelsAndRestartsPointerCountdown() {
        var countdown = PointerExitCountdown()
        XCTAssertFalse(countdown.shouldClose(pointerInside: false, at: 0, delay: .fiveSeconds))
        XCTAssertFalse(countdown.shouldClose(pointerInside: true, at: 4, delay: .fiveSeconds))
        XCTAssertFalse(countdown.shouldClose(pointerInside: false, at: 6, delay: .fiveSeconds))
        XCTAssertFalse(countdown.shouldClose(pointerInside: false, at: 10, delay: .fiveSeconds))
        XCTAssertTrue(countdown.shouldClose(pointerInside: false, at: 11, delay: .fiveSeconds))
    }

    func testNeverAndChangingDelayDiscardPreviousCountdown() {
        var countdown = PointerExitCountdown()
        XCTAssertFalse(countdown.shouldClose(pointerInside: false, at: 0, delay: .fiveSeconds))
        XCTAssertFalse(countdown.shouldClose(pointerInside: false, at: 100, delay: .never))
        XCTAssertFalse(countdown.shouldClose(pointerInside: false, at: 200, delay: .never))
        XCTAssertFalse(countdown.shouldClose(pointerInside: false, at: 201, delay: .halfSecond))
        XCTAssertTrue(countdown.shouldClose(pointerInside: false, at: 201.5, delay: .halfSecond))
        XCTAssertFalse(countdown.shouldClose(pointerInside: true, at: 202, delay: .immediately))
    }

    @MainActor
    func testBehaviorSettingsDefaultAndPersist() {
        let suite = "DualTimeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = AppModel(defaults: defaults)
        XCTAssertEqual(model.pointerExitDelay, .fiveSeconds)
        XCTAssertTrue(model.closeOnOutsideClick)
        for delay in PointerExitDelay.allCases {
            model.pointerExitDelay = delay
            XCTAssertEqual(AppModel(defaults: defaults).pointerExitDelay, delay)
        }
        model.closeOnOutsideClick = false
        XCTAssertFalse(AppModel(defaults: defaults).closeOnOutsideClick)
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
