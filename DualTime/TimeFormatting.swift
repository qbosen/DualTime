import Foundation

struct TimeFormatting {
    static func string(from date: Date, timeZone: TimeZone, language: AppLanguage) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = language == .english ? Locale(identifier: "en_US_POSIX") : Locale(identifier: "zh_CN")
        formatter.dateFormat = language == .english ? "EEE MMM d HH:mm" : "M月d日 EEE HH:mm"
        return formatter.string(from: date)
    }

    static func nextMinuteBoundary(after date: Date) -> Date {
        let seconds = date.timeIntervalSince1970
        let nextMinute = (floor(seconds / 60) + 1) * 60
        return Date(timeIntervalSince1970: nextMinute)
    }
}
