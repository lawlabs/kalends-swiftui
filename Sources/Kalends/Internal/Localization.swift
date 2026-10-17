import Foundation

/// User-facing strings, resolved against the locale from the SwiftUI
/// environment rather than the process language, so a host that pins
/// `\.locale` gets matching calendar text.
enum KalendsText {
    static func string(_ key: String.LocalizationValue, locale: Locale) -> String {
        guard let bundle = translationBundle(for: locale) else {
            // English is the source language and has no .lproj of its own.
            // Looking in a table that does not exist misses in every
            // localization, so the key itself — the English text — comes
            // back, whatever languages the process prefers.
            return String(localized: key, table: "KalendsSourceText", bundle: .module, locale: locale)
        }
        return String(localized: key, bundle: bundle, locale: locale)
    }

    private static func translationBundle(for locale: Locale) -> Bundle? {
        let candidates = [locale.identifier, locale.language.languageCode?.identifier].compactMap { $0 }
        for candidate in candidates {
            if let path = Bundle.module.path(forResource: candidate, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return nil
    }
}
