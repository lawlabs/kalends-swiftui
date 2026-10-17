import XCTest
@testable import Kalends

final class EventLayoutCalculatorTests: XCTestCase {
    private let containerWidth: CGFloat = 300
    private let hourHeight: CGFloat = 60
    private let calendar = Calendar.testCalendar
    private let configuration = EventLayoutConfiguration()

    private var indentFraction: CGFloat { configuration.staggerOffset / containerWidth }

    func testEventsWithOverlappingTitlesSitSideBySide() {
        let day = testDay()
        let first = testEvent("One", day: day, from: (10, 0), to: (11, 0))
        let second = testEvent("Two", day: day, from: (10, 10), to: (10, 50))

        let layout = layout(for: [first, second], day: day)

        XCTAssertEqual(layout.count, 2)
        XCTAssertEqual(layout[first.id]?.xFraction ?? -1, 0, accuracy: 0.001)
        XCTAssertEqual(layout[first.id]?.widthFraction ?? 0, 0.5, accuracy: 0.001)
        XCTAssertEqual(layout[second.id]?.xFraction ?? 0, 0.5, accuracy: 0.001)
        XCTAssertEqual(layout[second.id]?.widthFraction ?? 0, 0.5, accuracy: 0.001)
        XCTAssertEqual(layout[first.id]?.overlapStackCount, 2)
        XCTAssertEqual(layout[second.id]?.overlapDepth, 0)
        assertReadable(layout, day: day)
    }

    func testSeparatedEventsReuseFullWidth() {
        let day = testDay()
        let first = testEvent("Morning", day: day, from: (9, 0), to: (10, 0))
        let second = testEvent("Afternoon", day: day, from: (11, 0), to: (12, 0))

        let layout = layout(for: [first, second], day: day)

        XCTAssertEqual(layout.count, 2)
        XCTAssertTrue(layout.allSatisfy { abs($0.xFraction) < 0.001 })
        XCTAssertTrue(layout.allSatisfy { $0.widthFraction > 0.999 })
    }

    func testEventStartingInsideALongerOneIsCascadedOverIt() {
        let day = testDay()
        let long = testEvent("Long", day: day, from: (9, 0), to: (12, 0))
        let short = testEvent("Short", day: day, from: (10, 0), to: (11, 0))

        let layout = layout(for: [long, short], day: day)

        XCTAssertEqual(layout[long.id]?.xFraction ?? -1, 0, accuracy: 0.001)
        XCTAssertEqual(layout[long.id]?.widthFraction ?? 0, 1, accuracy: 0.001)
        XCTAssertEqual(layout[short.id]?.xFraction ?? 0, indentFraction, accuracy: 0.001)
        XCTAssertEqual(layout[short.id]?.widthFraction ?? 0, 1 - indentFraction, accuracy: 0.001)
        XCTAssertEqual(layout[short.id]?.overlapDepth, 1)
        XCTAssertGreaterThan(layout[short.id]?.zIndexPriority ?? 0, layout[long.id]?.zIndexPriority ?? 0)
        assertReadable(layout, day: day)
    }

    func testVisibleHeightEndsWhereALaterBlockCoversTheEvent() {
        let day = testDay()
        let long = testEvent("Long", day: day, from: (9, 0), to: (12, 0))
        let inner = testEvent("Inner", day: day, from: (9, 30), to: (10, 0))
        let later = testEvent("Later", day: day, from: (11, 0), to: (11, 30))
        let separate = testEvent("Separate", day: day, from: (13, 0), to: (14, 0))

        let layout = layout(for: [long, inner, later, separate], day: day)

        // The first covering block counts; 30 minutes are 30 points here.
        XCTAssertEqual(layout[long.id]?.visibleHeight ?? 0, 30, accuracy: 0.001)
        XCTAssertNil(layout[inner.id]?.visibleHeight)
        XCTAssertNil(layout[later.id]?.visibleHeight)
        XCTAssertNil(layout[separate.id]?.visibleHeight)
    }

    func testSideBySideNeighboursDoNotShortenTheVisibleHeight() {
        let day = testDay()
        let left = testEvent("Left", day: day, from: (10, 0), to: (12, 0))
        let right = testEvent("Right", day: day, from: (10, 10), to: (12, 0))

        let layout = layout(for: [left, right], day: day)

        XCTAssertNil(layout[left.id]?.visibleHeight)
        XCTAssertNil(layout[right.id]?.visibleHeight)
    }

    func testCascadeStartsOneTitleBandBelowTheEarlierEvent() {
        let day = testDay()
        let first = testEvent("First", day: day, from: (9, 0), to: (10, 0))
        let cascaded = testEvent("Below", day: day, from: (9, 20), to: (9, 50))
        let sideBySide = testEvent("Side", day: day, from: (10, 0), to: (11, 0))
        let nearStart = testEvent("Near", day: day, from: (10, 15), to: (11, 0))

        let below = layout(for: [first, cascaded], day: day)
        XCTAssertEqual(below[cascaded.id]?.xFraction ?? 0, indentFraction, accuracy: 0.001, "20 minutes clears the title band")

        let near = layout(for: [sideBySide, nearStart], day: day)
        XCTAssertEqual(near[nearStart.id]?.xFraction ?? 0, 0.5, accuracy: 0.001, "15 minutes is inside the title band")
    }

    func testRowSplitsOverTheColumnsOfTheEventsItCovers() {
        let day = testDay()
        let parent = testEvent("Parent", day: day, from: (11, 0), to: (12, 0))
        let left = testEvent("Left", day: day, from: (11, 30), to: (12, 30))
        let right = testEvent("Right", day: day, from: (11, 30), to: (12, 30))
        let noon = ["Noon A", "Noon B", "Noon C"].map { testEvent($0, day: day, from: (12, 0), to: (13, 0)) }

        let layout = layout(for: [parent, left, right] + noon, day: day)

        XCTAssertEqual(layout[parent.id]?.widthFraction ?? 0, 1, accuracy: 0.001)
        let halfWidth = (1 - indentFraction) / 2
        XCTAssertEqual(layout[left.id]?.xFraction ?? 0, indentFraction, accuracy: 0.001)
        XCTAssertEqual(layout[left.id]?.widthFraction ?? 0, halfWidth, accuracy: 0.001)
        XCTAssertEqual(layout[right.id]?.xFraction ?? 0, indentFraction + halfWidth, accuracy: 0.001)

        // Each noon event goes over one of the 11:30 columns, never across
        // the left edge of the other one.
        let leftEdge = layout[left.id]?.xFraction ?? 0
        let rightEdge = layout[right.id]?.xFraction ?? 0
        for event in noon {
            let x = layout[event.id]?.xFraction ?? -1
            let maxX = x + (layout[event.id]?.widthFraction ?? 0)
            XCTAssertTrue(
                (x >= leftEdge + indentFraction - 0.001 && maxX <= rightEdge + 0.001) || x >= rightEdge + indentFraction - 0.001,
                "\(event.id) spans \(x) ..< \(maxX)"
            )
        }
        assertReadable(layout, day: day)
    }

    func testEventNeverCoversTheTitleOfAnEventStartingJustBefore() {
        let day = testDay()
        let first = testEvent("First", day: day, from: (9, 0), to: (12, 0))
        let second = testEvent("Second", day: day, from: (9, 15), to: (12, 0))
        let third = testEvent("Third", day: day, from: (9, 30), to: (10, 0))

        let layout = layout(for: [first, second, third], day: day)

        // 9:30 is clear of the 9:00 title but not of the 9:15 one, so it
        // goes over the first column only.
        XCTAssertEqual(layout[third.id]?.xFraction ?? 0, indentFraction, accuracy: 0.001)
        XCTAssertLessThanOrEqual(
            (layout[third.id]?.xFraction ?? 1) + (layout[third.id]?.widthFraction ?? 1),
            (layout[second.id]?.xFraction ?? 0) + 0.001
        )
        assertReadable(layout, day: day)
    }

    func testLaterEventReturnsToFullWidthAfterEarlierOverlapCluster() {
        let day = testDay()
        let first = testEvent("First", day: day, from: (9, 0), to: (9, 45))
        let second = testEvent("Second", day: day, from: (9, 5), to: (9, 25))
        let third = testEvent("Third", day: day, from: (10, 0), to: (10, 45))

        let layout = layout(for: [first, second, third], day: day)

        XCTAssertEqual(layout.count, 3)
        XCTAssertEqual(layout[third.id]?.xFraction ?? -1, 0, accuracy: 0.001)
        XCTAssertEqual(layout[third.id]?.widthFraction ?? 0, 1, accuracy: 0.001)
    }

    func testEventsTouchingBoundariesDoNotOverlap() {
        let day = testDay()
        let first = testEvent("First", day: day, from: (10, 0), to: (10, 30))
        let second = testEvent("Second", day: day, from: (10, 30), to: (11, 0))

        let layout = layout(for: [first, second], day: day)

        XCTAssertEqual(layout.count, 2)
        XCTAssertTrue(layout.allSatisfy { abs($0.xFraction) < 0.001 })
        XCTAssertTrue(layout.allSatisfy { $0.widthFraction > 0.999 })
    }

    func testShortEventsAreLaidOutAtTheirMinimumHeight() {
        let day = testDay()
        // Five minutes are drawn 20 points tall, so the 10:15 event starts
        // inside that block and has to sit next to it.
        let short = testEvent("Short", day: day, from: (10, 0), to: (10, 5))
        let next = testEvent("Next", day: day, from: (10, 15), to: (11, 0))

        let layout = layout(for: [short, next], day: day)

        XCTAssertEqual(layout[short.id]?.widthFraction ?? 0, 0.5, accuracy: 0.001)
        XCTAssertEqual(layout[next.id]?.xFraction ?? 0, 0.5, accuracy: 0.001)
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

        let first = layout(for: events, day: day)
        let second = layout(for: events.reversed(), day: day)

        for id in ["a", "b", "c"] {
            XCTAssertEqual(first[id]?.xFraction ?? -1, second[id]?.xFraction ?? -2, accuracy: 0.0001)
        }
        XCTAssertLessThan(first["a"]?.xFraction ?? 1, first["b"]?.xFraction ?? 0)
        XCTAssertLessThan(first["b"]?.xFraction ?? 1, first["c"]?.xFraction ?? 0)
    }

    /// The busy day compared with Apple Calendar, with neutral titles.
    func testBusyDayMatchesAppleCalendarArrangement() {
        let day = testDay()
        let events = busyDay(on: day)
        let width: CGFloat = 870
        let layout = EventLayoutCalculator.layout(
            for: events, on: day, containerWidth: width, hourHeight: hourHeight, calendar: calendar
        )
        let indent = configuration.staggerOffset / width

        XCTAssertEqual(layout.count, events.count)
        assertReadable(layout, day: day, containerWidth: width)

        // 9:00 starts inside 8:15: drawn over it, shifted right, out to the
        // column's edge.
        XCTAssertEqual(layout["0815"]?.widthFraction ?? 0, 1, accuracy: 0.001)
        XCTAssertEqual(layout["0900"]?.xFraction ?? 0, indent, accuracy: 0.001)
        XCTAssertEqual(layout["0900"]?.widthFraction ?? 0, 1 - indent, accuracy: 0.001)

        // Two at 10:00 take a half each.
        XCTAssertEqual(layout["1000a"]?.widthFraction ?? 0, 0.5, accuracy: 0.001)
        XCTAssertEqual(layout["1000b"]?.xFraction ?? 0, 0.5, accuracy: 0.001)

        // 11:00 is full width; both 11:30 events go over it side by side.
        XCTAssertEqual(layout["1100"]?.widthFraction ?? 0, 1, accuracy: 0.001)
        XCTAssertEqual(layout["1130a"]?.xFraction ?? 0, indent, accuracy: 0.001)
        XCTAssertEqual(layout["1130b"]?.xFraction ?? 0, indent + (1 - indent) / 2, accuracy: 0.001)

        // 13:30 goes over 13:00, both 14:00 events over 13:30.
        XCTAssertEqual(layout["1330"]?.xFraction ?? 0, indent, accuracy: 0.001)
        XCTAssertEqual(layout["1400a"]?.xFraction ?? 0, 2 * indent, accuracy: 0.001)
        XCTAssertEqual(layout["1400a"]?.overlapDepth, 2)

        // Four at 15:00 and one at 15:15: five equal columns.
        for (index, id) in ["1500a", "1500b", "1500c", "1500d", "1515"].enumerated() {
            XCTAssertEqual(layout[id]?.xFraction ?? -1, CGFloat(index) / 5, accuracy: 0.001, id)
            XCTAssertEqual(layout[id]?.widthFraction ?? 0, 0.2, accuracy: 0.001, id)
        }

        XCTAssertEqual(layout["1915"]?.xFraction ?? 0, indent, accuracy: 0.001)

        // Apple Calendar shows only the title where a later event covers the
        // block half an hour in; uncovered blocks keep their full height.
        for id in ["0815", "1100", "1130a", "1130b", "1300", "1330", "1830"] {
            XCTAssertNotNil(layout[id]?.visibleHeight, id)
        }
        XCTAssertEqual(layout["1100"]?.visibleHeight ?? 0, 30, accuracy: 0.001)
        XCTAssertEqual(layout["0815"]?.visibleHeight ?? 0, 45, accuracy: 0.001)
        for id in ["1000a", "1000b", "1200a", "1200b", "1200c", "1400a", "1500a", "1515", "1915"] {
            XCTAssertNil(layout[id]?.visibleHeight, id)
        }
    }

    func testRandomDaysStayReadable() {
        var generator = SeededGenerator(seed: 2026)
        let day = testDay()
        for width in [120 as CGFloat, 300, 870] {
            for _ in 0 ..< 200 {
                let count = Int.random(in: 1 ... 18, using: &generator)
                let events = (0 ..< count).map { index -> TestEvent in
                    let start = Int.random(in: 32 ... 76, using: &generator) * 15
                    let length = [10, 15, 30, 45, 60, 90, 120, 180].randomElement(using: &generator)!
                    return testEvent(
                        "e\(index)", day: day,
                        from: (start / 60, start % 60),
                        to: ((start + length) / 60, (start + length) % 60)
                    )
                }
                let layout = EventLayoutCalculator.layout(
                    for: events, on: day, containerWidth: width, hourHeight: hourHeight, calendar: calendar
                )
                XCTAssertEqual(layout.count, events.count)
                assertReadable(layout, day: day, containerWidth: width)
            }
        }
    }

    // MARK: - Helpers

    private func layout(for events: [TestEvent], day: Date) -> [EventLayout<TestEvent>] {
        EventLayoutCalculator.layout(
            for: events,
            on: day,
            containerWidth: containerWidth,
            hourHeight: hourHeight,
            calendar: calendar
        )
    }

    /// Checks the promise of the layout for every pair of blocks that
    /// overlap on screen: the one on top starts at least one title band
    /// lower and at least the stagger offset further right. Every block
    /// stays inside the column.
    private func assertReadable(
        _ layout: [EventLayout<TestEvent>],
        day: Date,
        containerWidth: CGFloat? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let width = containerWidth ?? self.containerWidth
        let startOfDay = calendar.startOfDay(for: day)
        let frames = layout.map { item -> (EventLayout<TestEvent>, CGRect) in
            let top = CGFloat(max(item.event.startDate, startOfDay).timeIntervalSince(startOfDay)) * hourHeight / 3600
            let height = max(
                CGFloat(item.event.endDate.timeIntervalSince(item.event.startDate)) * hourHeight / 3600,
                configuration.minEventHeight
            )
            return (item, CGRect(x: item.xFraction * width, y: top, width: item.widthFraction * width, height: height))
        }

        for (item, frame) in frames {
            XCTAssertGreaterThanOrEqual(frame.minX, -0.01, "\(item.id) leaves the column", file: file, line: line)
            XCTAssertLessThanOrEqual(frame.maxX, width + 0.01, "\(item.id) leaves the column", file: file, line: line)
            XCTAssertGreaterThan(frame.width, 0, "\(item.id) has no width", file: file, line: line)
        }

        for (firstIndex, (first, firstFrame)) in frames.enumerated() {
            for (second, secondFrame) in frames[(firstIndex + 1)...] {
                let overlapsVertically = firstFrame.minY < secondFrame.maxY && secondFrame.minY < firstFrame.maxY
                let overlapsHorizontally = firstFrame.minX < secondFrame.maxX - 0.01 && secondFrame.minX < firstFrame.maxX - 0.01
                guard overlapsVertically, overlapsHorizontally else { continue }

                let (lower, upper) = first.zIndexPriority < second.zIndexPriority
                    ? ((first, firstFrame), (second, secondFrame))
                    : ((second, secondFrame), (first, firstFrame))
                XCTAssertGreaterThanOrEqual(
                    upper.1.minY - lower.1.minY, configuration.titleHeight - 0.01,
                    "\(upper.0.id) covers the title of \(lower.0.id)", file: file, line: line
                )
                XCTAssertGreaterThanOrEqual(
                    upper.1.minX - lower.1.minX, configuration.staggerOffset - 0.01,
                    "\(upper.0.id) covers the left edge of \(lower.0.id)", file: file, line: line
                )
            }
        }
    }

    /// Start times and lengths of the day compared with Apple Calendar.
    private func busyDay(on day: Date) -> [TestEvent] {
        [
            ("0815", (8, 15), (9, 15)),
            ("0900", (9, 0), (10, 0)),
            ("1000a", (10, 0), (11, 0)),
            ("1000b", (10, 0), (11, 0)),
            ("1100", (11, 0), (12, 0)),
            ("1130a", (11, 30), (12, 30)),
            ("1130b", (11, 30), (12, 30)),
            ("1200a", (12, 0), (13, 0)),
            ("1200b", (12, 0), (13, 0)),
            ("1200c", (12, 0), (13, 0)),
            ("1300", (13, 0), (14, 0)),
            ("1330", (13, 30), (14, 30)),
            ("1400a", (14, 0), (15, 0)),
            ("1400b", (14, 0), (15, 0)),
            ("1500a", (15, 0), (16, 0)),
            ("1500b", (15, 0), (16, 0)),
            ("1500c", (15, 0), (16, 0)),
            ("1500d", (15, 0), (16, 0)),
            ("1515", (15, 15), (16, 15)),
            ("1830", (18, 30), (19, 30)),
            ("1915", (19, 15), (20, 15)),
            ("2350", (23, 50), (23, 59)),
        ].map { testEvent($0.0, day: day, from: $0.1, to: $0.2) }
    }
}

private extension Array where Element == EventLayout<TestEvent> {
    subscript(id: String) -> EventLayout<TestEvent>? {
        first { $0.id == id }
    }
}

/// A small deterministic generator, so the random days are the same on
/// every run.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state ^ (state >> 33)
    }
}
