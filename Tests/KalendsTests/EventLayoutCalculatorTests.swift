import XCTest
@testable import Kalends

final class EventLayoutCalculatorTests: XCTestCase {
    private let containerWidth: CGFloat = 300
    private let hourHeight: CGFloat = 60
    private let calendar = Calendar.testCalendar

    func testOverlappingTitleBandsSplitEventsHorizontally() {
        let day = testDay()
        let first = testEvent("One", day: day, from: (10, 0), to: (11, 0))
        let second = testEvent("Two", day: day, from: (10, 10), to: (10, 50))

        let layout = layout(for: [first, second], day: day)
        let firstLayout = layout.first { $0.id == first.id }
        let secondLayout = layout.first { $0.id == second.id }

        XCTAssertEqual(layout.count, 2)
        XCTAssertNotNil(firstLayout)
        XCTAssertNotNil(secondLayout)
        XCTAssertEqual(firstLayout?.xFraction ?? -1, 0, accuracy: 0.001)
        XCTAssertEqual(firstLayout?.overlapDepth, 0)
        XCTAssertEqual(secondLayout?.overlapDepth, 1)
        XCTAssertGreaterThan(firstLayout?.widthFraction ?? 0, 0.55)
        XCTAssertLessThan(firstLayout?.widthFraction ?? 1, 0.62)
        XCTAssertGreaterThan(secondLayout?.xFraction ?? 0, 0.38)
        XCTAssertLessThan(secondLayout?.xFraction ?? 1, 0.44)
        XCTAssertGreaterThan(secondLayout?.widthFraction ?? 0, 0.55)
        XCTAssertLessThan(secondLayout?.widthFraction ?? 1, 0.62)
    }

    func testSeparatedEventsReuseFullWidth() {
        let day = testDay()
        let first = testEvent("Morning", day: day, from: (9, 0), to: (10, 0))
        let second = testEvent("Afternoon", day: day, from: (11, 0), to: (12, 0))

        let layout = layout(for: [first, second], day: day)

        XCTAssertEqual(layout.count, 2)
        XCTAssertTrue(layout.allSatisfy { abs($0.xFraction) < 0.001 })
        XCTAssertTrue(layout.allSatisfy { $0.widthFraction > 0.99 })
    }

    func testBodyOverlapKeepsLongEventWide() {
        let day = testDay()
        let long = testEvent("Long", day: day, from: (9, 0), to: (12, 0))
        let short = testEvent("Short", day: day, from: (10, 0), to: (11, 0))

        let layout = layout(for: [long, short], day: day)
        let longLayout = layout.first { $0.id == long.id }
        let shortLayout = layout.first { $0.id == short.id }

        XCTAssertEqual(layout.count, 2)
        XCTAssertEqual(longLayout?.xFraction ?? -1, 0, accuracy: 0.001)
        XCTAssertGreaterThan(shortLayout?.xFraction ?? 0, 0.03)
        XCTAssertGreaterThan(longLayout?.widthFraction ?? 0, 0.95)
        XCTAssertGreaterThan(shortLayout?.widthFraction ?? 0, 0.88)
        XCTAssertLessThan(shortLayout?.widthFraction ?? 1, 0.95)
    }

    func testThreeStackAssignsIncreasingDepthAndStaggeredOffsets() {
        let day = testDay()
        let first = testEvent("A", day: day, from: (12, 0), to: (14, 0))
        let second = testEvent("B", day: day, from: (12, 5), to: (13, 0))
        let third = testEvent("C", day: day, from: (12, 10), to: (13, 15))

        let layout = layout(for: [first, second, third], day: day)
        let firstLayout = layout.first { $0.id == first.id }
        let secondLayout = layout.first { $0.id == second.id }
        let thirdLayout = layout.first { $0.id == third.id }

        XCTAssertEqual(layout.count, 3)
        XCTAssertEqual(firstLayout?.overlapDepth, 0)
        XCTAssertEqual(secondLayout?.overlapDepth, 1)
        XCTAssertEqual(thirdLayout?.overlapDepth, 2)
        XCTAssertEqual(firstLayout?.overlapStackCount, 3)
        XCTAssertEqual(secondLayout?.overlapStackCount, 3)
        XCTAssertEqual(thirdLayout?.overlapStackCount, 3)
        XCTAssertLessThan(firstLayout?.xFraction ?? 1, secondLayout?.xFraction ?? 0)
        XCTAssertLessThan(secondLayout?.xFraction ?? 1, thirdLayout?.xFraction ?? 0)
        XCTAssertGreaterThan(firstLayout?.widthFraction ?? 0, 0.45)
        XCTAssertGreaterThan(secondLayout?.widthFraction ?? 0, 0.45)
        XCTAssertGreaterThan(thirdLayout?.widthFraction ?? 0, 0.45)
    }

    func testLaterLongBodyOverlapGetsRevealGap() {
        let day = testDay()
        let first = testEvent("Primary", day: day, from: (12, 0), to: (13, 45))
        let second = testEvent("Secondary", day: day, from: (12, 45), to: (15, 0))

        let layout = layout(for: [first, second], day: day)
        let firstLayout = layout.first { $0.id == first.id }
        let secondLayout = layout.first { $0.id == second.id }

        XCTAssertEqual(layout.count, 2)
        XCTAssertEqual(firstLayout?.xFraction ?? -1, 0, accuracy: 0.001)
        XCTAssertGreaterThan(secondLayout?.xFraction ?? 0, 0.03)
        XCTAssertGreaterThan(firstLayout?.widthFraction ?? 0, 0.95)
        XCTAssertGreaterThan(secondLayout?.widthFraction ?? 0, 0.88)
        XCTAssertLessThan(secondLayout?.widthFraction ?? 1, 0.95)
    }

    func testLaterEventReturnsToFullWidthAfterEarlierOverlapCluster() {
        let day = testDay()
        let first = testEvent("First", day: day, from: (9, 0), to: (9, 45))
        let second = testEvent("Second", day: day, from: (9, 5), to: (9, 25))
        let third = testEvent("Third", day: day, from: (10, 0), to: (10, 45))

        let layout = layout(for: [first, second, third], day: day)
        let thirdLayout = layout.first { $0.id == third.id }

        XCTAssertEqual(layout.count, 3)
        XCTAssertNotNil(thirdLayout)
        XCTAssertEqual(thirdLayout?.xFraction ?? -1, 0, accuracy: 0.001)
        XCTAssertGreaterThan(thirdLayout?.widthFraction ?? 0, 0.95)
    }

    func testEventsTouchingBoundariesDoNotOverlap() {
        let day = testDay()
        let first = testEvent("First", day: day, from: (10, 0), to: (10, 30))
        let second = testEvent("Second", day: day, from: (10, 30), to: (11, 0))

        let layout = layout(for: [first, second], day: day)

        XCTAssertEqual(layout.count, 2)
        XCTAssertTrue(layout.allSatisfy { abs($0.xFraction) < 0.001 })
        XCTAssertTrue(layout.allSatisfy { $0.widthFraction > 0.99 })
    }

    func testAllDayEventsAreExcluded() {
        let day = testDay()
        var allDay = testEvent("All day", day: day, from: (0, 0), to: (23, 59))
        allDay.isAllDay = true
        let timed = testEvent("Timed", day: day, from: (10, 0), to: (11, 0))

        let layout = layout(for: [allDay, timed], day: day)

        XCTAssertEqual(layout.map(\.id), [timed.id])
    }

    func testMultiDayEventIsClampedToTheDisplayedDay() {
        let day = testDay()
        let nextDay = calendar.date(byAdding: .day, value: 1, to: day)!
        let overnight = TestEvent(
            id: "overnight",
            title: "Overnight",
            startDate: calendar.date(bySettingHour: 22, minute: 0, second: 0, of: day)!,
            endDate: calendar.date(bySettingHour: 2, minute: 0, second: 0, of: nextDay)!
        )

        let todayLayout = layout(for: [overnight], day: day)
        let tomorrowLayout = layout(for: [overnight], day: nextDay)

        XCTAssertEqual(todayLayout.count, 1)
        XCTAssertEqual(tomorrowLayout.count, 1)
        XCTAssertEqual(todayLayout.first?.zIndexPriority ?? 0, 22 * 3600, accuracy: 0.01)
        XCTAssertEqual(tomorrowLayout.first?.zIndexPriority ?? -1, 0, accuracy: 0.01)
    }

    func testZIndexPriorityStaysWithinOneDay() {
        let day = testDay()
        let late = testEvent("Late", day: day, from: (23, 45), to: (23, 59))

        let priority = EventLayoutCalculator.zIndexPriority(for: late, on: day, calendar: calendar)

        XCTAssertGreaterThan(priority, 0)
        XCTAssertLessThan(priority, 86_400)
    }

    func testLayoutIsDeterministicForIdenticalIntervals() {
        let day = testDay()
        let events = ["b", "a", "c"].map { testEvent($0, day: day, from: (9, 0), to: (10, 0)) }

        let first = layout(for: events, day: day).map { ($0.id, $0.overlapDepth) }
        let second = layout(for: events.reversed(), day: day).map { ($0.id, $0.overlapDepth) }

        XCTAssertEqual(Dictionary(uniqueKeysWithValues: first), Dictionary(uniqueKeysWithValues: second))
        XCTAssertEqual(Dictionary(uniqueKeysWithValues: first)["a"], 0)
    }

    private func layout(for events: [TestEvent], day: Date) -> [EventLayout<TestEvent>] {
        EventLayoutCalculator.layout(
            for: events,
            on: day,
            containerWidth: containerWidth,
            hourHeight: hourHeight,
            calendar: calendar
        )
    }
}
