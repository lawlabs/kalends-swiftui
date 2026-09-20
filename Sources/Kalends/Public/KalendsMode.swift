import Foundation

/// The four calendar views, for hosts that switch between them with one control.
public enum KalendsMode: String, CaseIterable, Sendable, Hashable {
    case day
    case week
    case month
    case year
}

/// Layout of ``DayView``.
public enum DayViewStyle: Sendable, Hashable {
    /// `.compact` on iOS, `.regular` on macOS.
    case automatic
    /// A week strip above the timeline, for phones and tablets.
    case compact
    /// Date header and timeline only.
    case regular
}

/// Layout of ``MonthView``.
public enum MonthViewStyle: Sendable, Hashable {
    /// `.compact` on iOS, `.detailed` on macOS.
    case automatic
    /// Tall day cells with colored bars per event, for touch.
    case compact
    /// Day cells listing event titles with a “more” popover, for desktop.
    case detailed
}

/// Layout of ``YearView``.
public enum YearViewStyle: Sendable, Hashable {
    /// `.compact` on iOS, `.cards` on macOS.
    case automatic
    /// Twelve plain mini months under a large year title.
    case compact
    /// Twelve mini months on cards.
    case cards
}
