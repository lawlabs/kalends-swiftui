import Foundation

/// Callbacks through which Kalends reports user intent to the host.
///
/// Kalends never edits data itself: it asks. Every callback has a no-op
/// default, so a read-only calendar needs none of them.
public struct KalendsActions<Event: KalendsEvent> {
    /// The user tapped an event.
    public var selectEvent: @MainActor (Event) -> Void
    /// The user tapped empty space; the host usually clears its selection.
    public var clearSelection: @MainActor () -> Void
    /// The user moved or resized an event; `interval` is the new, snapped time range.
    public var rescheduleEvent: @MainActor (Event, DateInterval) -> Void
    /// The user double-tapped empty space in a time grid at `start`.
    /// The host picks the duration and creates the event.
    public var createEvent: @MainActor (_ start: Date) -> Void
    /// The user is dragging on empty space to draw a new event. Called
    /// continuously with the current snapped range; the host creates a draft
    /// on the first call and updates it afterwards.
    public var updateDraft: @MainActor (DateInterval) -> Void
    /// The user double-tapped a day in the month or year view.
    public var openDay: @MainActor (Date) -> Void

    public init(
        selectEvent: @escaping @MainActor (Event) -> Void = { _ in },
        clearSelection: @escaping @MainActor () -> Void = {},
        rescheduleEvent: @escaping @MainActor (Event, DateInterval) -> Void = { _, _ in },
        createEvent: @escaping @MainActor (Date) -> Void = { _ in },
        updateDraft: @escaping @MainActor (DateInterval) -> Void = { _ in },
        openDay: @escaping @MainActor (Date) -> Void = { _ in }
    ) {
        self.selectEvent = selectEvent
        self.clearSelection = clearSelection
        self.rescheduleEvent = rescheduleEvent
        self.createEvent = createEvent
        self.updateDraft = updateDraft
        self.openDay = openDay
    }
}
