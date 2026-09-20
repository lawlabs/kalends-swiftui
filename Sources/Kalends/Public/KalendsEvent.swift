import SwiftUI

/// An event drawn by Kalends.
///
/// The host application owns storage, synchronization and editing; Kalends
/// only needs what it draws. Conform your own model directly or map it to a
/// small display value, and resolve the original record by `id` in the
/// ``KalendsActions`` callbacks.
///
/// `endDate` is exclusive, including for all-day events: an all-day event on
/// one day starts at midnight and ends at the next midnight.
public protocol KalendsEvent: Identifiable, Hashable, Sendable {
    var title: String { get }
    var startDate: Date { get }
    var endDate: Date { get }
    var isAllDay: Bool { get }
    /// The calendar color; Kalends derives fills, accents and text color from it.
    var color: Color { get }
    /// Read-only events are shown but cannot be moved or resized.
    var isReadOnly: Bool { get }
    /// A secondary line (location, participants…) shown where space allows.
    var subtitle: String? { get }
}

public extension KalendsEvent {
    var isReadOnly: Bool { false }
    var subtitle: String? { nil }
}
