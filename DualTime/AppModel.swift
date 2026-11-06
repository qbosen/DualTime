import AppKit
import Combine
import Foundation
import ServiceManagement

enum PointerExitDelay: Double, CaseIterable, Identifiable {
    case immediately = 0
    case halfSecond = 0.5
    case oneSecond = 1
    case twoSeconds = 2
    case threeSeconds = 3
    case fiveSeconds = 5
    case never = -1

    var id: Double { rawValue }
    var seconds: TimeInterval? { self == .never ? nil : rawValue }
    var localizationKey: String {
        switch self {
        case .immediately: return "behavior.delay.immediately"
        case .halfSecond: return "behavior.delay.halfSecond"
        case .oneSecond: return "behavior.delay.oneSecond"
        case .twoSeconds: return "behavior.delay.twoSeconds"
        case .threeSeconds: return "behavior.delay.threeSeconds"
        case .fiveSeconds: return "behavior.delay.fiveSeconds"
        case .never: return "behavior.delay.never"
        }
    }
}

struct PointerExitCountdown {
    private var exitedAt: TimeInterval?
    private var previousDelay: PointerExitDelay?

    mutating func shouldClose(pointerInside: Bool, at now: TimeInterval, delay: PointerExitDelay) -> Bool {
        if previousDelay != delay {
            exitedAt = nil
            previousDelay = delay
        }
        guard !pointerInside, let seconds = delay.seconds else {
            exitedAt = nil
            return false
        }
        if exitedAt == nil { exitedAt = now }
        return now - (exitedAt ?? now) >= seconds
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var pointerExitDelay: PointerExitDelay {
        didSet { defaults.set(pointerExitDelay.rawValue, forKey: Keys.pointerExitDelay) }
    }
    @Published var closeOnOutsideClick: Bool {
        didSet { defaults.set(closeOnOutsideClick, forKey: Keys.closeOnOutsideClick) }
    }
    @Published var worldClocks: [WorldClock] {
        didSet { if let data = try? JSONEncoder().encode(worldClocks) { defaults.set(data, forKey: Keys.worldClocks) } }
    }
    @Published var clockListFormat: ClockListFormat {
        didSet { if let data = try? JSONEncoder().encode(clockListFormat) { defaults.set(data, forKey: Keys.clockListFormat) } }
    }
    @Published var timeZoneIdentifier: String {
        didSet { defaults.set(timeZoneIdentifier, forKey: Keys.timeZoneIdentifier); recalculateDisplayWidth(); refresh() }
    }
    @Published var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: Keys.language); recalculateDisplayWidth(); refresh() }
    }
    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin); updateLaunchAtLogin() }
    }
    @Published var showDate: Bool {
        didSet { defaults.set(showDate, forKey: Keys.showDate); recalculateDisplayWidth(); refreshAndReschedule() }
    }
    @Published var showWeekday: Bool {
        didSet { defaults.set(showWeekday, forKey: Keys.showWeekday); recalculateDisplayWidth(); refreshAndReschedule() }
    }
    @Published var flashTimeSeparators: Bool {
        didSet { defaults.set(flashTimeSeparators, forKey: Keys.flashTimeSeparators); recalculateDisplayWidth(); refreshAndReschedule() }
    }
    @Published var showSeconds: Bool {
        didSet { defaults.set(showSeconds, forKey: Keys.showSeconds); recalculateDisplayWidth(); refreshAndReschedule() }
    }
    @Published private(set) var currentDate = Date()
    @Published private(set) var displayWidth: CGFloat = 0
    @Published private(set) var loginItemError: String?

    private let defaults: UserDefaults
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var localizedZoneNames: [String: String] = [:]

    private enum Keys {
        static let pointerExitDelay = "pointerExitDelay"
        static let closeOnOutsideClick = "closeOnOutsideClick"
        static let worldClocks = "worldClocks"
        static let clockListFormat = "clockListFormat"
        static let timeZoneIdentifier = "timeZoneIdentifier"
        static let language = "language"
        static let launchAtLogin = "launchAtLogin"
        static let showDate = "showDate"
        static let showWeekday = "showWeekday"
        static let flashTimeSeparators = "flashTimeSeparators"
        static let showSeconds = "showSeconds"
        static let didCompleteOnboarding = "didCompleteOnboarding"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.pointerExitDelay = (defaults.object(forKey: Keys.pointerExitDelay) as? Double)
            .flatMap(PointerExitDelay.init(rawValue:)) ?? .fiveSeconds
        self.closeOnOutsideClick = defaults.object(forKey: Keys.closeOnOutsideClick) as? Bool ?? true
        let storedClocks = defaults.data(forKey: Keys.worldClocks)
            .flatMap { try? JSONDecoder().decode([WorldClock].self, from: $0) }?
            .filter { TimeZone(identifier: $0.timeZoneIdentifier) != nil } ?? [
                WorldClock(timeZoneIdentifier: "Asia/Shanghai"),
                WorldClock(timeZoneIdentifier: "America/Los_Angeles")
            ]
        self.worldClocks = storedClocks.isEmpty ? [WorldClock(timeZoneIdentifier: "Asia/Shanghai")] : storedClocks
        self.clockListFormat = defaults.data(forKey: Keys.clockListFormat)
            .flatMap { try? JSONDecoder().decode(ClockListFormat.self, from: $0) } ?? ClockListFormat()
        let systemIdentifier = TimeZone.current.identifier
        let storedIdentifier = defaults.string(forKey: Keys.timeZoneIdentifier) ?? systemIdentifier
        self.timeZoneIdentifier = TimeZone(identifier: storedIdentifier) == nil ? systemIdentifier : storedIdentifier
        if let rawLanguage = defaults.string(forKey: Keys.language), let storedLanguage = AppLanguage(rawValue: rawLanguage) {
            self.language = storedLanguage
        } else {
            self.language = Locale.current.language.languageCode?.identifier == "zh" ? .chinese : .english
        }
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        self.showDate = defaults.object(forKey: Keys.showDate) as? Bool ?? true
        self.showWeekday = defaults.object(forKey: Keys.showWeekday) as? Bool ?? true
        self.flashTimeSeparators = defaults.bool(forKey: Keys.flashTimeSeparators)
        self.showSeconds = defaults.bool(forKey: Keys.showSeconds)
        self.displayWidth = 0
        recalculateDisplayWidth()
    }

    var timeZone: TimeZone { TimeZone(identifier: timeZoneIdentifier) ?? .current }
    var locale: Locale { language.locale }

    var refreshInterval: TimeInterval {
        (showSeconds || flashTimeSeparators) ? 1 : 60
    }

    var separatorsVisible: Bool {
        !flashTimeSeparators || Int(currentDate.timeIntervalSince1970.rounded(.down)) % 2 == 0
    }

    var displayText: String {
        TimeFormatting.string(
            from: currentDate,
            timeZone: timeZone,
            language: language,
            showDate: showDate,
            showWeekday: showWeekday,
            showSeconds: showSeconds,
            separatorsVisible: separatorsVisible
        )
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
        scheduleNextRefresh()
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

    private func recalculateDisplayWidth() {
        displayWidth = TimeFormatting.maximumDisplayWidth(
            timeZone: timeZone,
            language: language,
            showDate: showDate,
            showWeekday: showWeekday,
            showSeconds: showSeconds,
            font: TimeFormatting.statusBarFont
        )
    }

    private func refreshAndReschedule() {
        refresh()
        scheduleNextRefresh()
    }

    private func scheduleNextRefresh() {
        timer?.invalidate()
        let now = Date()
        let next = refreshInterval == 1
            ? TimeFormatting.nextSecondBoundary(after: now)
            : TimeFormatting.nextMinuteBoundary(after: now)
        let interval = max(0.1, next.timeIntervalSinceNow)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.refreshAndReschedule()
            }
        }
    }

    private func localizedName(for identifier: String) -> String {
        let key = "\(language.rawValue):\(identifier)"
        if let name = localizedZoneNames[key] { return name }
        let name = WorldClock(timeZoneIdentifier: identifier).name(style: .full, language: language)
        localizedZoneNames[key] = name
        return name
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
