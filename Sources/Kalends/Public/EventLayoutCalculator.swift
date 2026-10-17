import Foundation

/// Tunables of the day-column layout, in points.
public struct EventLayoutConfiguration: Sendable, Hashable {
    /// Height of the title band at the top of a block. Events whose title
    /// bands overlap are placed side by side; a later event is drawn over an
    /// earlier one only below that event's title band.
    public var titleHeight: CGFloat
    /// Narrowest space an event is placed in; narrower gaps are skipped.
    public var minEventWidth: CGFloat
    /// Height of the shortest block. Shorter events are drawn this tall, so
    /// the layout treats them as this tall too.
    public var minEventHeight: CGFloat
    /// How far right of an earlier event's left edge a later event drawn over
    /// it starts, so that edge and its accent bar stay visible.
    public var staggerOffset: CGFloat

    public init(
        titleHeight: CGFloat = 20,
        minEventWidth: CGFloat = 16,
        minEventHeight: CGFloat = 20,
        staggerOffset: CGFloat = 10
    ) {
        self.titleHeight = titleHeight
        self.minEventWidth = minEventWidth
        self.minEventHeight = minEventHeight
        self.staggerOffset = staggerOffset
    }
}

/// Where one event goes inside a day column. Horizontal values are fractions
/// of the column width, so the result is independent of the actual size.
public struct EventLayout<Event: KalendsEvent>: Identifiable, Hashable {
    public let event: Event
    public let xFraction: CGFloat
    public let widthFraction: CGFloat
    /// Cascade level: 0 when nothing is under this block, otherwise one more
    /// than the deepest block it is drawn over.
    public let overlapDepth: Int
    /// How many events share this block's title band side by side, itself
    /// included.
    public let overlapStackCount: Int
    /// Draw order; later starts and deeper cascade levels go on top.
    public let zIndexPriority: Double
    /// Height in points of the block's top part that no later block covers,
    /// or `nil` when nothing covers it. Lay the block's text out within this
    /// part, as Apple Calendar does, so a covering block never cuts a line
    /// in half: a short visible part shows the title without the time.
    public let visibleHeight: CGFloat?

    public var id: Event.ID { event.id }
}

/// Lays out the timed events of one day the way Apple Calendar does:
///
/// - Events whose title bands overlap sit side by side and never cover each
///   other.
/// - A later event may cover the body of an earlier one, below its title
///   band, starting ``EventLayoutConfiguration/staggerOffset`` right of its
///   left edge. No block ever crosses the left edge of a block under it, so
///   every title and accent bar stays visible.
/// - Within these rules each event takes the widest space it can.
///
/// Events are placed in rows, earliest first: a row is an event together
/// with the events starting within one title band of it. A row never moves
/// the rows above it, so filling the afternoon does not reshuffle the
/// morning.
public enum EventLayoutCalculator {
    public static func layout<Event: KalendsEvent>(
        for events: [Event],
        on day: Date,
        containerWidth: CGFloat,
        hourHeight: CGFloat,
        configuration: EventLayoutConfiguration = EventLayoutConfiguration(),
        calendar: Calendar = .current
    ) -> [EventLayout<Event>] {
        let timedEvents = events.filter { !$0.isAllDay }

        guard !timedEvents.isEmpty, containerWidth > 0, hourHeight > 0 else {
            return []
        }

        let startOfDay = calendar.startOfDay(for: day)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return timedEvents.map {
                EventLayout(
                    event: $0,
                    xFraction: 0,
                    widthFraction: 1,
                    overlapDepth: 0,
                    overlapStackCount: 1,
                    zIndexPriority: zIndexPriority(for: $0, startOfDay: startOfDay),
                    visibleHeight: nil
                )
            }
        }

        let pointsPerSecond = hourHeight / 3600
        let blocks = timedEvents.compactMap { event -> Block<Event>? in
            guard let interval = displayInterval(for: event, startOfDay: startOfDay, endOfDay: endOfDay) else {
                return nil
            }
            let top = CGFloat(interval.start.timeIntervalSince(startOfDay)) * pointsPerSecond
            let height = max(CGFloat(interval.duration) * pointsPerSecond, configuration.minEventHeight)
            return Block(
                event: event,
                top: top,
                bottom: top + height,
                duration: interval.duration,
                zIndexPriority: zIndexPriority(for: event, startOfDay: startOfDay)
            )
        }.sorted(by: blockOrder)

        var placements: [Placement<Event>] = []
        var rowStart = 0
        while rowStart < blocks.count {
            var rowEnd = rowStart + 1
            while rowEnd < blocks.count,
                  blocks[rowEnd].top - blocks[rowStart].top < configuration.titleHeight {
                rowEnd += 1
            }
            placements += placeRow(
                blocks[rowStart ..< rowEnd],
                over: placements,
                width: containerWidth,
                configuration: configuration
            )
            rowStart = rowEnd
        }

        return placements.enumerated().map { index, placement in
            // Placements run row by row, so a block can only be covered by
            // one placed after it, from a lower row.
            let coveringTops = placements[(index + 1)...]
                .filter {
                    $0.block.top > placement.block.top &&
                        $0.block.top < placement.block.bottom &&
                        $0.overlapsHorizontally(placement)
                }
                .map(\.block.top)
            return EventLayout(
                event: placement.block.event,
                xFraction: placement.x / containerWidth,
                widthFraction: placement.width / containerWidth,
                overlapDepth: placement.depth,
                overlapStackCount: placement.rowCount,
                zIndexPriority: placement.block.zIndexPriority + Double(placement.depth) * 0.001,
                visibleHeight: coveringTops.min().map { $0 - placement.block.top }
            )
        }
    }

    /// Base z-index of an event in its day column: seconds since the start
    /// of the day.
    ///
    /// The value stays below one day (< 86 400) so a view can lift the block
    /// being dragged above every other one with a constant of a larger order.
    public static func zIndexPriority<Event: KalendsEvent>(
        for event: Event,
        on day: Date,
        calendar: Calendar = .current
    ) -> Double {
        zIndexPriority(for: event, startOfDay: calendar.startOfDay(for: day))
    }
}

private extension EventLayoutCalculator {
    /// An event's vertical extent in the column, in points from midnight.
    struct Block<Event: KalendsEvent> {
        let event: Event
        let top: CGFloat
        let bottom: CGFloat
        let duration: TimeInterval
        let zIndexPriority: Double
    }

    struct Placement<Event: KalendsEvent> {
        let block: Block<Event>
        let x: CGFloat
        let width: CGFloat
        let depth: Int
        let rowCount: Int

        func overlapsHorizontally(_ other: Placement<Event>) -> Bool {
            x < other.x + other.width - EventLayoutCalculator.tolerance && other.x < x + width - EventLayoutCalculator.tolerance
        }
    }

    /// A horizontal span a row may use.
    struct Slot {
        let x: CGFloat
        let width: CGFloat
    }

    /// Positions are compared with this margin so rounding never splits a
    /// slot or breaks a tie.
    static var tolerance: CGFloat { 0.01 }

    static func displayInterval<Event: KalendsEvent>(
        for event: Event,
        startOfDay: Date,
        endOfDay: Date
    ) -> DateInterval? {
        let clampedStart = max(event.startDate, startOfDay)
        let clampedEnd = min(event.endDate, endOfDay)
        guard clampedEnd > clampedStart else {
            return nil
        }
        return DateInterval(start: clampedStart, end: clampedEnd)
    }

    static func zIndexPriority<Event: KalendsEvent>(for event: Event, startOfDay: Date) -> Double {
        max(0, event.startDate.timeIntervalSince(startOfDay))
    }

    /// Earlier start first, then longer duration, then a stable tie-break on
    /// the identifier so the layout never flickers between runs.
    static func blockOrder<Event: KalendsEvent>(_ first: Block<Event>, _ second: Block<Event>) -> Bool {
        if first.top != second.top {
            return first.top < second.top
        }
        if first.duration != second.duration {
            return first.duration > second.duration
        }
        return String(describing: first.event.id) < String(describing: second.event.id)
    }

    /// Places one row against the blocks already placed above it.
    static func placeRow<Event: KalendsEvent>(
        _ row: ArraySlice<Block<Event>>,
        over placed: [Placement<Event>],
        width: CGFloat,
        configuration: EventLayoutConfiguration
    ) -> [Placement<Event>] {
        guard let rowTop = row.first?.top else { return [] }

        // Every placed block starts at or above the row, so it reaches the
        // row exactly when it ends below the row's top.
        let underneath = placed.filter { $0.block.bottom > rowTop }
        // A block whose title band reaches the row must not be covered at
        // all; the rest may be covered below their titles.
        let blocking = underneath.filter { rowTop - $0.block.top < configuration.titleHeight }
        let covered = underneath.filter { rowTop - $0.block.top >= configuration.titleHeight }

        var slots = freeSlots(
            width: width,
            blocking: blocking,
            covered: covered,
            staggerOffset: configuration.staggerOffset,
            minimumWidth: configuration.minEventWidth
        )
        if slots.isEmpty {
            // A crowded narrow column: covering a title is better than
            // dropping the event.
            slots = freeSlots(
                width: width,
                blocking: [],
                covered: underneath,
                staggerOffset: configuration.staggerOffset,
                minimumWidth: 1
            )
        }
        if slots.isEmpty {
            slots = [Slot(x: 0, width: width)]
        }

        // Each event takes the slot that leaves it the most width; a tie
        // goes to the leftmost slot.
        var members = Array(repeating: [Block<Event>](), count: slots.count)
        for block in row {
            var best = 0
            var bestShare = -CGFloat.infinity
            for (index, slot) in slots.enumerated() {
                let share = slot.width / CGFloat(members[index].count + 1)
                if share > bestShare + tolerance {
                    best = index
                    bestShare = share
                }
            }
            members[best].append(block)
        }

        var result: [Placement<Event>] = []
        for (slot, blocks) in zip(slots, members) where !blocks.isEmpty {
            let share = slot.width / CGFloat(blocks.count)
            for (index, block) in blocks.enumerated() {
                let candidate = Placement(
                    block: block,
                    x: slot.x + share * CGFloat(index),
                    width: share,
                    depth: 0,
                    rowCount: row.count
                )
                let depth = underneath
                    .filter { $0.block.bottom > block.top && candidate.overlapsHorizontally($0) }
                    .map { $0.depth + 1 }
                    .max() ?? 0
                result.append(Placement(
                    block: block,
                    x: candidate.x,
                    width: candidate.width,
                    depth: depth,
                    rowCount: row.count
                ))
            }
        }
        return result
    }

    /// The spans of `0 ..< width` a row may use: outside every blocking
    /// block, and never across the left edge of a covered one. A span that
    /// starts at such an edge is shifted right by `staggerOffset`.
    static func freeSlots<Event: KalendsEvent>(
        width: CGFloat,
        blocking: [Placement<Event>],
        covered: [Placement<Event>],
        staggerOffset: CGFloat,
        minimumWidth: CGFloat
    ) -> [Slot] {
        let edges = ([0, width] + covered.map(\.x) + blocking.flatMap { [$0.x, $0.x + $0.width] })
            .map { min(max($0, 0), width) }
            .sorted()
        var uniqueEdges: [CGFloat] = []
        for edge in edges where uniqueEdges.last.map({ edge - $0 > tolerance }) ?? true {
            uniqueEdges.append(edge)
        }

        var slots: [Slot] = []
        for (left, right) in zip(uniqueEdges, uniqueEdges.dropFirst()) {
            let isBlocked = blocking.contains { $0.x < right - tolerance && $0.x + $0.width > left + tolerance }
            guard !isBlocked else { continue }

            let coversLeftEdge = covered.contains { abs($0.x - left) <= tolerance }
            let inset = coversLeftEdge ? staggerOffset : 0
            let slotWidth = right - left - inset
            guard slotWidth >= minimumWidth else { continue }
            slots.append(Slot(x: left + inset, width: slotWidth))
        }
        return slots
    }
}
