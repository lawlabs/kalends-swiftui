import XCTest
@testable import Kalends

final class LocalizationTests: XCTestCase {
    /// English has no .lproj of its own; it must not fall back to the
    /// languages the process prefers (Russian on a Russian Mac).
    func testEnglishLocaleGetsEnglishWhateverTheProcessLanguage() {
        XCTAssertEqual(KalendsText.string("All day", locale: Locale(identifier: "en_US")), "All day")
        XCTAssertEqual(KalendsText.string("All day", locale: Locale(identifier: "ru_RU")), "Весь день")
    }

    func testLanguageWithoutTranslationGetsEnglish() {
        XCTAssertEqual(KalendsText.string("All day", locale: Locale(identifier: "de_DE")), "All day")
    }

    func testInterpolatedStringsKeepTheirArguments() {
        let day = "Friday, 16 October"
        let count = 3

        XCTAssertEqual(
            KalendsText.string("\(day), \(count) events", locale: Locale(identifier: "en_US")),
            "Friday, 16 October, 3 events"
        )
        XCTAssertEqual(
            KalendsText.string("\(day), \(count) events", locale: Locale(identifier: "ru_RU")),
            "Friday, 16 October, событий: 3"
        )
    }
}
