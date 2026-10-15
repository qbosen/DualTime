import AppKit
import Combine
import Foundation
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {
    @Published var timeZoneIdentifier: String {
        didSet { defaults.set(timeZoneIdentifier, forKey: Keys.timeZoneIdentifier); refresh() }
    }
    @Published var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: Keys.language); refresh() }
    }
    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin); updateLaunchAtLogin() }
    }
    @Published private(set) var currentDate = Date()
    @Published private(set) var loginItemError: String?

    private let defaults: UserDefaults
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []

    private enum Keys {
        static let timeZoneIdentifier = "timeZoneIdentifier"
        static let language = "language"
        static let launchAtLogin = "launchAtLogin"
        static let didCompleteOnboarding = "didCompleteOnboarding"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let systemIdentifier = TimeZone.current.identifier
        let storedIdentifier = defaults.string(forKey: Keys.timeZoneIdentifier) ?? systemIdentifier
        self.timeZoneIdentifier = TimeZone(identifier: storedIdentifier) == nil ? systemIdentifier : storedIdentifier
        if let rawLanguage = defaults.string(forKey: Keys.language), let storedLanguage = AppLanguage(rawValue: rawLanguage) {
            self.language = storedLanguage
        } else {
            self.language = Locale.current.language.languageCode?.identifier == "zh" ? .chinese : .english
        }
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
    }

    var timeZone: TimeZone { TimeZone(identifier: timeZoneIdentifier) ?? .current }

    var displayText: String {
        TimeFormatting.string(from: currentDate, timeZone: timeZone, language: language)
    }

    var timeZoneOptions: [TimeZoneOption] {
        let common = [
            TimeZone.current.identifier,
            "Asia/Shanghai",
            "Asia/Tokyo",
            "America/New_York",
            "America/Los_Angeles",
            "Europe/London",
            "UTC"
        ]
        var seen = Set<String>()
        let ordered = common + TimeZone.knownTimeZoneIdentifiers.sorted { localizedName(for: $0) < localizedName(for: $1) }
        return ordered.compactMap { identifier in
            guard seen.insert(identifier).inserted, TimeZone(identifier: identifier) != nil else { return nil }
            return TimeZoneOption(identifier: identifier, name: localizedName(for: identifier), offset: offsetName(for: identifier))
        }
    }

    func start() {
        refresh()
        scheduleNextMinute()
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refreshAndReschedule() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSNotification.Name.NSSystemClockDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refreshAndReschedule() }
        })
    }

    func stop() {
        timer?.invalidate()
        observers.forEach {
            NotificationCenter.default.removeObserver($0)
            NSWorkspace.shared.notificationCenter.removeObserver($0)
        }
        observers.removeAll()
    }

    func markOnboardingComplete() {
        defaults.set(true, forKey: Keys.didCompleteOnboarding)
    }

    var hasCompletedOnboarding: Bool {
        defaults.bool(forKey: Keys.didCompleteOnboarding)
    }

    private func refresh() { currentDate = Date() }

    private func refreshAndReschedule() {
        refresh()
        scheduleNextMinute()
    }

    private func scheduleNextMinute() {
        timer?.invalidate()
        let interval = max(0.1, TimeFormatting.nextMinuteBoundary(after: Date()).timeIntervalSinceNow)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.refreshAndReschedule()
            }
        }
    }

    private func localizedName(for identifier: String) -> String {
        let locale = language == .chinese ? Locale(identifier: "zh_CN") : Locale(identifier: "en_US")
        let components = identifier.split(separator: "/").map(String.init)
        let city = components.last?.replacingOccurrences(of: "_", with: " ") ?? identifier
        if let localized = locale.localizedString(forIdentifier: identifier), localized != identifier {
            return localized
        }
        return city
    }

    private func offsetName(for identifier: String) -> String {
        guard let zone = TimeZone(identifier: identifier) else { return "" }
        let seconds = zone.secondsFromGMT(for: currentDate)
        let sign = seconds >= 0 ? "+" : "-"
        let absolute = abs(seconds)
        return String(format: "UTC%@%02d:%02d", sign, absolute / 3600, (absolute % 3600) / 60)
    }

    private func updateLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginItemError = nil
        } catch {
            loginItemError = error.localizedDescription
        }
    }
}

struct TimeZoneOption: Identifiable, Hashable {
    let identifier: String
    let name: String
    let offset: String
    var id: String { identifier }
}
