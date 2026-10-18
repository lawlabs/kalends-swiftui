import SwiftUI

/// One day as a 24-hour timeline with an all-day section above it.
///
/// Events can be dragged and resized; double-tapping empty space creates an
/// event, dragging on empty space draws one. The timeline first opens
/// scrolled to two hours before now on today and to 8:00 on other days, and
/// then keeps the hour the user scrolled to; inside ``KalendsView`` that
/// hour is shared with the week view.
public struct DayView<Source: KalendsDataSource>: View {
    private let source: Source
    @Binding private var selectedDate: Date
    private let selectedEventID: Source.Event.ID?
    private let style: DayViewStyle
    private let hourHeight: CGFloat
    private let actions: KalendsActions<Source.Event>

    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar
    @Environment(\.kalendsDays) private var dayConfiguration

    private let hours = Array(0 ... 23)
    private let timeColumnWidth: CGFloat = 58

    /// - Parameters:
    ///   - source: Supplies the day's events.
    ///   - selectedDate: The day shown; the week strip of the `.compact` style changes it.
    ///   - selectedEventID: The event drawn as selected, if any.
    ///   - style: `.compact` adds a week strip; `.automatic` picks by platform.
    ///   - hourHeight: Height of one hour in points.
    ///   - actions: Callbacks for selection, rescheduling and creation.
    public init(
        source: Source,
        selectedDate: Binding<Date>,
        selectedEventID: Source.Event.ID? = nil,
        style: DayViewStyle = .automatic,
        hourHeight: CGFloat = 60,
        actions: KalendsActions<Source.Event> = KalendsActions()
    ) {
        self.source = source
        self._selectedDate = selectedDate
        self.selectedEventID = selectedEventID
        self.style = style
        self.hourHeight = hourHeight
        self.actions = actions
    }

    private var resolvedStyle: DayViewStyle {
        guard style == .automatic else { return style }
        #if os(macOS)
        return .regular
        #else
        return .compact
        #endif
    }

    private var isToday: Bool {
        calendar.isDateInToday(selectedDate)
    }

    /// Where the timeline opens before the user has scrolled it, like Apple
    /// Calendar: two hours before now on today, 8:00 otherwise.
    private var initialScrollHour: Int {
        if isToday {
            return max(0, calendar.component(.hour, from: Date()) - 2)
        }
        return 8
    }

    public var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if resolvedStyle == .compact {
                    weekStrip
                }
                dateHeader

                AllDaySection(
                    source: source,
                    day: selectedDate,
                    selectedEventID: selectedEventID,
                    actions: actions,
                    timeColumnWidth: timeColumnWidth
                )

                ScrollView {
                    let columnWidth = max(0, geometry.size.width - timeColumnWidth)
                    ZStack(alignment: .topLeading) {
                        HStack(spacing: 0) {
                            HourLabelsColumn(hours: hours, hourHeight: hourHeight, trailingPadding: 8)
                            TimeGridLines(hourHeight: hourHeight, hourCount: hours.count, columnCount: 1)
                                .background(DayBackground(date: selectedDate))
                        }

                        TimeGridCreationOverlay(
                            day: selectedDate,
                            hourHeight: hourHeight,
                            hourCount: hours.count,
                            actions: actions
                        )
                        .frame(width: columnWidth, height: CGFloat(hours.count) * hourHeight)
                        .offset(x: timeColumnWidth)

                        ZStack(alignment: .topLeading) {
                            DayColumnEvents(
                                source: source,
                                day: selectedDate,
                                hourHeight: hourHeight,
                                containerWidth: columnWidth,
                                dayWidth: nil,
                                style: .day,
                                selectedEventID: selectedEventID,
                                actions: actions
                            )
                        }
                        .padding(.leading, timeColumnWidth)

                        if isToday {
                            CurrentTimeIndicator(hourHeight: hourHeight)
                        }
                    }
                    .frame(minHeight: CGFloat(hours.count) * hourHeight)
                }
                // Changing the date, or switching to another mode and back,
                // keeps the hour the user scrolled to, like Apple Calendar.
                .timelineScroll(hourHeight: hourHeight) { initialScrollHour }
            }
        }
    }

    private var dateHeader: some View {
        let presentation = dayConfiguration.presentation(for: selectedDate, calendar: calendar, locale: locale)
        return VStack(alignment: .leading, spacing: 2) {
            Text(DateText.dayMonthYear(selectedDate, locale: locale))
                .font(.title)
                .fontWeight(.bold)

            HStack {
                Text(DateText.weekdayName(selectedDate, locale: locale))
                    .font(.title3)
                    .foregroundColor(presentation.foreground)
                DayMarker(date: selectedDate)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, resolvedStyle == .compact ? 10 : 12)
        .padding(.bottom, 12)
        .background(presentation.background)
        .accessibilityElement(children: .combine)
        .kalendsDayDetails(selectedDate)
    }

    private var weekStrip: some View {
        HStack(spacing: 0) {
            ForEach(calendar.visibleDaysOfWeek(containing: selectedDate, showWeekends: dayConfiguration.showWeekends), id: \.self) { date in
                let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                let presentation = dayConfiguration.presentation(for: date, calendar: calendar, locale: locale)

                Button {
                    selectedDate = date
                } label: {
                    VStack(spacing: 6) {
                        Text(DateText.weekdayNarrow(date, locale: locale))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(isSelected ? .red : presentation.foreground)

                        Text(DateText.dayNumber(date, locale: locale))
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(isSelected ? .white : presentation.foreground)
                            .frame(width: 30, height: 30)
                            .background(
                                Circle()
                                    .fill(isSelected ? Color.red : Color.clear)
                            )

                        DayMarker(date: date, compact: true)
                            .frame(height: 9)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(presentation.background)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(DateText.weekdayDayMonth(date, locale: locale))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .kalendsDayDetails(date)
            }
        }
        .padding(.horizontal, 8)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
