import Foundation

struct TimeFormatting {
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

        let separator = separatorsVisible ? ":" : " "
        let timeFormat = showSeconds ? "HH\(separator)mm\(separator)ss" : "HH\(separator)mm"
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
