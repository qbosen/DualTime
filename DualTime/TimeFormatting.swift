import AppKit
import Foundation

import SwiftUI

struct WorldClock: Codable, Identifiable, Equatable {
    var id = UUID()
    var timeZoneIdentifier: String
    var customName = ""

    func name(style: ClockNameStyle, language: AppLanguage) -> String {
        let city = timeZoneIdentifier.split(separator: "/").last.map(String.init)?.replacingOccurrences(of: "_", with: " ") ?? timeZoneIdentifier
        let abbreviations = [
            "Asia/Shanghai": "SH",
            "America/Los_Angeles": "LOS",
            "Asia/Tokyo": "TYO",
            "America/New_York": "NYC",
            "Europe/London": "LON",
            "UTC": "UTC"
        ]
        if style == .custom, !customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return customName
        }
        if style == .abbreviation {
            if let abbreviation = abbreviations[timeZoneIdentifier] { return abbreviation }
            let words = city.split(separator: " ")
            return words.count == 1 ? String(city.prefix(3)).uppercased() : words.map { String($0.prefix(1)) }.joined().uppercased()
        }
        if timeZoneIdentifier == "UTC" { return language == .chinese ? "协调世界时" : "UTC" }
        guard let zone = TimeZone(identifier: timeZoneIdentifier) else { return city }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language == .chinese ? "zh_CN" : "en_US")
        formatter.timeZone = zone
        formatter.dateFormat = "VVV"
        return formatter.string(from: Date(timeIntervalSince1970: 0))
    }
}

enum ClockNameStyle: String, Codable, CaseIterable, Identifiable {
    case full, abbreviation, custom
    var id: String { rawValue }
    var label: LocalizedStringKey {
        switch self {
        case .full: return "clocks.name.full"
        case .abbreviation: return "clocks.name.abbreviation"
        case .custom: return "clocks.name.custom"
        }
    }
}

enum ClockDateStyle: String, Codable, CaseIterable, Identifiable {
    case monthDay, dayMonth, iso
    var id: String { rawValue }
    var label: String {
        switch self {
        case .monthDay: return "MM/DD"
        case .dayMonth: return "DD/MM"
        case .iso: return "YYYY-MM-DD"
        }
    }
    var pattern: String {
        switch self {
        case .monthDay: return "MM/dd"
        case .dayMonth: return "dd/MM"
        case .iso: return "yyyy-MM-dd"
        }
    }
}

struct ClockListFormat: Codable, Equatable {
    var nameStyle: ClockNameStyle = .full
    var dateStyle: ClockDateStyle = .monthDay
    var showWeekday = true
    var use24Hour = true
    var showSeconds = false

    func dateText(at date: Date, in zone: TimeZone, language: AppLanguage) -> String {
        format(date, in: zone, language: language, pattern: dateStyle.pattern + (showWeekday ? " EEE" : ""))
    }

    func timeText(at date: Date, in zone: TimeZone, language: AppLanguage) -> String {
        format(date, in: zone, language: language, pattern: (use24Hour ? "HH:mm" : "h:mm") + (showSeconds ? ":ss" : "") + (use24Hour ? "" : " a"))
    }

    private func format(_ date: Date, in zone: TimeZone, language: AppLanguage, pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language == .chinese ? "zh_CN" : "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = zone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}

struct TimeFormatting {
    static var statusBarFont: NSFont {
        let menuBarFont = NSFont.menuBarFont(ofSize: 0)
        return NSFont.monospacedDigitSystemFont(ofSize: menuBarFont.pointSize, weight: .regular)
    }

    static func string(
        from date: Date,
        timeZone: TimeZone,
        language: AppLanguage,
        showDate: Bool = true,
        showWeekday: Bool = true,
        showSeconds: Bool = false,
        separatorsVisible: Bool = true
    ) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = language == .english ? Locale(identifier: "en_US_POSIX") : Locale(identifier: "zh_CN")

        let hourMinuteSeparator = showSeconds ? ":" : (separatorsVisible ? ":" : " ")
        let minuteSecondSeparator = separatorsVisible ? ":" : " "
        let timeFormat = showSeconds
            ? "HH\(hourMinuteSeparator)mm\(minuteSecondSeparator)ss"
            : "HH\(hourMinuteSeparator)mm"
        let dateFormat: String
        if language == .english {
            let dateParts = [showWeekday ? "EEE" : nil, showDate ? "MMM d" : nil].compactMap { $0 }
            dateFormat = (dateParts + [timeFormat]).joined(separator: " ")
        } else {
            let dateParts = [showDate ? "M月d日" : nil, showWeekday ? "EEE" : nil].compactMap { $0 }
            dateFormat = (dateParts + [timeFormat]).joined(separator: " ")
        }

        formatter.dateFormat = dateFormat
        return formatter.string(from: date)
    }

    static func maximumDisplayWidth(
        timeZone: TimeZone,
        language: AppLanguage,
        showDate: Bool,
        showWeekday: Bool,
        showSeconds: Bool,
        font: NSFont = TimeFormatting.statusBarFont
    ) -> CGFloat {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var maximum: CGFloat = 0

        for month in 1...12 {
            for day in 1...31 {
                var components = DateComponents()
                components.year = 2024
                components.month = month
                components.day = day
                components.hour = 23
                components.minute = 59
                components.second = 59
                guard let date = calendar.date(from: components) else { continue }
                for separatorsVisible in [true, false] {
                    let string = self.string(
                        from: date,
                        timeZone: timeZone,
                        language: language,
                        showDate: showDate,
                        showWeekday: showWeekday,
                        showSeconds: showSeconds,
                        separatorsVisible: separatorsVisible
                    )
                    maximum = max(maximum, (string as NSString).size(withAttributes: [.font: font]).width)
                }
            }
        }

        return ceil(maximum + 8)
    }

    static func nextSecondBoundary(after date: Date) -> Date {
        let seconds = date.timeIntervalSince1970
        return Date(timeIntervalSince1970: (floor(seconds) + 1))
    }

    static func nextMinuteBoundary(after date: Date) -> Date {
        let seconds = date.timeIntervalSince1970
        let nextMinute = (floor(seconds / 60) + 1) * 60
        return Date(timeIntervalSince1970: nextMinute)
    }
}
