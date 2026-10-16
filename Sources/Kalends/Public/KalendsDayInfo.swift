import Foundation

/// The host resolves production-calendar rules; Kalends renders the result.
public enum KalendsDayKind: String, CaseIterable, Sendable, Hashable {
    /// An ordinary working day, including an explicitly working weekend date.
    case working
    /// An ordinary Saturday or Sunday.
    case weekend
    /// A public holiday.
    case holiday
    /// A day off moved from another date.
    case transferredDayOff
    /// A working day moved from another date.
    case transferredWorking
}

/// Classification of a calendar date, independent of its events.
public struct KalendsDayInfo: Sendable, Hashable {
    /// The resolved kind takes precedence over the date's weekday.
    public var kind: KalendsDayKind
    /// Can accompany either kind of working day, including a working transfer.
    public var isShortened: Bool
    /// Optional host-supplied explanation for tooltips and accessibility.
    public var description: String?

    /// Creates the presentation of one date. No holiday rules are inferred.
    public init(kind: KalendsDayKind = .working, isShortened: Bool = false, description: String? = nil) {
        self.kind = kind
        self.isShortened = isShortened
        self.description = description
    }

    /// Working transfers remain working even when they fall on a weekend.
    public var isNonWorking: Bool {
        switch kind {
        case .weekend, .holiday, .transferredDayOff: true
        case .working, .transferredWorking: false
        }
    }

    /// Highlight switches change presentation without changing classification.
    public func shouldHighlight(weekends: Bool, holidays: Bool) -> Bool {
        switch kind {
        case .weekend: weekends
        case .holiday, .transferredDayOff: holidays
        case .working, .transferredWorking: false
        }
    }

    /// A localized explanation, available even when markers are switched off.
    public func localizedDescription(locale: Locale) -> String {
        if let description, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return description
        }
        var parts: [String] = []
        switch kind {
        case .working: break
        case .weekend: parts.append(KalendsText.string("Day off", locale: locale))
        case .holiday: parts.append(KalendsText.string("Public holiday", locale: locale))
        case .transferredDayOff: parts.append(KalendsText.string("Transferred day off", locale: locale))
        case .transferredWorking: parts.append(KalendsText.string("Working day due to a transfer", locale: locale))
        }
        if isShortened && !isNonWorking {
            parts.append(KalendsText.string("Shortened working day", locale: locale))
        }
        return parts.joined(separator: " · ")
    }

    /// Text complements color; compact calendars use `*` for shortened days.
    public func marker(
        weekends: Bool = true,
        holidays: Bool = true,
        workingDays: Bool = true,
        compact: Bool = false,
        locale: Locale = .current
    ) -> String {
        if shouldHighlight(weekends: weekends, holidays: holidays) {
            switch kind {
            case .weekend: return KalendsText.string(compact ? "O" : "Off", locale: locale)
            case .holiday: return KalendsText.string("H", locale: locale)
            case .transferredDayOff: return "↔"
            case .working, .transferredWorking: break
            }
        }
        guard workingDays && !isNonWorking else { return "" }
        var parts: [String] = []
        if kind == .transferredWorking {
            parts.append(KalendsText.string("W", locale: locale))
        }
        if isShortened {
            parts.append(compact ? "*" : KalendsText.string("−1h", locale: locale))
        }
        return parts.joined(separator: compact ? "" : " ")
    }
}
