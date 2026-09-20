import SwiftUI

/// A full-width row for an all-day event above the time grid of a single day.
struct AllDayEventRow<Event: KalendsEvent>: View {
    let event: Event
    var isSelected: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    private var textColor: Color {
        event.color.eventTextColor(isSelected: isSelected, colorScheme: colorScheme)
    }

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(event.color)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(textColor)

                if let subtitle = event.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(textColor.opacity(0.7))
                }
            }
            .padding(.horizontal, 8)

            Spacer()
        }
        .padding(.vertical, 8)
        .background(event.color.opacity(isSelected ? 0.95 : 0.2))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(event.color.opacity(isSelected ? 0.6 : 0), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

/// The all-day section of a single-day timeline: a title and the rows.
struct AllDaySection<Source: KalendsDataSource>: View {
    let source: Source
    let day: Date
    let selectedEventID: Source.Event.ID?
    let actions: KalendsActions<Source.Event>

    @Environment(\.locale) private var locale

    var body: some View {
        let allDayEvents = source.events(on: day).filter(\.isAllDay)
        if !allDayEvents.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(KalendsText.string("All day", locale: locale))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)

                // Sized to its rows; only a long list scrolls within 100 pt.
                ViewThatFits(in: .vertical) {
                    rows(allDayEvents)
                    ScrollView {
                        rows(allDayEvents)
                    }
                }
                .frame(maxHeight: 100)
            }
            .padding(.vertical, 8)
            .background(
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        actions.clearSelection()
                    }
            )

            Divider()
        }
    }

    private func rows(_ events: [Source.Event]) -> some View {
        VStack(spacing: 4) {
            ForEach(events) { event in
                AllDayEventRow(event: event, isSelected: selectedEventID == event.id)
                    .onTapGesture {
                        actions.selectEvent(event)
                    }
            }
        }
    }
}
