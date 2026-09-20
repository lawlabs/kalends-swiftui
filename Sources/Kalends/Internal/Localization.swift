import Foundation

/// User-facing strings, resolved against the locale from the SwiftUI
/// environment rather than the process language, so a host that pins
/// `\.locale` gets matching calendar text.
enum KalendsText {
    static func string(_ key: String.LocalizationValue, locale: Locale) -> String {
        String(localized: key, bundle: bundle(for: locale), locale: locale)
    }

    private static func bundle(for locale: Locale) -> Bundle {
        let candidates = [locale.identifier, locale.language.languageCode?.identifier].compactMap { $0 }
        for candidate in candidates {
            if let path = Bundle.module.path(forResource: candidate, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return .module
    }
}
