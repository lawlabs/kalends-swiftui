import SwiftUI

/// One day as a 24-hour timeline with an all-day section above it.
///
/// Events can be dragged and resized; double-tapping empty space creates an
/// event, dragging on empty space draws one. The timeline opens scrolled to
/// two hours before now on today and to 8:00 on other days.
public struct DayView<Source: KalendsDataSource>: View {
    private let source: Source
    @Binding private var selectedDate: Date
    private let selectedEventID: Source.Event.ID?
    private let style: DayViewStyle
    private let hourHeight: CGFloat
    private let actions: KalendsActions<Source.Event>

    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

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

    /// Like Apple Calendar: two hours before now on today, 8:00 otherwise.
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
                    actions: actions
                )

                ScrollViewReader { proxy in
                    ScrollView {
                        let columnWidth = max(0, geometry.size.width - timeColumnWidth)
                        ZStack(alignment: .topLeading) {
                            HStack(spacing: 0) {
                                HourLabelsColumn(hours: hours, hourHeight: hourHeight, trailingPadding: 8)
                                TimeGridLines(hourHeight: hourHeight, hourCount: hours.count, columnCount: 1)
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
                        .background(
                            VStack(spacing: 0) {
                                ForEach(hours, id: \.self) { hour in
                                    Color.clear
                                        .frame(height: hourHeight)
                                        .id("hour-\(hour)")
                                }
                            }
                        )
                    }
                    .onAppear {
                        let hour = initialScrollHour
                        Task { @MainActor in
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo("hour-\(hour)", anchor: .top)
                            }
                        }
                    }
                    // Changing the date keeps the scroll position: the user
                    // stays on the same hour, like Apple Calendar.
                }
            }
        }
    }

    private var dateHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(DateText.dayMonthYear(selectedDate, locale: locale))
                .font(.title)
                .fontWeight(.bold)

            Text(DateText.weekdayName(selectedDate, locale: locale))
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, resolvedStyle == .compact ? 10 : 12)
        .padding(.bottom, 12)
    }

    private var weekStrip: some View {
        HStack(spacing: 0) {
            ForEach(calendar.daysOfWeek(containing: selectedDate), id: \.self) { date in
                let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)

                Button {
                    selectedDate = date
                } label: {
                    VStack(spacing: 6) {
                        Text(DateText.weekdayNarrow(date, locale: locale))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(isSelected ? .red : .secondary)

                        Text(DateText.dayNumber(date, locale: locale))
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(isSelected ? .white : .primary)
                            .frame(width: 30, height: 30)
                            .background(
                                Circle()
                                    .fill(isSelected ? Color.red : Color.clear)
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
