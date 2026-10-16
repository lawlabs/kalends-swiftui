import XCTest
@testable import Kalends

@MainActor
final class DayInfoTests: XCTestCase {
    private let calendar = Calendar.testCalendar
    private let english = Locale(identifier: "en_US")
    private let russian = Locale(identifier: "ru_RU")

    func testWorkingTransferNeverReceivesNonWorkingHighlightAndKeepsBothMarkers() {
        let day = KalendsDayInfo(kind: .transferredWorking, isShortened: true)

        XCTAssertFalse(day.isNonWorking)
        XCTAssertFalse(day.shouldHighlight(weekends: true, holidays: true))
        XCTAssertEqual(day.marker(locale: english), "W −1h")
        XCTAssertEqual(day.marker(compact: true, locale: english), "W*")
        XCTAssertEqual(day.marker(locale: russian), "Р −1ч")
        XCTAssertEqual(day.marker(compact: true, locale: russian), "Р*")
    }

    func testHighlightSwitchesAreIndependentForEveryKindAndDoNotChangeStatus() {
        for kind in KalendsDayKind.allCases {
            let day = KalendsDayInfo(kind: kind)
            let isHoliday = kind == .holiday || kind == .transferredDayOff
            for weekends in [true, false] {
                for holidays in [true, false] {
                    XCTAssertEqual(day.shouldHighlight(weekends: weekends, holidays: holidays),
                                   (kind == .weekend && weekends) || (isHoliday && holidays))
                    XCTAssertEqual(day.isNonWorking, kind == .weekend || isHoliday)
                }
            }
        }
    }

    func testDisablingWorkingMarkersKeepsTransferredDaysOff() {
        XCTAssertEqual(KalendsDayInfo(kind: .transferredWorking, isShortened: true)
            .marker(workingDays: false, locale: english), "")
        XCTAssertEqual(KalendsDayInfo(kind: .transferredDayOff)
            .marker(workingDays: false, locale: english), "↔")
        XCTAssertEqual(KalendsDayInfo(kind: .holiday)
            .marker(weekends: true, holidays: false, locale: english), "")
    }

    func testShortenedStatusOnlyAppliesToWorkingDays() {
        for kind in [KalendsDayKind.weekend, .holiday, .transferredDayOff] {
            let day = KalendsDayInfo(kind: kind, isShortened: true)
            XCTAssertEqual(day.marker(weekends: false, holidays: false, locale: english), "")
            XCTAssertFalse(day.localizedDescription(locale: english).contains("Shortened"))
        }
        XCTAssertEqual(KalendsDayInfo(isShortened: true).marker(locale: english), "−1h")
        XCTAssertEqual(KalendsDayInfo(isShortened: true).marker(compact: true, locale: english), "*")
    }

    func testDescriptionsRemainAvailableWhenAllHighlightsAreOff() {
        let day = KalendsDayInfo(kind: .transferredWorking, isShortened: true)
        XCTAssertEqual(day.marker(weekends: false, holidays: false, workingDays: false, locale: english), "")
        XCTAssertEqual(day.localizedDescription(locale: english), "Working day due to a transfer · Shortened working day")
        XCTAssertEqual(day.localizedDescription(locale: russian), "Рабочий день по переносу · Сокращённый рабочий день")
        XCTAssertEqual(KalendsDayInfo(kind: .holiday, description: "Custom explanation")
            .localizedDescription(locale: russian), "Custom explanation")
        XCTAssertEqual(KalendsDayInfo(kind: .holiday, description: " \n ")
            .localizedDescription(locale: english), "Public holiday")
    }

    func testDefaultConfigurationClassifiesOnlySaturdayAndSundayAsWeekends() {
        let configuration = KalendsDayConfiguration()
        XCTAssertTrue(configuration.showWeekends)
        XCTAssertTrue(configuration.highlightWeekends)
        XCTAssertTrue(configuration.highlightHolidays)
        XCTAssertTrue(configuration.showWorkingDayMarkers)
        for offset in 0 ..< 7 {
            let day = calendar.date(byAdding: .day, value: offset, to: testDay(2026, 9, 14))!
            XCTAssertEqual(configuration.info(for: day, calendar: calendar).kind, offset >= 5 ? .weekend : .working)
        }
    }

    func testProviderOverridesSaturdayAndReceivesStartOfDayInViewTimeZone() {
        let saturday = testDay(2026, 9, 19)
        let lateSaturday = calendar.date(bySettingHour: 23, minute: 45, second: 0, of: saturday)!
        let configuration = KalendsDayConfiguration(dayInfoProvider: { day in
            XCTAssertEqual(day, saturday)
            return KalendsDayInfo(kind: .transferredWorking, isShortened: true)
        })

        let info = configuration.info(for: lateSaturday, calendar: calendar)
        XCTAssertEqual(info.kind, .transferredWorking)
        XCTAssertFalse(info.isNonWorking)
    }

    func testMissingProviderEntryFallsBackAndChangedDataIsNotCached() {
        let data = DayData()
        let configuration = KalendsDayConfiguration(dayInfoProvider: { _ in data.info })
        let date = testDay(2026, 9, 19)

        XCTAssertEqual(configuration.info(for: date, calendar: calendar).kind, .weekend)
        data.info = KalendsDayInfo(kind: .working)
        XCTAssertEqual(configuration.info(for: date, calendar: calendar).kind, .working)
        data.info = KalendsDayInfo(kind: .holiday)
        XCTAssertEqual(configuration.info(for: date, calendar: calendar).kind, .holiday)
        data.info = nil
        XCTAssertEqual(configuration.info(for: date, calendar: calendar).kind, .weekend)
    }

    func testVisibilityDoesNotDependOnHolidayOrTransferClassification() {
        let configuration = KalendsDayConfiguration(showWeekends: false, dayInfoProvider: { _ in
            KalendsDayInfo(kind: .holiday)
        })
        let days = calendar.visibleDaysOfWeek(containing: testDay(), showWeekends: configuration.showWeekends)
        XCTAssertEqual(days.count, 5)
        XCTAssertTrue(days.allSatisfy { configuration.info(for: $0, calendar: calendar).kind == .holiday })
    }
}

@MainActor
private final class DayData {
    var info: KalendsDayInfo?
}
