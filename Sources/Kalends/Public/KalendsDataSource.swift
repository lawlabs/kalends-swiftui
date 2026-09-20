import Foundation
import Observation

/// Supplies events to Kalends views, one calendar day at a time.
///
/// Views ask for the events of every day they draw, so the source should
/// answer quickly — keep an index by day rather than filtering a large array
/// on each call. An `@Observable` source makes the views redraw when its data
/// changes.
@MainActor
public protocol KalendsDataSource<Event> {
    associatedtype Event: KalendsEvent

    /// Events that intersect the calendar day containing `day`, sorted by start.
    /// A multi-day event is expected on every day it covers.
    func events(on day: Date) -> [Event]

    /// Whether the day has at least one event; used by the year and mini
    /// calendars, which only draw a dot.
    func hasEvents(on day: Date) -> Bool
}

public extension KalendsDataSource {
    func hasEvents(on day: Date) -> Bool {
        !events(on: day).isEmpty
    }
}

/// An in-memory data source for previews, samples and small apps.
///
/// Keeps events in an array and indexes them by day; every change to
/// ``events`` rebuilds the index.
@MainActor
@Observable
public final class KalendsEventStore<Event: KalendsEvent>: KalendsDataSource {
    public var events: [Event] {
        didSet { rebuildIndex() }
    }

    private var eventsByDay: [Date: [Event]] = [:]
    private let calendar: Calendar

    public init(events: [Event] = [], calendar: Calendar = .current) {
        self.events = events
        self.calendar = calendar
        rebuildIndex()
    }

    public func events(on day: Date) -> [Event] {
        eventsByDay[calendar.startOfDay(for: day)] ?? []
    }

    public func hasEvents(on day: Date) -> Bool {
        eventsByDay[calendar.startOfDay(for: day)] != nil
    }

    /// Replaces the event with the same `id`, or appends it.
    public func upsert(_ event: Event) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = event
        } else {
            events.append(event)
        }
    }

    public func remove(id: Event.ID) {
        events.removeAll { $0.id == id }
    }

    private func rebuildIndex() {
        var index: [Date: [Event]] = [:]
        for event in events {
            for day in calendar.days(covering: event) {
                index[day, default: []].append(event)
            }
        }
        for key in index.keys {
            index[key]?.sort { $0.startDate < $1.startDate }
        }
        eventsByDay = index
    }
}
