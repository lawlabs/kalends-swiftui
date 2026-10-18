import SwiftUI

/// The hour at the top of the day and week timelines.
///
/// ``KalendsView`` keeps one for both modes, so switching between day and
/// week, or to the month and back, keeps the time of day the user scrolled
/// to, as Apple Calendar does. A plain reference rather than observed state:
/// the timeline writes it while the user scrolls and reads it only when it
/// appears, so a write must not redraw anything.
@MainActor
final class TimelineScrollMemory {
    var topHour: Double?
}

extension EnvironmentValues {
    /// Shared by the modes of one ``KalendsView``; `nil` for a day or week
    /// view used on its own, which then remembers its own position.
    @Entry var kalendsTimelineScroll: TimelineScrollMemory? = nil
}

extension View {
    /// Opens a vertical timeline scroll view at the remembered hour, or at
    /// `initialHour` the first time, and records where the user scrolls.
    func timelineScroll(hourHeight: CGFloat, initialHour: @escaping () -> Int) -> some View {
        modifier(TimelineScrollModifier(hourHeight: hourHeight, initialHour: initialHour))
    }
}

private struct TimelineScrollModifier: ViewModifier {
    let hourHeight: CGFloat
    let initialHour: () -> Int

    @Environment(\.kalendsTimelineScroll) private var sharedMemory
    @State private var ownMemory = TimelineScrollMemory()
    @State private var position = ScrollPosition(edge: .top)
    @State private var phase = ScrollPhase.idle

    private var memory: TimelineScrollMemory { sharedMemory ?? ownMemory }

    func body(content: Content) -> some View {
        content
            .scrollPosition($position)
            // Only the user's scrolling is remembered. Restoring the hour in
            // a taller view can clamp it at the bottom; that clamp must not
            // replace the hour the user chose.
            .onScrollGeometryChange(for: Double?.self, of: topHour) { _, hour in
                guard phase.isScrolling, let hour else { return }
                memory.topHour = hour
            }
            .onScrollPhaseChange { oldPhase, newPhase, context in
                phase = newPhase
                if oldPhase.isScrolling, !newPhase.isScrolling, let hour = topHour(context.geometry) {
                    memory.topHour = hour
                }
            }
            .onAppear {
                // onAppear finishes before the first frame, so the timeline
                // opens at this hour instead of scrolling there visibly.
                let hour = memory.topHour ?? Double(initialHour())
                position.scrollTo(y: CGFloat(hour) * hourHeight)
            }
    }

    private func topHour(_ geometry: ScrollGeometry) -> Double? {
        // A scroll view on its way out can report an empty container.
        guard geometry.containerSize.height > 0, hourHeight > 0 else { return nil }
        return max(0, Double((geometry.contentOffset.y + geometry.contentInsets.top) / hourHeight))
    }
}
