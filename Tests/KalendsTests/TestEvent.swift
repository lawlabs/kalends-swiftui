import Foundation
import SwiftUI
@testable import Kalends

/// The smallest possible ``KalendsEvent`` for tests.
struct TestEvent: KalendsEvent {
    let id: String
    var title: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool = false
    var color: Color = .blue
    var isReadOnly: Bool = false
    var subtitle: String? = nil
}

extension Calendar {
    static var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        calendar.timeZone = TimeZone(identifier: "Europe/Moscow")!
        calendar.firstWeekday = 2
        return calendar
    }
}

func testDay(_ year: Int = 2026, _ month: Int = 9, _ day: Int = 19, calendar: Calendar = .testCalendar) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day))!
}

func testEvent(
    _ id: String,
    day: Date,
    from start: (hour: Int, minute: Int),
    to end: (hour: Int, minute: Int),
    calendar: Calendar = .testCalendar
) -> TestEvent {
    TestEvent(
        id: id,
        title: id,
        startDate: calendar.date(bySettingHour: start.hour, minute: start.minute, second: 0, of: day)!,
        endDate: calendar.date(bySettingHour: end.hour, minute: end.minute, second: 0, of: day)!
    )
}
