import AppKit
import Foundation

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
