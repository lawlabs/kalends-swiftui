import Foundation

extension Calendar {
    enum WeekdaySymbolStyle {
        /// “Mon”, “Tue”, …
        case short
        /// “M”, “T”, …
        case veryShort
    }

    /// Weekday labels in grid column order, i.e. starting at `firstWeekday`.
    /// `weeksInMonth(_:)` builds its grid from the same `firstWeekday`, so
    /// labels and columns always line up.
    func orderedWeekdaySymbols(_ style: WeekdaySymbolStyle, locale: Locale) -> [String] {
        var localized = self
        localized.locale = locale
        let symbols: [String]
        switch style {
        case .short:
            symbols = localized.shortStandaloneWeekdaySymbols
        case .veryShort:
            symbols = localized.veryShortStandaloneWeekdaySymbols
        }
        guard symbols.count == 7 else { return symbols }
        let firstIndex = max(0, min(6, firstWeekday - 1))
        return Array(symbols[firstIndex...] + symbols[..<firstIndex])
    }

    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? date
    }

    func startOfWeek(for date: Date) -> Date {
        self.date(from: dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)) ?? date
    }

    /// The seven days of the week containing `date`, starting at `firstWeekday`.
    func daysOfWeek(containing date: Date) -> [Date] {
        let weekStart = startOfWeek(for: date)
        return (0 ..< 7).compactMap { self.date(byAdding: .day, value: $0, to: weekStart) }
    }

    func daysInMonth(of date: Date) -> [Date] {
        let start = startOfMonth(for: date)
        guard let range = range(of: .day, in: .month, for: start) else { return [start] }
        return range.compactMap { self.date(byAdding: .day, value: $0 - 1, to: start) }
    }

    /// The month as rows of seven days starting at `firstWeekday`; `nil` pads
    /// the cells before the first and after the last day of the month.
    func weeksInMonth(of date: Date) -> [[Date?]] {
        let days = daysInMonth(of: date)
        var weeks: [[Date?]] = []
        var currentWeek: [Date?] = []

        if let firstDay = days.first {
            let weekday = component(.weekday, from: firstDay)
            let padding = (weekday - firstWeekday + 7) % 7
            currentWeek = Array(repeating: nil, count: padding)
        }

        for day in days {
            currentWeek.append(day)
            if currentWeek.count == 7 {
                weeks.append(currentWeek)
                currentWeek = []
            }
        }

        if !currentWeek.isEmpty {
            while currentWeek.count < 7 {
                currentWeek.append(nil)
            }
            weeks.append(currentWeek)
        }

        return weeks
    }

    /// The first days of the twelve months of the year containing `date`.
    func monthsInYear(of date: Date) -> [Date] {
        let year = component(.year, from: date)
        return (1 ... 12).compactMap { self.date(from: DateComponents(year: year, month: $0, day: 1)) }
    }

    /// Starts of the calendar days an event covers. `endDate` is exclusive, so
    /// an event ending exactly at midnight does not belong to the next day.
    func days<Event: KalendsEvent>(covering event: Event) -> [Date] {
        let firstDay = startOfDay(for: event.startDate)
        var lastDay = startOfDay(for: max(event.endDate, event.startDate))
        if lastDay > firstDay, event.endDate == lastDay {
            lastDay = date(byAdding: .day, value: -1, to: lastDay) ?? firstDay
        }

        var days: [Date] = [firstDay]
        var day = firstDay
        while day < lastDay, days.count < 3_660 {
            guard let next = date(byAdding: .day, value: 1, to: day) else { break }
            day = next
            days.append(day)
        }
        return days
    }
}

/// Locale-aware date strings used across the views.
enum DateText {
    static func time(_ date: Date, locale: Locale) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale))
    }

    /// “5”
    static func dayNumber(_ date: Date, locale: Locale) -> String {
        date.formatted(.dateTime.day().locale(locale))
    }

    /// “September 2026”
    static func monthYear(_ date: Date, locale: Locale) -> String {
        date.formatted(.dateTime.month(.wide).year().locale(locale)).capitalizedFirst
    }

    /// “September”
    static func month(_ date: Date, locale: Locale) -> String {
        date.formatted(.dateTime.month(.wide).locale(locale)).capitalizedFirst
    }

    /// “September 5”
    static func dayMonth(_ date: Date, locale: Locale) -> String {
        date.formatted(.dateTime.day().month(.wide).locale(locale))
    }

    /// “September 5, 2026”
    static func dayMonthYear(_ date: Date, locale: Locale) -> String {
        date.formatted(.dateTime.day().month(.wide).year().locale(locale))
    }

    /// “Saturday, September 5”
    static func weekdayDayMonth(_ date: Date, locale: Locale) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(locale))
    }

    /// “Sat”
    static func weekdayAbbreviated(_ date: Date, locale: Locale) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).locale(locale)).capitalizedFirst
    }

    /// “S”
    static func weekdayNarrow(_ date: Date, locale: Locale) -> String {
        date.formatted(.dateTime.weekday(.narrow).locale(locale))
    }

    /// “Saturday” / “суббота” — with the capitalization the locale uses.
    static func weekdayName(_ date: Date, locale: Locale) -> String {
        date.formatted(.dateTime.weekday(.wide).locale(locale))
    }

    /// “2026”
    static func year(_ date: Date, locale: Locale) -> String {
        date.formatted(.dateTime.year().locale(locale))
    }

    /// “09:00” — fixed-width hour labels of the time column.
    static func hourLabel(_ hour: Int) -> String {
        String(format: "%02d:00", hour)
    }
}

private extension String {
    var capitalizedFirst: String {
        guard let first = first else { return self }
        return first.uppercased() + dropFirst()
    }
}
