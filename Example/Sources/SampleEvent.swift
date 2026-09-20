import Kalends
import SwiftUI

/// The sample's own event type: everything ``KalendsEvent`` asks for and
/// nothing else. A real app would map its records to something like this.
struct SampleEvent: KalendsEvent {
    let id: UUID
    var title: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var color: Color
    var isReadOnly: Bool
    var subtitle: String?

    init(
        id: UUID = UUID(),
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        color: Color = SampleEvents.work,
        isReadOnly: Bool = false,
        subtitle: String? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.color = color
        self.isReadOnly = isReadOnly
        self.subtitle = subtitle
    }
}

/// The same week of events as the Kalends.WinUI sample, so the two
/// libraries can be compared side by side.
enum SampleEvents {
    static let work = Color(red: 101 / 255, green: 81 / 255, blue: 143 / 255)
    static let meetings = Color(red: 56 / 255, green: 109 / 255, blue: 174 / 255)
    static let personal = Color(red: 53 / 255, green: 118 / 255, blue: 93 / 255)
    static let important = Color(red: 151 / 255, green: 102 / 255, blue: 30 / 255)

    @MainActor
    static func makeStore(around date: Date = Date(), calendar: Calendar = .current) -> KalendsEventStore<SampleEvent> {
        KalendsEventStore(events: events(around: date, calendar: calendar), calendar: calendar)
    }

    /// The week containing `date`, Monday to Sunday, plus a few events in the
    /// weeks around it so the month and year views are not empty.
    static func events(around date: Date, calendar: Calendar) -> [SampleEvent] {
        var mondayFirst = calendar
        mondayFirst.firstWeekday = 2
        let week = mondayFirst.date(
            from: mondayFirst.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        ) ?? calendar.startOfDay(for: date)

        func day(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: week) ?? week
        }
        func at(_ offset: Int, _ hour: Double) -> Date {
            day(offset).addingTimeInterval(hour * 3600)
        }

        var events: [SampleEvent] = []
        func add(_ offset: Int, _ hour: Double, _ duration: Double, _ title: String, _ color: Color, _ subtitle: String? = nil, readOnly: Bool = false) {
            events.append(SampleEvent(
                title: title,
                startDate: at(offset, hour),
                endDate: at(offset, hour + duration),
                color: color,
                isReadOnly: readOnly,
                subtitle: subtitle
            ))
        }

        add(0, 9, 1, "Weekly planning", work, "Office")
        add(0, 11, 1.5, "Deep work", work)
        add(0, 14, 1, "Team sync", meetings, "Online")
        add(0, 17, 1, "Training", personal)
        add(1, 9.5, 1.5, "Draft documents", work)
        add(1, 12, 1, "Lunch", personal)
        add(1, 14, 2, "Project review", meetings)
        add(2, 9, 1, "Focus block", work)
        add(2, 10.5, 1.5, "Consultation", meetings, "Online")
        add(2, 15, 1.5, "Research", work)
        add(3, 9, 2, "No-meeting morning", work)
        add(3, 12, 1, "Client meeting", meetings)
        add(3, 15, 1, "Walk", personal)
        add(4, 9.5, 1, "Weekly review", work)
        add(4, 11, 1.5, "Presentation", meetings, "Online")
        add(4, 17, 1.5, "Friends", personal)
        add(3, 11, 1.5, "Court hearing", important, "Courtroom 412", readOnly: true)

        events.append(SampleEvent(title: "Project due", startDate: day(4), endDate: day(5), isAllDay: true, color: important))
        events.append(SampleEvent(title: "Design days", startDate: day(1), endDate: day(3), isAllDay: true, color: meetings))

        // Neighbouring weeks, so month and year views have something to show.
        for weekOffset in [-3, -2, -1, 1, 2, 3] {
            let base = weekOffset * 7
            add(base + 0, 9, 1, "Weekly planning", work, "Office")
            add(base + 1, 12, 1, "Lunch", personal)
            add(base + 2, 10.5, 1.5, "Consultation", meetings, "Online")
            add(base + 3, 15, 1, "Walk", personal)
            add(base + 4, 11, 1.5, "Presentation", meetings)
            if weekOffset.isMultiple(of: 2) {
                events.append(SampleEvent(title: "Filing deadline", startDate: day(base + 2), endDate: day(base + 3), isAllDay: true, color: important))
            }
        }

        return events
    }
}
