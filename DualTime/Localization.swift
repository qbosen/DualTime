import Foundation

struct L10n {
    static var bundle: Bundle = .main

    static func string(_ key: String, locale: Locale) -> String {
        let localization = Bundle.preferredLocalizations(
            from: bundle.localizations,
            forPreferences: [locale.identifier]
        ).first
        let localizedBundle = localization
            .flatMap { bundle.path(forResource: $0, ofType: "lproj") }
            .flatMap(Bundle.init(path:))
            ?? bundle
        return localizedBundle.localizedString(forKey: key, value: nil, table: nil)
    }
}
