import SwiftUI

/// Twelve mini months of the year containing `selectedDate`.
///
/// Tapping a day selects it and, when it has events, lists them in a
/// popover; a double tap calls `openDay`. `.compact` puts the months under a
/// large year title, `.cards` frames each month on a card.
public struct YearView<Source: KalendsDataSource>: View {
    private let source: Source
    @Binding private var selectedDate: Date
    private let style: YearViewStyle
    private let actions: KalendsActions<Source.Event>

    public init(
        source: Source,
        selectedDate: Binding<Date>,
        style: YearViewStyle = .automatic,
        actions: KalendsActions<Source.Event> = KalendsActions()
    ) {
        self.source = source
        self._selectedDate = selectedDate
        self.style = style
        self.actions = actions
    }

    private var resolvedStyle: YearViewStyle {
        guard style == .automatic else { return style }
        #if os(macOS)
        return .cards
        #else
        return .compact
        #endif
    }

    public var body: some View {
        switch resolvedStyle {
        case .cards:
            CardsYearView(source: source, selectedDate: $selectedDate, actions: actions)
        case .compact, .automatic:
            CompactYearView(source: source, selectedDate: $selectedDate, actions: actions)
        }
    }
}

// MARK: - Compact

private struct CompactYearView<Source: KalendsDataSource>: View {
    let source: Source
    @Binding var selectedDate: Date
    let actions: KalendsActions<Source.Event>

    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 28, alignment: .top), count: 3)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(DateText.year(selectedDate, locale: locale))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.red)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                Divider()
                    .padding(.horizontal, 20)

                LazyVGrid(columns: columns, spacing: 30) {
                    ForEach(calendar.monthsInYear(of: selectedDate), id: \.self) { month in
                        CompactMiniMonth(
                            source: source,
                            month: month,
                            selectedDate: $selectedDate,
                            actions: actions
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
    }
}

private struct CompactMiniMonth<Source: KalendsDataSource>: View {
    let source: Source
    let month: Date
    @Binding var selectedDate: Date
    let actions: KalendsActions<Source.Event>

    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    private var isSelectedMonth: Bool {
        calendar.isDate(month, equalTo: selectedDate, toGranularity: .month)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(DateText.month(month, locale: locale))
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(isSelectedMonth ? .red : .primary)
                .padding(.bottom, 2)

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Array(calendar.orderedWeekdaySymbols(.veryShort, locale: locale).enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.65))
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Array(calendar.weeksInMonth(of: month).flatMap { $0 }.enumerated()), id: \.offset) { _, date in
                    if let date {
                        CompactMiniDayCell(
                            source: source,
                            date: date,
                            selectedDate: $selectedDate,
                            isCurrentMonth: calendar.isDate(date, equalTo: month, toGranularity: .month),
                            actions: actions
                        )
                    } else {
                        Text("")
                            .frame(width: 22, height: 26)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct CompactMiniDayCell<Source: KalendsDataSource>: View {
    let source: Source
    let date: Date
    @Binding var selectedDate: Date
    let isCurrentMonth: Bool
    let actions: KalendsActions<Source.Event>

    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar
    @State private var showingPopover = false

    private var isToday: Bool {
        calendar.isDateInToday(date)
    }

    private var isSelectedDay: Bool {
        calendar.isDate(date, equalTo: selectedDate, toGranularity: .day)
    }

    private var hasEvents: Bool {
        source.hasEvents(on: date)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(DateText.dayNumber(date, locale: locale))
                .font(.system(size: 11, weight: isToday ? .bold : .regular))
                .foregroundColor(dayForegroundColor)
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(isToday ? Color.red : Color.clear)
                )
                .padding(.top, 1)

            Circle()
                .fill(hasEvents ? eventIndicatorColor : Color.clear)
                .frame(width: 3.5, height: 3.5)
                .padding(.top, 2)
        }
        .frame(width: 22, height: 26, alignment: .top)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedDate = date
            actions.clearSelection()
            if hasEvents {
                showingPopover = true
            }
        }
        .popover(isPresented: $showingPopover, arrowEdge: .trailing) {
            DayEventsPopover(date: date, events: source.events(on: date), actions: actions)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(hasEvents
            ? KalendsText.string("\(DateText.weekdayDayMonth(date, locale: locale)), has events", locale: locale)
            : DateText.weekdayDayMonth(date, locale: locale))
        .accessibilityAddTraits(.isButton)
    }

    private var dayForegroundColor: Color {
        if isToday {
            return .white
        }
        if isSelectedDay {
            return .red
        }
        return isCurrentMonth ? .primary : .gray.opacity(0.45)
    }

    private var eventIndicatorColor: Color {
        if isToday {
            return .red
        }
        return isSelectedDay ? .red : .blue
    }
}

// MARK: - Cards

private struct CardsYearView<Source: KalendsDataSource>: View {
    let source: Source
    @Binding var selectedDate: Date
    let actions: KalendsActions<Source.Event>

    @Environment(\.calendar) private var calendar

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(calendar.monthsInYear(of: selectedDate), id: \.self) { month in
                    CardMiniMonth(
                        source: source,
                        month: month,
                        selectedDate: $selectedDate,
                        actions: actions
                    )
                }
            }
            .padding()
        }
    }
}

private struct CardMiniMonth<Source: KalendsDataSource>: View {
    let source: Source
    let month: Date
    @Binding var selectedDate: Date
    let actions: KalendsActions<Source.Event>

    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    var body: some View {
        VStack(spacing: 4) {
            Text(DateText.month(month, locale: locale))
                .font(.headline)
                .padding(.bottom, 4)

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Array(calendar.orderedWeekdaySymbols(.veryShort, locale: locale).enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Array(calendar.weeksInMonth(of: month).flatMap { $0 }.enumerated()), id: \.offset) { _, date in
                    if let date {
                        CardMiniDayCell(
                            date: date,
                            isToday: calendar.isDateInToday(date),
                            isCurrentMonth: calendar.isDate(date, equalTo: month, toGranularity: .month),
                            hasEvents: source.hasEvents(on: date),
                            onTap: {
                                selectedDate = date
                                actions.clearSelection()
                            },
                            onDoubleTap: {
                                selectedDate = date
                                actions.openDay(date)
                            },
                            popover: {
                                DayEventsPopover(date: date, events: source.events(on: date), actions: actions)
                            }
                        )
                    } else {
                        Text("")
                            .frame(width: 24, height: 24)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.kalendsControlBackground)
        .cornerRadius(8)
    }
}

/// A day on a year card. A click selects the day and lists its events, a
/// double click opens the day.
private struct CardMiniDayCell<Popover: View>: View {
    let date: Date
    let isToday: Bool
    let isCurrentMonth: Bool
    let hasEvents: Bool
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    @ViewBuilder let popover: () -> Popover

    @Environment(\.locale) private var locale
    @State private var showingPopover = false

    var body: some View {
        VStack(spacing: 2) {
            Text(DateText.dayNumber(date, locale: locale))
                .font(.system(size: 11))
                .fontWeight(isToday ? .bold : .regular)
                .foregroundColor(isToday ? .white : (isCurrentMonth ? .primary : .gray))
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(isToday ? Color.red : Color.clear)
                )

            Circle()
                .fill(hasEvents ? Color.blue : Color.clear)
                .frame(width: 4, height: 4)
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            showingPopover = false
            onDoubleTap()
        }
        .onTapGesture {
            onTap()
            if hasEvents {
                showingPopover = true
            }
        }
        .popover(isPresented: $showingPopover, arrowEdge: .trailing, content: popover)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(hasEvents
            ? KalendsText.string("\(DateText.weekdayDayMonth(date, locale: locale)), has events", locale: locale)
            : DateText.weekdayDayMonth(date, locale: locale))
        .accessibilityAddTraits(.isButton)
    }
}
