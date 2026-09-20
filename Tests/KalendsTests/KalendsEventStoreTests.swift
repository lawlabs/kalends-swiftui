import XCTest
@testable import Kalends

@MainActor
final class KalendsEventStoreTests: XCTestCase {
    private let calendar = Calendar.testCalendar

    func testEventsAreIndexedByEveryDayTheyCover() {
        let day = testDay(2026, 9, 19)
        let nextDay = testDay(2026, 9, 20)
        let overnight = TestEvent(
            id: "o",
            title: "Overnight",
            startDate: calendar.date(bySettingHour: 23, minute: 0, second: 0, of: day)!,
            endDate: calendar.date(bySettingHour: 1, minute: 0, second: 0, of: nextDay)!
        )
        let morning = testEvent("m", day: nextDay, from: (9, 0), to: (10, 0))

        let store = KalendsEventStore(events: [morning, overnight], calendar: calendar)

        XCTAssertEqual(store.events(on: day).map(\.id), ["o"])
        XCTAssertEqual(store.events(on: nextDay).map(\.id), ["o", "m"])
        XCTAssertTrue(store.hasEvents(on: day))
        XCTAssertFalse(store.hasEvents(on: testDay(2026, 9, 21)))
    }

    func testUpsertReplacesByIDAndRemoveDrops() {
        let day = testDay()
        let store = KalendsEventStore(events: [testEvent("a", day: day, from: (9, 0), to: (10, 0))], calendar: calendar)

        var moved = testEvent("a", day: day, from: (14, 0), to: (15, 0))
        moved.title = "Moved"
        store.upsert(moved)
        store.upsert(testEvent("b", day: day, from: (11, 0), to: (12, 0)))

        XCTAssertEqual(store.events.count, 2)
        XCTAssertEqual(store.events(on: day).map(\.id), ["b", "a"])
        XCTAssertEqual(store.events(on: day).last?.title, "Moved")

        store.remove(id: "a")
        XCTAssertEqual(store.events(on: day).map(\.id), ["b"])
    }
}
