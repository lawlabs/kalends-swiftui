import XCTest
@testable import Kalends

final class DateHelpersTests: XCTestCase {
    private let calendar = Calendar.testCalendar

    func testWeeksInMonthReturnFullWeeksPaddedWithNil() {
        let weeks = calendar.weeksInMonth(of: testDay(2026, 2, 1))

        XCTAssertEqual(weeks.count, 5)
        XCTAssertTrue(weeks.allSatisfy { $0.count == 7 })
        // February 2026 starts on a Sunday: six empty cells before it in a Monday-first grid,
        // and the 28th (a Saturday) leaves one empty cell after it.
        XCTAssertEqual(weeks[0].prefix(6).compactMap { $0 }.count, 0)
        XCTAssertEqual(weeks[0][6], testDay(2026, 2, 1))
        XCTAssertEqual(weeks[4][5], testDay(2026, 2, 28))
        XCTAssertNil(weeks[4][6])
    }

    func testTimeHasTwoDigitHoursOnA24HourClock() {
        // DateText formats in the default time zone, so build the date there.
        let morning = Calendar.current.date(bySettingHour: 8, minute: 15, second: 0, of: Date())!

        XCTAssertEqual(DateText.time(morning, locale: Locale(identifier: "ru_RU")), "08:15")
        XCTAssertTrue(DateText.time(morning, locale: Locale(identifier: "en_US")).hasPrefix("8:15"))
    }

    func testDaysOfWeekStartAtFirstWeekday() {
        let days = calendar.daysOfWeek(containing: testDay(2026, 9, 19))

        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(days.first, testDay(2026, 9, 14))
        XCTAssertEqual(days.last, testDay(2026, 9, 20))

        var sundayFirst = calendar
        sundayFirst.firstWeekday = 1
        XCTAssertEqual(sundayFirst.daysOfWeek(containing: testDay(2026, 9, 19)).first, testDay(2026, 9, 13))
    }

    func testMonthsInYearAreTwelveFirstDays() {
        let months = calendar.monthsInYear(of: testDay(2026, 9, 19))

        XCTAssertEqual(months.count, 12)
        XCTAssertEqual(months.first, testDay(2026, 1, 1))
        XCTAssertEqual(months.last, testDay(2026, 12, 1))
    }

    func testHiddenWeekendColumnsKeepMonthDatesAndHeadersAlignedForEveryFirstWeekday() {
        for firstWeekday in 1 ... 7 {
            var custom = calendar
            custom.firstWeekday = firstWeekday
            let indices = custom.visibleWeekdayIndices(showWeekends: false)
            XCTAssertEqual(indices.count, 5)

            for year in [2024, 2026] {
                for month in 1 ... 12 {
                    let date = testDay(year, month, 1)
                    let weeks = custom.visibleWeeksInMonth(of: date, showWeekends: false)
                    XCTAssertTrue(weeks.allSatisfy { $0.count == 5 && $0.contains { $0 != nil } })
                    for week in weeks {
                        for (column, day) in week.enumerated() {
                            if let day {
                                let expectedWeekday = (firstWeekday - 1 + indices[column]) % 7 + 1
                                XCTAssertEqual(custom.component(.weekday, from: day), expectedWeekday)
                            }
                        }
                    }
                    let expected = custom.daysInMonth(of: date).filter {
                        let weekday = custom.component(.weekday, from: $0)
                        return weekday != 1 && weekday != 7
                    }
                    XCTAssertEqual(weeks.flatMap { $0 }.compactMap { $0 }, expected)
                    XCTAssertEqual(custom.visibleWeeksInMonth(of: date, showWeekends: true), custom.weeksInMonth(of: date))
                }
            }
        }
    }

    func testHorizontalDragFollowsVisibleColumnsAcrossHiddenWeekends() {
        var thursdayFirst = calendar
        thursdayFirst.firstWeekday = 5
        let friday = testDay(2026, 9, 18)
        let days = thursdayFirst.visibleDaysOfWeek(containing: friday, showWeekends: false)

        XCTAssertEqual(thursdayFirst.destinationDay(from: friday, columnOffset: 1, visibleDays: days), testDay(2026, 9, 21))
        XCTAssertEqual(thursdayFirst.destinationDay(from: testDay(2026, 9, 21), columnOffset: -1, visibleDays: days), friday)
        XCTAssertEqual(thursdayFirst.destinationDay(from: friday, columnOffset: 100, visibleDays: days), days.last)
        XCTAssertEqual(thursdayFirst.destinationDay(from: friday, columnOffset: -100, visibleDays: days), days.first)
        XCTAssertNil(thursdayFirst.destinationDay(from: friday, columnOffset: 1, visibleDays: []))
    }

    func testOrderedWeekdaySymbolsRespectMondayFirstRegion() {
        var monday = calendar
        monday.firstWeekday = 2

        XCTAssertEqual(
            monday.orderedWeekdaySymbols(.short, locale: Locale(identifier: "ru_RU")),
            ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
        )
        XCTAssertEqual(
            monday.orderedWeekdaySymbols(.short, locale: Locale(identifier: "en_US")),
            ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        )
    }

    func testOrderedWeekdaySymbolsRespectSundayFirstRegion() {
        var sunday = calendar
        sunday.firstWeekday = 1

        XCTAssertEqual(
            sunday.orderedWeekdaySymbols(.veryShort, locale: Locale(identifier: "ru_RU")),
            ["В", "П", "В", "С", "Ч", "П", "С"]
        )
    }

    func testOrderedWeekdaySymbolsMatchGridColumns() throws {
        let firstWeek = try XCTUnwrap(calendar.weeksInMonth(of: testDay(2026, 9, 1)).first)
        let firstRealDay = try XCTUnwrap(firstWeek.compactMap { $0 }.first)
        let column = try XCTUnwrap(firstWeek.firstIndex(of: firstRealDay))
        let weekdayIndex = calendar.component(.weekday, from: firstRealDay) - 1
        let locale = Locale(identifier: "en_US")
        var localized = calendar
        localized.locale = locale

        XCTAssertEqual(
            calendar.orderedWeekdaySymbols(.short, locale: locale)[column],
            localized.shortStandaloneWeekdaySymbols[weekdayIndex]
        )
    }

    func testDaysCoveringExclusiveMidnightEnd() {
        let day = testDay(2026, 9, 19)
        let untilMidnight = TestEvent(
            id: "m",
            title: "",
            startDate: calendar.date(bySettingHour: 22, minute: 0, second: 0, of: day)!,
            endDate: testDay(2026, 9, 20)
        )
        let overnight = TestEvent(
            id: "o",
            title: "",
            startDate: calendar.date(bySettingHour: 23, minute: 0, second: 0, of: day)!,
            endDate: calendar.date(bySettingHour: 1, minute: 0, second: 0, of: testDay(2026, 9, 20))!
        )

        XCTAssertEqual(calendar.days(covering: untilMidnight), [day])
        XCTAssertEqual(calendar.days(covering: overnight), [day, testDay(2026, 9, 20)])
    }

    func testDateTextFollowsLocale() {
        let date = calendar.date(bySettingHour: 9, minute: 5, second: 0, of: testDay(2026, 9, 5))!

        XCTAssertEqual(DateText.monthYear(date, locale: Locale(identifier: "en_US")), "September 2026")
        // ICU puts a non-breaking space before “г.”, so compare the prefix.
        XCTAssertTrue(DateText.monthYear(date, locale: Locale(identifier: "ru_RU")).hasPrefix("Сентябрь 2026"))
        XCTAssertEqual(DateText.dayMonth(date, locale: Locale(identifier: "ru_RU")), "5 сентября")
        XCTAssertEqual(DateText.weekdayAbbreviated(date, locale: Locale(identifier: "ru_RU")), "Сб")
        XCTAssertEqual(DateText.hourLabel(9), "09:00")
    }
}
