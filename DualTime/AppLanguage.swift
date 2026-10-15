import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case chinese = "zh"

    var id: String { rawValue }

    var locale: Locale {
        switch self {
        case .english: return Locale(identifier: "en")
        case .chinese: return Locale(identifier: "zh-Hans")
        }
    }

    var displayNameKey: LocalizedStringKey {
        switch self {
        case .english: return "language.english"
        case .chinese: return "language.chinese"
        }
    }
}
