import SwiftUI

/// One view for all four modes, for hosts that switch with a single control.
///
/// The day and week modes share their scroll position: switching between
/// them, or to the month and back, keeps the hour the user scrolled to.
///
/// ```swift
/// KalendsView(mode: mode, source: store, selectedDate: $date)
/// ```
public struct KalendsView<Source: KalendsDataSource>: View {
    private let mode: KalendsMode
    private let source: Source
    @Binding private var selectedDate: Date
    private let selectedEventID: Source.Event.ID?
    private let dayStyle: DayViewStyle
    private let monthStyle: MonthViewStyle
    private let yearStyle: YearViewStyle
    private let hourHeight: CGFloat
    private let actions: KalendsActions<Source.Event>

    @State private var timelineScroll = TimelineScrollMemory()

    public init(
        mode: KalendsMode,
        source: Source,
        selectedDate: Binding<Date>,
        selectedEventID: Source.Event.ID? = nil,
        dayStyle: DayViewStyle = .automatic,
        monthStyle: MonthViewStyle = .automatic,
        yearStyle: YearViewStyle = .automatic,
        hourHeight: CGFloat = 60,
        actions: KalendsActions<Source.Event> = KalendsActions()
    ) {
        self.mode = mode
        self.source = source
        self._selectedDate = selectedDate
        self.selectedEventID = selectedEventID
        self.dayStyle = dayStyle
        self.monthStyle = monthStyle
        self.yearStyle = yearStyle
        self.hourHeight = hourHeight
        self.actions = actions
    }

    public var body: some View {
        modeView
            .environment(\.kalendsTimelineScroll, timelineScroll)
    }

    @ViewBuilder
    private var modeView: some View {
        switch mode {
        case .day:
            DayView(
                source: source,
                selectedDate: $selectedDate,
                selectedEventID: selectedEventID,
                style: dayStyle,
                hourHeight: hourHeight,
                actions: actions
            )
        case .week:
            WeekView(
                source: source,
                selectedDate: $selectedDate,
                selectedEventID: selectedEventID,
                hourHeight: hourHeight,
                actions: actions
            )
        case .month:
            MonthView(
                source: source,
                selectedDate: $selectedDate,
                selectedEventID: selectedEventID,
                style: monthStyle,
                actions: actions
            )
        case .year:
            YearView(
                source: source,
                selectedDate: $selectedDate,
                style: yearStyle,
                actions: actions
            )
        }
    }
}
