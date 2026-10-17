import SwiftUI

/// Visual variant of an event block in a time grid.
enum EventBlockStyle {
    /// Day view: larger type, time range, subtitle.
    case day
    /// Week view: compact type, start time only.
    case week

    var metrics: Metrics {
        switch self {
        case .day:
            return Metrics(
                cornerRadius: 6, accentBarWidth: 4, contentSpacing: 2,
                horizontalPadding: 6, verticalPadding: 4,
                titleFont: .caption, timeFont: .caption2, clockFont: .system(size: 9),
                resizeHandleHeight: 8, showsEndTime: true, showsSubtitle: true,
                baseOpacity: 0.9
            )
        case .week:
            return Metrics(
                cornerRadius: 4, accentBarWidth: 3, contentSpacing: 1,
                horizontalPadding: 3, verticalPadding: 2,
                titleFont: .system(size: 10), timeFont: .system(size: 8), clockFont: .system(size: 7),
                resizeHandleHeight: 6, showsEndTime: false, showsSubtitle: false,
                baseOpacity: 1
            )
        }
    }

    struct Metrics {
        let cornerRadius: CGFloat
        let accentBarWidth: CGFloat
        let contentSpacing: CGFloat
        let horizontalPadding: CGFloat
        let verticalPadding: CGFloat
        let titleFont: Font
        let timeFont: Font
        let clockFont: Font
        let resizeHandleHeight: CGFloat
        let showsEndTime: Bool
        let showsSubtitle: Bool
        /// Opacity applied to the event color before any fill; the day view
        /// softens its blocks slightly.
        let baseOpacity: CGFloat
    }
}

/// An event block in a time grid that can be dragged (in time and, when
/// `dayWidth` is given, across days) and resized from its top and bottom
/// edges. Read-only events only respond to taps.
///
/// While interacting, position and size snap to 15 minutes and a badge shows
/// the new time, so what the user sees is what will be committed.
struct DraggableEventView<Event: KalendsEvent>: View {
    let event: Event
    let displayDate: Date
    let hourHeight: CGFloat
    let containerWidth: CGFloat
    /// Width of one day column; `nil` disables horizontal dragging.
    let dayWidth: CGFloat?
    let style: EventBlockStyle
    let xFraction: CGFloat
    let widthFraction: CGFloat
    let zIndexPriority: Double
    let isSelected: Bool
    let onReschedule: (DateInterval) -> Void
    let onTap: () -> Void
    var visibleDays: [Date]? = nil
    /// Cascade level from ``EventLayout/overlapDepth``; above 0 the block is
    /// drawn over another one.
    var overlapDepth: Int = 0

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    private enum InteractionMode {
        case none, dragging, resizingTop, resizingBottom
    }

    @State private var interactionMode: InteractionMode = .none
    @State private var dragOffsetX: CGFloat = 0
    @State private var dragOffsetY: CGFloat = 0
    @State private var topResizeOffset: CGFloat = 0
    @State private var bottomResizeOffset: CGFloat = 0

    private static var minimumDuration: TimeInterval { 15 * 60 }
    private static var snapMinutes: Int { 15 }
    /// zIndex of the block being dragged. `zIndexPriority` stays within a day
    /// in seconds (< 86 400), so this is guaranteed to be above it.
    private static var interactingZIndex: Double { 1_000_000 }

    private var metrics: EventBlockStyle.Metrics { style.metrics }
    private var color: Color { event.color.opacity(metrics.baseOpacity) }

    // MARK: - Geometry

    private var displayedInterval: DateInterval {
        let startOfDay = calendar.startOfDay(for: displayDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay.addingTimeInterval(24 * 3600)
        let visibleStart = max(event.startDate, startOfDay)
        let visibleEnd = max(min(event.endDate, endOfDay), visibleStart)
        return DateInterval(start: visibleStart, end: visibleEnd)
    }

    private var pointsPerMinute: CGFloat { hourHeight / 60 }
    private var snapStep: CGFloat { pointsPerMinute * CGFloat(Self.snapMinutes) }
    private var minimumHeight: CGFloat { max(20, pointsPerMinute * CGFloat(Self.minimumDuration / 60)) }

    private var startOffset: CGFloat {
        let startOfDay = calendar.startOfDay(for: displayDate)
        let secondsFromStartOfDay = displayedInterval.start.timeIntervalSince(startOfDay)
        return CGFloat(max(secondsFromStartOfDay, 0)) * (hourHeight / 3600)
    }

    private var eventHeight: CGFloat {
        max(CGFloat(displayedInterval.duration) * (hourHeight / 3600), 20)
    }

    private var eventWidth: CGFloat {
        max(0, containerWidth * widthFraction - 2)
    }

    private var horizontalOffset: CGFloat {
        containerWidth * xFraction
    }

    private var isInteracting: Bool {
        interactionMode != .none
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            eventBody
            if !event.isReadOnly {
                topResizeHandle
                bottomResizeHandle
            }
        }
        .frame(width: eventWidth, height: max(1, eventHeight - topResizeOffset + bottomResizeOffset))
        .overlay(alignment: .topLeading) {
            if isInteracting {
                interactionTimeLabel
            }
        }
        .offset(x: horizontalOffset + dragOffsetX, y: startOffset + dragOffsetY + topResizeOffset)
        .padding(.horizontal, 1)
        .zIndex(isInteracting ? Self.interactingZIndex : zIndexPriority)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Appearance (Apple Calendar style)

    private var textColor: Color {
        color.eventTextColor(isSelected: isSelected, colorScheme: colorScheme)
    }

    private var backgroundColor: Color {
        color.opacity(isSelected ? 0.95 : 0.25)
    }

    private var displayTitle: String {
        event.title.isEmpty ? KalendsText.string("New Event", locale: locale) : event.title
    }

    private var eventBody: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: metrics.accentBarWidth / 2)
                .fill(color)
                .frame(width: metrics.accentBarWidth)

            EventBlockContentLayout(spacing: metrics.contentSpacing) {
                Text(displayTitle)
                    .font(metrics.titleFont)
                    .fontWeight(.semibold)
                    .foregroundColor(textColor)

                timeLine

                if metrics.showsSubtitle, let subtitle = event.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(metrics.timeFont)
                        .foregroundColor(textColor.opacity(0.7))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.vertical, metrics.verticalPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            // The tint goes over an opaque backdrop: a block drawn over
            // another one hides it rather than mixing both texts.
            RoundedRectangle(cornerRadius: metrics.cornerRadius)
                .fill(Color.kalendsEventBackdrop)
                .overlay(
                    RoundedRectangle(cornerRadius: metrics.cornerRadius)
                        .fill(backgroundColor)
                )
                .opacity(isInteracting ? 0.6 : 1.0)
        )
        .clipShape(RoundedRectangle(cornerRadius: metrics.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: metrics.cornerRadius)
                .stroke(
                    color.opacity(isSelected ? 0.5 : 0.3),
                    lineWidth: isSelected ? 1.5 : (isInteracting ? 1 : 0)
                )
        )
        .background {
            // A thin rim in the backdrop color sets a cascaded block off
            // from the one it covers.
            if overlapDepth > 0, !isInteracting {
                RoundedRectangle(cornerRadius: metrics.cornerRadius + 1)
                    .fill(Color.kalendsEventBackdrop)
                    .padding(-1)
            }
        }
        // Keeps back-to-back events of one calendar from merging.
        .padding(.bottom, 1)
        .contentShape(Rectangle())
        .gesture(dragGesture, isEnabled: !event.isReadOnly)
        .onTapGesture {
            onTap()
        }
    }

    private var timeText: String {
        let start = DateText.time(event.startDate, locale: locale)
        if metrics.showsEndTime {
            return "\(start) — \(DateText.time(event.endDate, locale: locale))"
        }
        return start
    }

    /// The time line, shortened step by step to fit a narrow block: without
    /// the clock, then the start time only, then nothing rather than a
    /// truncated “1…”.
    private var timeLine: some View {
        ViewThatFits(in: .horizontal) {
            timeLabel(timeText, showsClock: true)
            timeLabel(timeText, showsClock: false)
            if metrics.showsEndTime {
                timeLabel(DateText.time(event.startDate, locale: locale), showsClock: false)
            }
            Color.clear.frame(width: 0, height: 0)
        }
    }

    private func timeLabel(_ text: String, showsClock: Bool) -> some View {
        HStack(spacing: metrics.contentSpacing + 1) {
            if showsClock {
                Image(systemName: "clock")
                    .font(metrics.clockFont)
            }
            Text(text)
                .font(metrics.timeFont)
        }
        .foregroundColor(textColor.opacity(0.8))
        .lineLimit(1)
        .fixedSize()
    }

    /// The badge with the new time while dragging or resizing.
    private var interactionTimeLabel: some View {
        let projected = projectedInterval()
        return Text("\(DateText.time(projected.start, locale: locale)) — \(DateText.time(projected.end, locale: locale))")
            .font(.system(size: 10, weight: .semibold))
            .monospacedDigit()
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.accentColor))
            .fixedSize()
            .offset(x: 2, y: -18)
            .allowsHitTesting(false)
    }

    private var accessibilityDescription: String {
        "\(displayTitle), \(DateText.time(event.startDate, locale: locale)) — \(DateText.time(event.endDate, locale: locale))"
    }

    // MARK: - Resize handles

    private var topResizeHandle: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: metrics.resizeHandleHeight)
            .contentShape(Rectangle())
            .gesture(topResizeGesture)
            .resizeCursorIfAvailable()
    }

    private var bottomResizeHandle: some View {
        VStack {
            Spacer()
            Rectangle()
                .fill(Color.clear)
                .frame(height: metrics.resizeHandleHeight)
                .contentShape(Rectangle())
                .gesture(bottomResizeGesture)
                .resizeCursorIfAvailable()
        }
    }

    // MARK: - New time

    private func minutes(fromPoints points: CGFloat) -> Int {
        Int((points / pointsPerMinute).rounded())
    }

    private func snapped(_ points: CGFloat) -> CGFloat {
        (points / snapStep).rounded() * snapStep
    }

    private func snappedDayOffset(_ points: CGFloat) -> CGFloat {
        guard let dayWidth, dayWidth > 0 else { return 0 }
        let offset = Int((points / dayWidth).rounded())
        if let visibleDays,
           let index = visibleDays.firstIndex(where: { calendar.isDate($0, inSameDayAs: displayDate) }) {
            return CGFloat(min(max(offset, -index), visibleDays.count - index - 1)) * dayWidth
        }
        return CGFloat(offset) * dayWidth
    }

    private var daysDelta: Int {
        guard let dayWidth, dayWidth > 0 else { return 0 }
        let columnOffset = Int((dragOffsetX / dayWidth).rounded())
        if let visibleDays,
           let destination = calendar.destinationDay(from: displayDate, columnOffset: columnOffset, visibleDays: visibleDays) {
            return calendar.dateComponents([.day], from: calendar.startOfDay(for: displayDate), to: destination).day ?? 0
        }
        return columnOffset
    }

    /// The event's time range with the current offsets applied — what will be
    /// committed on release.
    private func projectedInterval() -> DateInterval {
        var newStart = event.startDate
        var newEnd = event.endDate

        switch interactionMode {
        case .dragging:
            if daysDelta != 0,
               let shiftedStart = calendar.date(byAdding: .day, value: daysDelta, to: newStart),
               let shiftedEnd = calendar.date(byAdding: .day, value: daysDelta, to: newEnd) {
                newStart = shiftedStart
                newEnd = shiftedEnd
            }
            let minutesDelta = minutes(fromPoints: dragOffsetY)
            if minutesDelta != 0,
               let shiftedStart = calendar.date(byAdding: .minute, value: minutesDelta, to: newStart),
               let shiftedEnd = calendar.date(byAdding: .minute, value: minutesDelta, to: newEnd) {
                newStart = shiftedStart
                newEnd = shiftedEnd
            }

        case .resizingTop:
            let minutesDelta = minutes(fromPoints: topResizeOffset)
            if minutesDelta != 0,
               let candidate = calendar.date(byAdding: .minute, value: minutesDelta, to: event.startDate),
               candidate <= event.endDate.addingTimeInterval(-Self.minimumDuration) {
                newStart = candidate
            }

        case .resizingBottom:
            let minutesDelta = minutes(fromPoints: bottomResizeOffset)
            if minutesDelta != 0,
               let candidate = calendar.date(byAdding: .minute, value: minutesDelta, to: event.endDate),
               candidate >= event.startDate.addingTimeInterval(Self.minimumDuration) {
                newEnd = candidate
            }

        case .none:
            break
        }

        return DateInterval(start: newStart, end: max(newEnd, newStart))
    }

    private func commitInteraction() {
        let projected = projectedInterval()
        if projected.start != event.startDate || projected.end != event.endDate {
            onReschedule(projected)
        }
        dragOffsetX = 0
        dragOffsetY = 0
        topResizeOffset = 0
        bottomResizeOffset = 0
        interactionMode = .none
    }

    // MARK: - Gestures

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .global)
            .onChanged { value in
                interactionMode = .dragging
                dragOffsetX = snappedDayOffset(value.translation.width)
                dragOffsetY = snapped(value.translation.height)
            }
            .onEnded { _ in
                commitInteraction()
            }
    }

    private var topResizeGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { value in
                interactionMode = .resizingTop
                let minOffset = -startOffset
                let maxOffset = eventHeight - minimumHeight
                topResizeOffset = min(max(snapped(value.translation.height), minOffset), maxOffset)
            }
            .onEnded { _ in
                commitInteraction()
            }
    }

    private var bottomResizeGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { value in
                interactionMode = .resizingBottom
                bottomResizeOffset = max(snapped(value.translation.height), -(eventHeight - minimumHeight))
            }
            .onEnded { _ in
                commitInteraction()
            }
    }
}

/// The timed events of one day laid out by ``EventLayoutCalculator`` and
/// rendered as draggable blocks.
struct DayColumnEvents<Source: KalendsDataSource>: View {
    let source: Source
    let day: Date
    let hourHeight: CGFloat
    let containerWidth: CGFloat
    let dayWidth: CGFloat?
    let style: EventBlockStyle
    let selectedEventID: Source.Event.ID?
    let actions: KalendsActions<Source.Event>
    var visibleDays: [Date]? = nil

    @Environment(\.calendar) private var calendar

    var body: some View {
        let dayEvents = source.events(on: day).filter { !$0.isAllDay }
        let layouts = EventLayoutCalculator.layout(
            for: dayEvents,
            on: day,
            containerWidth: containerWidth,
            hourHeight: hourHeight,
            calendar: calendar
        )

        ForEach(layouts) { layout in
            DraggableEventView(
                event: layout.event,
                displayDate: day,
                hourHeight: hourHeight,
                containerWidth: containerWidth,
                dayWidth: dayWidth,
                style: style,
                xFraction: layout.xFraction,
                widthFraction: layout.widthFraction,
                zIndexPriority: layout.zIndexPriority,
                isSelected: selectedEventID == layout.event.id,
                onReschedule: { interval in
                    actions.rescheduleEvent(layout.event, interval)
                },
                onTap: {
                    actions.selectEvent(layout.event)
                },
                visibleDays: visibleDays,
                overlapDepth: layout.overlapDepth
            )
        }
    }
}
