import SwiftUI

/// Transparent layer over a day column that turns taps and drags on empty
/// space into host callbacks: a tap clears the selection, a double tap asks
/// for a new event at that time, a vertical drag draws a draft.
struct TimeGridCreationOverlay<Event: KalendsEvent>: View {
    let day: Date
    let hourHeight: CGFloat
    let hourCount: Int
    let actions: KalendsActions<Event>

    @Environment(\.calendar) private var calendar
    @State private var creationDragStartY: CGFloat?

    private var totalHeight: CGFloat { CGFloat(hourCount) * hourHeight }

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())
            .gesture(dragCreationGesture)
            .simultaneousGesture(doubleTapCreationGesture)
            .simultaneousGesture(backgroundSelectionClearGesture)
    }

    /// The grid time at a vertical position, snapped to 15 minutes.
    private func date(forVerticalLocation y: CGFloat) -> Date {
        let clampedY = min(max(0, y), totalHeight)
        let rawMinutes = Int((clampedY / hourHeight) * 60)
        let roundedMinutes = min(23 * 60 + 45, ((rawMinutes + 7) / 15) * 15)
        return calendar.date(
            bySettingHour: roundedMinutes / 60,
            minute: roundedMinutes % 60,
            second: 0,
            of: day
        ) ?? day
    }

    private var doubleTapCreationGesture: some Gesture {
        SpatialTapGesture(count: 2)
            .onEnded { value in
                actions.createEvent(date(forVerticalLocation: value.location.y))
            }
    }

    private var backgroundSelectionClearGesture: some Gesture {
        SpatialTapGesture(count: 1)
            .onEnded { _ in
                actions.clearSelection()
            }
    }

    private var dragCreationGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in
                let startY = creationDragStartY ?? value.startLocation.y
                creationDragStartY = startY

                guard abs(value.translation.height) >= 8 else { return }

                let start = date(forVerticalLocation: startY)
                let end = date(forVerticalLocation: value.location.y)
                actions.updateDraft(DateInterval(start: min(start, end), end: max(start, end)))
            }
            .onEnded { _ in
                creationDragStartY = nil
            }
    }
}
