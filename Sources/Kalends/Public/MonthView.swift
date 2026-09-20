import SwiftUI

/// A vertically scrolling run of months with a pinned weekday header.
///
/// `.compact` cells show a colored bar per event; `.detailed` cells list
/// event titles and offer a “more” popover, and a double tap on a day calls
/// `openDay`. Tapping a day makes it `selectedDate`.
public struct MonthView<Source: KalendsDataSource>: View {
    private let source: Source
    @Binding private var selectedDate: Date
    private let selectedEventID: Source.Event.ID?
    private let style: MonthViewStyle
    private let actions: KalendsActions<Source.Event>

    public init(
        source: Source,
        selectedDate: Binding<Date>,
        selectedEventID: Source.Event.ID? = nil,
        style: MonthViewStyle = .automatic,
        actions: KalendsActions<Source.Event> = KalendsActions()
    ) {
        self.source = source
        self._selectedDate = selectedDate
        self.selectedEventID = selectedEventID
        self.style = style
        self.actions = actions
    }

    private var resolvedStyle: MonthViewStyle {
        guard style == .automatic else { return style }
        #if os(macOS)
        return .detailed
        #else
        return .compact
        #endif
    }

    public var body: some View {
        switch resolvedStyle {
        case .detailed:
            DetailedMonthView(
                source: source,
                selectedDate: $selectedDate,
                selectedEventID: selectedEventID,
                actions: actions
            )
        case .compact, .automatic:
            CompactMonthView(
                source: source,
                selectedDate: $selectedDate,
                actions: actions
            )
        }
    }
}

// MARK: - Shared parts

/// Weekday names above a month grid.
struct WeekdayHeaderRow: View {
    let style: Calendar.WeekdaySymbolStyle
    let font: Font
    let color: Color
    let verticalPadding: CGFloat
    let horizontalPadding: CGFloat

    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(Array(calendar.orderedWeekdaySymbols(style, locale: locale).enumerated()), id: \.offset) { _, day in
                Text(day)
                    .font(font)
                    .fontWeight(.medium)
                    .foregroundColor(color)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, verticalPadding)
            }
        }
        .padding(.horizontal, horizontalPadding)
    }
}

func monthScrollID(for date: Date, calendar: Calendar) -> String {
    let components = calendar.dateComponents([.year, .month], from: date)
    return "month-\(components.year ?? 0)-\(components.month ?? 0)"
}

// MARK: - Compact

private struct CompactMonthView<Source: KalendsDataSource>: View {
    let source: Source
    @Binding var selectedDate: Date
    let actions: KalendsActions<Source.Event>

    @Environment(\.calendar) private var calendar

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    /// Months around an anchor fixed on first appearance; the range only
    /// grows at the edges so the content above the scroll position never
    /// moves. See `DetailedMonthView`.
    @State private var anchorMonth: Date?
    @State private var monthOffsets: ClosedRange<Int> = -24 ... 24
    private static var edgeMargin: Int { 6 }

    private var resolvedAnchor: Date {
        anchorMonth ?? calendar.startOfMonth(for: selectedDate)
    }

    private var allMonths: [Date] {
        monthOffsets.compactMap { calendar.date(byAdding: .month, value: $0, to: resolvedAnchor) }
    }

    var body: some View {
        VStack(spacing: 0) {
            WeekdayHeaderRow(
                style: .veryShort,
                font: .system(size: 13, weight: .medium),
                color: .secondary.opacity(0.85),
                verticalPadding: 9,
                horizontalPadding: 8
            )

            Divider()

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(allMonths, id: \.self) { month in
                            CompactMonthSection(
                                source: source,
                                month: month,
                                selectedDate: $selectedDate,
                                columns: columns,
                                actions: actions
                            )
                            .id(monthScrollID(for: month, calendar: calendar))
                        }
                    }
                }
                .onAppear {
                    if anchorMonth == nil {
                        anchorMonth = calendar.startOfMonth(for: selectedDate)
                    }
                    let target = monthScrollID(for: selectedDate, calendar: calendar)
                    Task { @MainActor in
                        proxy.scrollTo(target, anchor: .top)
                    }
                }
                .onChange(of: selectedDate) { oldDate, newDate in
                    let newMonth = calendar.startOfMonth(for: newDate)
                    guard newMonth != calendar.startOfMonth(for: oldDate) else { return }
                    extendRangeIfNeeded(for: newMonth)
                    let target = monthScrollID(for: newMonth, calendar: calendar)
                    Task { @MainActor in
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(target, anchor: .top)
                        }
                    }
                }
            }
        }
    }

    private func extendRangeIfNeeded(for month: Date) {
        let offset = calendar.dateComponents([.month], from: resolvedAnchor, to: month).month ?? 0
        if offset - Self.edgeMargin < monthOffsets.lowerBound {
            monthOffsets = (offset - 24) ... monthOffsets.upperBound
        } else if offset + Self.edgeMargin > monthOffsets.upperBound {
            monthOffsets = monthOffsets.lowerBound ... (offset + 24)
        }
    }
}

private struct CompactMonthSection<Source: KalendsDataSource>: View {
    let source: Source
    let month: Date
    @Binding var selectedDate: Date
    let columns: [GridItem]
    let actions: KalendsActions<Source.Event>

    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    private var monthTitle: String {
        if calendar.isDate(month, equalTo: selectedDate, toGranularity: .year) {
            return DateText.month(month, locale: locale)
        }
        return DateText.monthYear(month, locale: locale)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(monthTitle)
                    .font(.system(size: 25, weight: .bold))
                    .padding(.leading, 12)
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                Spacer()
            }
            .padding(.horizontal, 4)

            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(Array(calendar.weeksInMonth(of: month).enumerated()), id: \.offset) { _, week in
                    ForEach(Array(week.enumerated()), id: \.offset) { _, date in
                        if let date {
                            CompactMonthDayCell(
                                date: date,
                                events: source.events(on: date),
                                isCurrentMonth: calendar.isDate(date, equalTo: month, toGranularity: .month),
                                isToday: calendar.isDateInToday(date),
                                isSelected: calendar.isDate(date, equalTo: selectedDate, toGranularity: .day),
                                onDayTap: {
                                    selectedDate = date
                                    actions.clearSelection()
                                }
                            )
                            .frame(height: 102)
                        } else {
                            Color.clear
                                .frame(height: 102)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
        }
    }
}

private struct CompactMonthDayCell<Event: KalendsEvent>: View {
    let date: Date
    let events: [Event]
    let isCurrentMonth: Bool
    let isToday: Bool
    let isSelected: Bool
    let onDayTap: () -> Void

    @Environment(\.locale) private var locale

    private static var maxVisibleIndicators: Int { 3 }

    private var sortedEvents: [Event] {
        events.sorted {
            if $0.isAllDay != $1.isAllDay {
                return $0.isAllDay && !$1.isAllDay
            }
            return $0.startDate < $1.startDate
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(DateText.dayNumber(date, locale: locale))
                    .font(.system(size: 16, weight: isToday ? .bold : .regular))
                    .foregroundColor(
                        isToday ? .white :
                            isCurrentMonth ? .primary : .gray.opacity(0.45)
                    )
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(dayBadgeBackground)
                    )
                    .padding(.top, 5)
                    .padding(.leading, 5)

                Spacer()
            }

            Spacer(minLength: 8)

            VStack(alignment: .leading, spacing: 5) {
                ForEach(sortedEvents.prefix(Self.maxVisibleIndicators)) { event in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(event.color.opacity(event.isAllDay ? 0.9 : 0.72))
                        .frame(height: event.isAllDay ? 5 : 4)
                }

                if events.count > Self.maxVisibleIndicators {
                    HStack(spacing: 2.5) {
                        ForEach(0 ..< 3, id: \.self) { _ in
                            Circle()
                                .fill(Color.secondary.opacity(0.38))
                                .frame(width: 2.5, height: 2.5)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 7)
            .padding(.bottom, 9)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onDayTap()
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.gray.opacity(0.08))
                .frame(height: 0.5)
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.gray.opacity(0.05))
                .frame(width: 0.5)
        }
    }

    private var dayBadgeBackground: Color {
        if isToday {
            return .red
        }
        if isSelected {
            return Color.primary.opacity(0.06)
        }
        return .clear
    }
}

// MARK: - Detailed

private struct DetailedMonthView<Source: KalendsDataSource>: View {
    let source: Source
    @Binding var selectedDate: Date
    let selectedEventID: Source.Event.ID?
    let actions: KalendsActions<Source.Event>

    @Environment(\.calendar) private var calendar

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    /// Months around an anchor. The anchor is fixed on first appearance and
    /// the range only grows at the edges when the user travels far; rebuilding
    /// the list around a new date would shift the content above the current
    /// position and make the scroll jump.
    @State private var anchorMonth: Date?
    @State private var monthOffsets: ClosedRange<Int> = -24 ... 24
    private static var edgeMargin: Int { 6 }

    private var resolvedAnchor: Date {
        anchorMonth ?? calendar.startOfMonth(for: selectedDate)
    }

    private var allMonths: [Date] {
        monthOffsets.compactMap { calendar.date(byAdding: .month, value: $0, to: resolvedAnchor) }
    }

    var body: some View {
        VStack(spacing: 0) {
            WeekdayHeaderRow(
                style: .short,
                font: .subheadline,
                color: .secondary,
                verticalPadding: 8,
                horizontalPadding: 4
            )

            Divider()

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(allMonths, id: \.self) { month in
                            DetailedMonthSection(
                                source: source,
                                month: month,
                                selectedDate: $selectedDate,
                                selectedEventID: selectedEventID,
                                columns: columns,
                                actions: actions
                            )
                            .id(monthScrollID(for: month, calendar: calendar))
                        }
                    }
                }
                .onAppear {
                    if anchorMonth == nil {
                        anchorMonth = calendar.startOfMonth(for: selectedDate)
                    }
                    let target = monthScrollID(for: selectedDate, calendar: calendar)
                    Task { @MainActor in
                        proxy.scrollTo(target, anchor: .top)
                    }
                }
                .onChange(of: selectedDate) { oldDate, newDate in
                    let newMonth = calendar.startOfMonth(for: newDate)
                    guard newMonth != calendar.startOfMonth(for: oldDate) else { return }
                    extendRangeIfNeeded(for: newMonth)
                    let target = monthScrollID(for: newMonth, calendar: calendar)
                    Task { @MainActor in
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(target, anchor: .top)
                        }
                    }
                }
            }
        }
    }

    private func extendRangeIfNeeded(for month: Date) {
        let offset = calendar.dateComponents([.month], from: resolvedAnchor, to: month).month ?? 0
        if offset - Self.edgeMargin < monthOffsets.lowerBound {
            monthOffsets = (offset - 24) ... monthOffsets.upperBound
        } else if offset + Self.edgeMargin > monthOffsets.upperBound {
            monthOffsets = monthOffsets.lowerBound ... (offset + 24)
        }
    }
}

private struct DetailedMonthSection<Source: KalendsDataSource>: View {
    let source: Source
    let month: Date
    @Binding var selectedDate: Date
    let selectedEventID: Source.Event.ID?
    let columns: [GridItem]
    let actions: KalendsActions<Source.Event>

    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(DateText.monthYear(month, locale: locale))
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.leading, 8)
                    .padding(.vertical, 10)

                Spacer()
            }
            .padding(.horizontal, 4)

            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(Array(calendar.weeksInMonth(of: month).enumerated()), id: \.offset) { _, week in
                    ForEach(Array(week.enumerated()), id: \.offset) { _, date in
                        if let date {
                            dayCell(for: date)
                                .frame(height: 110)
                        } else {
                            Color.clear
                                .frame(height: 110)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func dayCell(for date: Date) -> some View {
        let events = source.events(on: date)

        return DetailedMonthDayCell(
            date: date,
            events: events,
            selectedEventID: selectedEventID,
            isCurrentMonth: calendar.isDate(date, equalTo: month, toGranularity: .month),
            isToday: calendar.isDateInToday(date),
            isSelected: calendar.isDate(date, equalTo: selectedDate, toGranularity: .day),
            onEventTap: { event in
                actions.selectEvent(event)
            },
            onDayTap: {
                selectedDate = date
                actions.clearSelection()
            },
            onDayDoubleTap: {
                selectedDate = date
                actions.openDay(date)
            }
        )
    }
}

private struct DetailedMonthDayCell<Event: KalendsEvent>: View {
    let date: Date
    let events: [Event]
    let selectedEventID: Event.ID?
    let isCurrentMonth: Bool
    let isToday: Bool
    let isSelected: Bool
    let onEventTap: (Event) -> Void
    let onDayTap: () -> Void
    let onDayDoubleTap: () -> Void

    @Environment(\.locale) private var locale
    @State private var isOverflowPresented = false

    private static var maxVisibleEvents: Int { 4 }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(DateText.dayNumber(date, locale: locale))
                    .font(.system(size: 14, weight: isToday ? .bold : .regular))
                    .foregroundColor(
                        isToday ? .white :
                            isCurrentMonth ? .primary : .gray.opacity(0.5)
                    )
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(isToday ? Color.red : Color.clear)
                    )
                    .padding(.top, 4)
                    .padding(.leading, 4)

                Spacer()
            }

            if !events.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(events.prefix(Self.maxVisibleEvents)) { event in
                        DetailedMonthEventRow(event: event, isSelected: selectedEventID == event.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onEventTap(event)
                            }
                    }

                    if events.count > Self.maxVisibleEvents {
                        Button {
                            isOverflowPresented = true
                        } label: {
                            Text(KalendsText.string("+\(events.count - Self.maxVisibleEvents) more", locale: locale))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $isOverflowPresented, arrowEdge: .trailing) {
                            DetailedMonthOverflowPopover(
                                date: date,
                                events: events,
                                selectedEventID: selectedEventID,
                                onEventTap: { event in
                                    isOverflowPresented = false
                                    onEventTap(event)
                                }
                            )
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .background(
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    isSelected && !isToday ?
                        Color.blue.opacity(0.08) :
                        Color.clear
                )
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onDayDoubleTap()
        }
        .onTapGesture {
            onDayTap()
        }
        .overlay(
            Rectangle()
                .stroke(Color.gray.opacity(0.15), lineWidth: 0.5)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let base = DateText.weekdayDayMonth(date, locale: locale)
        if events.isEmpty { return base }
        return KalendsText.string("\(base), \(events.count) events", locale: locale)
    }
}

private struct DetailedMonthEventRow<Event: KalendsEvent>: View {
    let event: Event
    let isSelected: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale

    private var selectedTextColor: Color {
        event.color.eventTextColor(isSelected: true, colorScheme: colorScheme)
    }

    var body: some View {
        HStack(spacing: 4) {
            if event.isAllDay {
                Text(event.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(selectedTextColor)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(event.color.opacity(isSelected ? 1.0 : 0.85))
                    )
            } else {
                RoundedRectangle(cornerRadius: 1)
                    .fill(event.color)
                    .frame(width: 3, height: 14)

                Text(event.title)
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? selectedTextColor : .primary)
                    .lineLimit(1)

                Spacer(minLength: 2)

                Text(DateText.time(event.startDate, locale: locale))
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? selectedTextColor.opacity(0.8) : .secondary)
            }
        }
        .padding(.horizontal, 3)
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(isSelected ? event.color.opacity(0.95) : Color.clear)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(event.isAllDay
            ? KalendsText.string("\(event.title), all-day", locale: locale)
            : "\(event.title), \(DateText.time(event.startDate, locale: locale))")
        .accessibilityAddTraits(.isButton)
    }
}

/// Every event of the day, for “+N more”.
private struct DetailedMonthOverflowPopover<Event: KalendsEvent>: View {
    let date: Date
    let events: [Event]
    let selectedEventID: Event.ID?
    let onEventTap: (Event) -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(DateText.weekdayDayMonth(date, locale: locale))
                .font(.headline)
                .padding(.bottom, 4)

            ForEach(events) { event in
                DetailedMonthEventRow(event: event, isSelected: selectedEventID == event.id)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onEventTap(event)
                    }
            }
        }
        .padding(12)
        .frame(minWidth: 240, maxWidth: 360)
    }
}
