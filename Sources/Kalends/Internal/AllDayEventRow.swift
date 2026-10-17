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
        .padding(.horizontal, 4)
    }
}

/// The all-day section of a single-day timeline: a title and the rows.
struct AllDaySection<Source: KalendsDataSource>: View {
    let source: Source
    let day: Date
    let selectedEventID: Source.Event.ID?
    let actions: KalendsActions<Source.Event>
    let timeColumnWidth: CGFloat

    @Environment(\.locale) private var locale

    var body: some View {
        let allDayEvents = source.events(on: day).filter(\.isAllDay)
        if !allDayEvents.isEmpty {
            HStack(alignment: .top, spacing: 0) {
                Text(KalendsText.string("All day", locale: locale))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.trailing)
                    .padding(.trailing, 8)
                    .frame(width: timeColumnWidth, alignment: .trailing)
                    .padding(.top, 8)

                // Sized to its rows; only a long list scrolls within 100 pt.
                CappedHeightLayout(maxHeight: 100) {
                    ScrollView {
                        rows(allDayEvents)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(DayBackground(date: day))
            }
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

/// As tall as its content, but no taller than `maxHeight`. Unlike
/// `.frame(maxHeight:)`, which grows to the limit whenever the parent offers
/// more room, it never adds empty space below the content.
private struct CappedHeightLayout: Layout {
    var maxHeight: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let content = subviews.first else { return .zero }
        let ideal = content.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil))
        return CGSize(width: proposal.width ?? ideal.width, height: min(ideal.height, maxHeight))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}
