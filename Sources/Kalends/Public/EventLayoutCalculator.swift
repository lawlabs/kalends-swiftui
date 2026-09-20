import Foundation

/// Tunables of the day-column layout, in points.
public struct EventLayoutConfiguration: Sendable, Hashable {
    /// Gap between the blocks of side-by-side events.
    public var horizontalSpacing: CGFloat
    /// Height of the title band at the top of a block; blocks whose title
    /// bands overlap are laid out side by side rather than cascaded.
    public var titleHeight: CGFloat
    public var minEventWidth: CGFloat
    public var minEventHeight: CGFloat
    /// Horizontal shift of each further level of a cascade.
    public var staggerOffset: CGFloat

    public init(
        horizontalSpacing: CGFloat = 1,
        titleHeight: CGFloat = 20,
        minEventWidth: CGFloat = 4,
        minEventHeight: CGFloat = 16,
        staggerOffset: CGFloat = 8
    ) {
        self.horizontalSpacing = horizontalSpacing
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
    /// How many overlapping events sit “under” this one.
    public let overlapDepth: Int
    /// Size of the largest overlap group this event belongs to.
    public let overlapStackCount: Int
    /// Draw order; later starts and deeper cascade levels go on top.
    public let zIndexPriority: Double

    public var id: Event.ID { event.id }
}

/// Lays out the timed events of one day: events whose title bands overlap
/// share the width side by side; an event starting inside the body of a
/// longer one is cascaded — narrower and shifted right — so both titles stay
/// visible.
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
                    zIndexPriority: zIndexPriority(for: $0, startOfDay: startOfDay)
                )
            }
        }

        let pointsPerSecond = hourHeight / 3600
        let titleHeightInSeconds = TimeInterval(configuration.titleHeight / pointsPerSecond)

        let descriptors = timedEvents.compactMap { event -> EventDescriptor<Event>? in
            guard let interval = displayInterval(for: event, startOfDay: startOfDay, endOfDay: endOfDay) else {
                return nil
            }
            let headerEnd = min(interval.end, interval.start.addingTimeInterval(titleHeightInSeconds))
            let headerInterval = DateInterval(start: interval.start, end: max(headerEnd, interval.start.addingTimeInterval(1)))

            return EventDescriptor(
                event: event,
                interval: interval,
                headerInterval: headerInterval,
                zIndexPriority: zIndexPriority(for: event, startOfDay: startOfDay)
            )
        }

        guard !descriptors.isEmpty else { return [] }

        let metricsByEvent = calculateHeaderStackMetrics(
            for: descriptors,
            titleHeightInSeconds: titleHeightInSeconds
        )
        let bodyMetricsByEvent = calculateBodyStackMetrics(for: descriptors)

        return descriptors.map { descriptor in
            let headerMetrics = metricsByEvent[descriptor.event.id] ?? EventStackMetrics()
            let bodyMetrics = bodyMetricsByEvent[descriptor.event.id] ?? EventStackMetrics()
            let resolvedMetrics = resolveMetrics(header: headerMetrics, body: bodyMetrics)
            let resolvedWidthFraction: CGFloat
            let resolvedXFraction: CGFloat

            if headerMetrics.maxStackCount > 1 {
                resolvedWidthFraction = widthFraction(
                    forStackCount: headerMetrics.maxStackCount,
                    containerWidth: containerWidth,
                    configuration: configuration
                )
                let maximumOriginFraction = max(1 - resolvedWidthFraction, 0)
                resolvedXFraction = xFraction(
                    forDepth: headerMetrics.depth,
                    stackCount: headerMetrics.maxStackCount,
                    maximumOriginFraction: maximumOriginFraction,
                    containerWidth: containerWidth,
                    configuration: configuration
                )
            } else if bodyMetrics.depth > 0 {
                resolvedWidthFraction = bodyRevealWidthFraction(
                    forStackCount: bodyMetrics.maxStackCount,
                    containerWidth: containerWidth,
                    configuration: configuration
                )
                let maximumOriginFraction = max(1 - resolvedWidthFraction, 0)
                resolvedXFraction = bodyRevealXFraction(
                    forDepth: bodyMetrics.depth,
                    stackCount: bodyMetrics.maxStackCount,
                    maximumOriginFraction: maximumOriginFraction,
                    containerWidth: containerWidth,
                    configuration: configuration
                )
            } else {
                resolvedWidthFraction = 1
                resolvedXFraction = 0
            }

            return EventLayout(
                event: descriptor.event,
                xFraction: resolvedXFraction,
                widthFraction: resolvedWidthFraction,
                overlapDepth: resolvedMetrics.depth,
                overlapStackCount: resolvedMetrics.maxStackCount,
                zIndexPriority: descriptor.zIndexPriority + Double(resolvedMetrics.depth) * 0.001
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
    struct EventDescriptor<Event: KalendsEvent> {
        let event: Event
        let interval: DateInterval
        let headerInterval: DateInterval
        let zIndexPriority: Double
    }

    struct EventStackMetrics {
        var depth: Int = 0
        var maxStackCount: Int = 1
    }

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

    static func calculateHeaderStackMetrics<Event: KalendsEvent>(
        for descriptors: [EventDescriptor<Event>],
        titleHeightInSeconds: TimeInterval
    ) -> [Event.ID: EventStackMetrics] {
        let boundaries = Array(
            Set(
                descriptors.flatMap { descriptor in
                    [
                        descriptor.headerInterval.start.timeIntervalSinceReferenceDate,
                        descriptor.headerInterval.end.timeIntervalSinceReferenceDate,
                    ]
                }
            )
        ).sorted()

        guard boundaries.count >= 2 else {
            return Dictionary(uniqueKeysWithValues: descriptors.map { ($0.event.id, EventStackMetrics()) })
        }

        var result: [Event.ID: EventStackMetrics] = [:]
        for descriptor in descriptors {
            result[descriptor.event.id] = EventStackMetrics()
        }

        for index in 0 ..< (boundaries.count - 1) {
            let sliceStart = Date(timeIntervalSinceReferenceDate: boundaries[index])
            let sliceEnd = Date(timeIntervalSinceReferenceDate: boundaries[index + 1])
            guard sliceEnd > sliceStart else { continue }

            let active = descriptors.filter { descriptor in
                descriptor.headerInterval.start < sliceEnd && descriptor.headerInterval.end > sliceStart
            }.sorted(by: descriptorPriority)

            guard active.count > 1 else { continue }

            for (depth, descriptor) in active.enumerated() {
                var metrics = result[descriptor.event.id] ?? EventStackMetrics()
                metrics.depth = max(metrics.depth, depth)
                metrics.maxStackCount = max(metrics.maxStackCount, active.count)
                result[descriptor.event.id] = metrics
            }
        }

        let nearbyGroups = groupedByHeaderProximity(descriptors, titleHeightInSeconds: titleHeightInSeconds)
        for group in nearbyGroups where group.count > 1 {
            let sortedGroup = group.sorted(by: descriptorPriority)
            for (depth, descriptor) in sortedGroup.enumerated() {
                var metrics = result[descriptor.event.id] ?? EventStackMetrics()
                metrics.depth = max(metrics.depth, depth)
                metrics.maxStackCount = max(metrics.maxStackCount, group.count)
                result[descriptor.event.id] = metrics
            }
        }

        return result
    }

    static func calculateBodyStackMetrics<Event: KalendsEvent>(
        for descriptors: [EventDescriptor<Event>]
    ) -> [Event.ID: EventStackMetrics] {
        let sorted = descriptors.sorted(by: descriptorPriority)
        var result = Dictionary(uniqueKeysWithValues: sorted.map { ($0.event.id, EventStackMetrics()) })

        for descriptor in sorted {
            let activeAtStart = sorted.filter { other in
                other.interval.start <= descriptor.interval.start &&
                    other.interval.end > descriptor.interval.start
            }

            guard activeAtStart.count > 1 else { continue }

            let orderedActive = activeAtStart.sorted(by: descriptorPriority)
            guard let depth = orderedActive.firstIndex(where: { $0.event.id == descriptor.event.id }) else {
                continue
            }

            var metrics = result[descriptor.event.id] ?? EventStackMetrics()
            metrics.depth = max(metrics.depth, depth)
            metrics.maxStackCount = max(metrics.maxStackCount, activeAtStart.count)
            result[descriptor.event.id] = metrics
        }

        return result
    }

    static func groupedByHeaderProximity<Event: KalendsEvent>(
        _ descriptors: [EventDescriptor<Event>],
        titleHeightInSeconds: TimeInterval
    ) -> [[EventDescriptor<Event>]] {
        let sorted = descriptors.sorted(by: descriptorPriority)
        var groups: [[EventDescriptor<Event>]] = []
        var currentGroup: [EventDescriptor<Event>] = []
        var currentGroupEnd: Date = .distantPast

        for descriptor in sorted {
            if currentGroup.isEmpty {
                currentGroup = [descriptor]
                currentGroupEnd = descriptor.headerInterval.end
                continue
            }

            let delta = descriptor.interval.start.timeIntervalSince(currentGroup[0].interval.start)
            if descriptor.headerInterval.start < currentGroupEnd || delta < titleHeightInSeconds {
                currentGroup.append(descriptor)
                currentGroupEnd = max(currentGroupEnd, descriptor.headerInterval.end)
            } else {
                groups.append(currentGroup)
                currentGroup = [descriptor]
                currentGroupEnd = descriptor.headerInterval.end
            }
        }

        if !currentGroup.isEmpty {
            groups.append(currentGroup)
        }

        return groups
    }

    /// Earlier start first, then longer duration, then a stable tie-break on
    /// the identifier so the layout never flickers between runs.
    static func descriptorPriority<Event: KalendsEvent>(
        _ first: EventDescriptor<Event>,
        _ second: EventDescriptor<Event>
    ) -> Bool {
        if first.interval.start == second.interval.start {
            if first.interval.duration == second.interval.duration {
                return String(describing: first.event.id) < String(describing: second.event.id)
            }
            return first.interval.duration > second.interval.duration
        }
        return first.interval.start < second.interval.start
    }

    static func widthFraction(
        forStackCount stackCount: Int,
        containerWidth: CGFloat,
        configuration: EventLayoutConfiguration
    ) -> CGFloat {
        guard stackCount > 1 else { return 1 }

        let preferredFraction: CGFloat
        switch stackCount {
        case 2:
            preferredFraction = 0.58
        case 3:
            preferredFraction = 0.46
        default:
            preferredFraction = max(0.34, 1 / CGFloat(stackCount))
        }

        let minimumFraction = configuration.minEventWidth / max(containerWidth, 1)
        let spacingFraction = configuration.horizontalSpacing / max(containerWidth, 1)
        return min(max(preferredFraction - spacingFraction, minimumFraction), 1)
    }

    static func bodyRevealWidthFraction(
        forStackCount stackCount: Int,
        containerWidth: CGFloat,
        configuration: EventLayoutConfiguration
    ) -> CGFloat {
        guard stackCount > 1 else { return 1 }

        let preferredFraction: CGFloat
        switch stackCount {
        case 2:
            preferredFraction = 0.92
        case 3:
            preferredFraction = 0.86
        default:
            preferredFraction = max(0.78, 1 - 0.06 * CGFloat(stackCount - 1))
        }

        let minimumFraction = configuration.minEventWidth / max(containerWidth, 1)
        let spacingFraction = configuration.horizontalSpacing / max(containerWidth, 1)
        return min(max(preferredFraction - spacingFraction, minimumFraction), 1)
    }

    static func xFraction(
        forDepth depth: Int,
        stackCount: Int,
        maximumOriginFraction: CGFloat,
        containerWidth: CGFloat,
        configuration: EventLayoutConfiguration
    ) -> CGFloat {
        guard stackCount > 1, depth > 0 else { return 0 }

        let staggerFraction = configuration.staggerOffset / max(containerWidth, 1)
        let evenlyDistributedFraction = maximumOriginFraction / CGFloat(stackCount - 1)
        let stepFraction = max(evenlyDistributedFraction, staggerFraction)
        return min(CGFloat(depth) * stepFraction, maximumOriginFraction)
    }

    static func bodyRevealXFraction(
        forDepth depth: Int,
        stackCount: Int,
        maximumOriginFraction: CGFloat,
        containerWidth: CGFloat,
        configuration: EventLayoutConfiguration
    ) -> CGFloat {
        guard stackCount > 1, depth > 0 else { return 0 }

        let baseStepFraction = max((configuration.staggerOffset * 1.25) / max(containerWidth, 1), 0.04)
        let depthMultiplier: CGFloat
        switch depth {
        case 1:
            depthMultiplier = 1
        case 2:
            depthMultiplier = 1.7
        default:
            depthMultiplier = 2.2 + CGFloat(max(depth - 3, 0)) * 0.35
        }

        return min(baseStepFraction * depthMultiplier, maximumOriginFraction)
    }

    static func resolveMetrics(header: EventStackMetrics, body: EventStackMetrics) -> EventStackMetrics {
        EventStackMetrics(
            depth: max(header.depth, body.depth),
            maxStackCount: max(header.maxStackCount, body.maxStackCount)
        )
    }
}
