import SwiftUI

/// Day columns on one 24-hour grid, with a pinned header of weekday
/// names and an all-day row when the week has all-day events.
///
/// Events can be dragged in time and across days, and resized. The week is
/// the one containing `selectedDate`, starting at the calendar's first weekday.
public struct WeekView<Source: KalendsDataSource>: View {
    private let source: Source
    @Binding private var selectedDate: Date
    private let selectedEventID: Source.Event.ID?
    private let hourHeight: CGFloat
    private let actions: KalendsActions<Source.Event>

    @Environment(\.calendar) private var calendar
    @Environment(\.kalendsDays) private var dayConfiguration

    private let hours = Array(0 ... 23)

    public init(
        source: Source,
        selectedDate: Binding<Date>,
        selectedEventID: Source.Event.ID? = nil,
        hourHeight: CGFloat = 60,
        actions: KalendsActions<Source.Event> = KalendsActions()
    ) {
        self.source = source
        self._selectedDate = selectedDate
        self.selectedEventID = selectedEventID
        self.hourHeight = hourHeight
        self.actions = actions
    }

    private var daysOfWeek: [Date] {
        calendar.visibleDaysOfWeek(containing: selectedDate, showWeekends: dayConfiguration.showWeekends)
    }

    private var hasAllDayEvents: Bool {
        daysOfWeek.contains { day in
            source.events(on: day).contains(where: \.isAllDay)
        }
    }

    /// Two hours before now when the week contains today, else 8:00.
    private var initialScrollHour: Int {
        if daysOfWeek.contains(where: { calendar.isDateInToday($0) }) {
            return max(0, calendar.component(.hour, from: Date()) - 2)
        }
        return 8
    }

    public var body: some View {
        // The header sits above the scroll view rather than as a pinned
        // section header inside it, so `scrollTo(hour)` lands exactly on
        // that hour instead of under the header.
        VStack(spacing: 0) {
            weekHeader

            ScrollViewReader { proxy in
                ScrollView {
                    WeekGrid(
                        source: source,
                        daysOfWeek: daysOfWeek,
                        hours: hours,
                        hourHeight: hourHeight,
                        selectedEventID: selectedEventID,
                        actions: actions
                    )
                    .background(
                        VStack(spacing: 0) {
                            ForEach(hours, id: \.self) { hour in
                                Color.clear
                                    .frame(height: hourHeight)
                                    .id("week-hour-\(hour)")
                            }
                        }
                    )
                }
                .onAppear {
                    let hour = initialScrollHour
                    Task { @MainActor in
                        proxy.scrollTo("week-hour-\(hour)", anchor: .top)
                    }
                }
            }
        }
    }

    private var weekHeader: some View {
        VStack(spacing: 0) {
            WeekHeader(daysOfWeek: daysOfWeek)

            if hasAllDayEvents {
                WeekAllDayRow(
                    source: source,
                    daysOfWeek: daysOfWeek,
                    selectedEventID: selectedEventID,
                    actions: actions
                )
            }

            Divider()
        }
        // Ideal height only: the all-day cells contain a greedy tap target
        // that would otherwise stretch the header down the window.
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.kalendsWindowBackground)
    }
}

// MARK: - Parts

/// Width of the hour column: 50 pt of label plus 4 pt of padding.
private let weekTimeColumnWidth: CGFloat = 54

private struct WeekHeader: View {
    let daysOfWeek: [Date]

    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar
    @Environment(\.kalendsDays) private var dayConfiguration

    var body: some View {
        HStack(spacing: 0) {
            Text("")
                .frame(width: 50)
                .padding(.trailing, 4)

            ForEach(daysOfWeek, id: \.self) { day in
                let isToday = calendar.isDateInToday(day)
                let presentation = dayConfiguration.presentation(for: day, calendar: calendar, locale: locale)
                VStack(spacing: 4) {
                    Text(DateText.weekdayAbbreviated(day, locale: locale))
                        .font(.caption)
                        .foregroundColor(presentation.foreground)

                    Text(DateText.dayNumber(day, locale: locale))
                        .font(.headline)
                        .foregroundColor(isToday ? .red : presentation.foreground)
                        .padding(4)
                        .background(
                            Circle()
                                .fill(isToday ? Color.red.opacity(0.1) : Color.clear)
                        )

                    DayMarker(date: day)
                        .frame(height: 12)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(presentation.background)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(DateText.weekdayDayMonth(day, locale: locale))
                .kalendsDayDetails(day)
            }
        }
    }
}

private struct WeekAllDayRow<Source: KalendsDataSource>: View {
    let source: Source
    let daysOfWeek: [Date]
    let selectedEventID: Source.Event.ID?
    let actions: KalendsActions<Source.Event>

    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: 0) {
            Text(KalendsText.string("all-day", locale: locale))
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 50, alignment: .trailing)
                .padding(.trailing, 4)

            ForEach(daysOfWeek, id: \.self) { day in
                let allDayEvents = source.events(on: day).filter(\.isAllDay)

                ZStack {
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            actions.clearSelection()
                        }

                    VStack(spacing: 2) {
                        ForEach(allDayEvents) { event in
                            WeekAllDayEventCell(event: event, isSelected: selectedEventID == event.id)
                                .padding(.horizontal, 2)
                                .onTapGesture {
                                    actions.selectEvent(event)
                                }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(DayBackground(date: day))
                .clipped()
            }
        }
    }
}

private struct WeekAllDayEventCell<Event: KalendsEvent>: View {
    let event: Event
    let isSelected: Bool

    @Environment(\.colorScheme) private var colorScheme

    private var textColor: Color {
        event.color.eventTextColor(isSelected: isSelected, colorScheme: colorScheme)
    }

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 1)
                .fill(event.color)
                .frame(width: 3)

            Text(event.title)
                .font(.system(size: 10))
                .fontWeight(.medium)
                .foregroundColor(textColor)
                .lineLimit(1)
                .padding(.horizontal, 3)

            Spacer(minLength: 0)
        }
        .frame(height: 18)
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(event.color.opacity(isSelected ? 0.5 : 0.2))
        )
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .stroke(event.color.opacity(isSelected ? 0.6 : 0), lineWidth: 1)
        )
    }
}

private struct WeekGrid<Source: KalendsDataSource>: View {
    let source: Source
    let daysOfWeek: [Date]
    let hours: [Int]
    let hourHeight: CGFloat
    let selectedEventID: Source.Event.ID?
    let actions: KalendsActions<Source.Event>

    @Environment(\.calendar) private var calendar

    private var totalHeight: CGFloat { CGFloat(hours.count) * hourHeight }

    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                HourLabelsColumn(hours: hours, hourHeight: hourHeight, trailingPadding: 4)
                TimeGridLines(hourHeight: hourHeight, hourCount: hours.count, columnCount: daysOfWeek.count)
                    .background {
                        HStack(spacing: 0) {
                            ForEach(daysOfWeek, id: \.self) { day in
                                DayBackground(date: day)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
            }

            HStack(spacing: 0) {
                Spacer().frame(width: weekTimeColumnWidth)

                ForEach(daysOfWeek, id: \.self) { day in
                    WeekDayColumn(
                        source: source,
                        day: day,
                        hours: hours,
                        hourHeight: hourHeight,
                        totalHeight: totalHeight,
                        selectedEventID: selectedEventID,
                        actions: actions,
                        visibleDays: daysOfWeek
                    )
                }
            }
            .frame(height: totalHeight)

            if daysOfWeek.contains(where: { calendar.isDateInToday($0) }) {
                CurrentTimeIndicator(hourHeight: hourHeight)
            }
        }
        .frame(minHeight: totalHeight)
    }
}

private struct WeekDayColumn<Source: KalendsDataSource>: View {
    let source: Source
    let day: Date
    let hours: [Int]
    let hourHeight: CGFloat
    /// Fixed height so the column never re-lays out while dragging.
    let totalHeight: CGFloat
    let selectedEventID: Source.Event.ID?
    let actions: KalendsActions<Source.Event>
    let visibleDays: [Date]

    var body: some View {
        GeometryReader { geometry in
            let dayWidth = geometry.size.width

            ZStack(alignment: .topLeading) {
                Color.clear

                TimeGridCreationOverlay(
                    day: day,
                    hourHeight: hourHeight,
                    hourCount: hours.count,
                    actions: actions
                )

                DayColumnEvents(
                    source: source,
                    day: day,
                    hourHeight: hourHeight,
                    containerWidth: dayWidth,
                    dayWidth: dayWidth,
                    style: .week,
                    selectedEventID: selectedEventID,
                    actions: actions,
                    visibleDays: visibleDays
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: totalHeight)
        // No clipping: events may cross the column edge while being dragged.
    }
}
