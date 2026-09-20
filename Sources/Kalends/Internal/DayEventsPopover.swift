import SwiftUI

/// The list of a day's events shown from the year views, like Apple Calendar.
struct DayEventsPopover<Event: KalendsEvent>: View {
    let date: Date
    let events: [Event]
    let actions: KalendsActions<Event>

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(DateText.weekdayDayMonth(date, locale: locale))
                .font(.headline)
                .padding(.bottom, 4)

            ForEach(events) { event in
                PopoverEventRow(event: event)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        actions.selectEvent(event)
                    }
            }
        }
        .background(
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .onTapGesture {
                    actions.clearSelection()
                }
        )
        .padding(12)
        .frame(minWidth: 280, maxWidth: 400)
    }
}

/// Color bar, title and time of one event in the popover.
private struct PopoverEventRow<Event: KalendsEvent>: View {
    let event: Event

    @Environment(\.locale) private var locale
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(event.color)
                .frame(width: 4, height: 18)

            Text(event.title)
                .font(.system(size: 13))
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(event.isAllDay
                ? KalendsText.string("all-day", locale: locale)
                : DateText.time(event.startDate, locale: locale))
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? Color.gray.opacity(0.1) : Color.clear)
        )
        .onHoverIfSupported { hovering in
            isHovered = hovering
        }
    }
}
