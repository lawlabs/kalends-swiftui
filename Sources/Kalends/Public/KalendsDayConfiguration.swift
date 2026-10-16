import SwiftUI

/// A fast synchronous lookup in host-owned data. The date is the start of a
/// day in the view's calendar. Return `nil` for the Saturday/Sunday fallback.
public typealias KalendsDayInfoProvider = @MainActor @Sendable (Date) -> KalendsDayInfo?

/// Shared day presentation for every calendar under ``View/kalendsDays(_:)``.
///
/// No country-specific dataset, networking or persistence is built in.
public struct KalendsDayConfiguration: Sendable {
    /// Shows Saturday/Sunday columns in week/month and the compact day strip.
    /// Year and sidebar calendars always retain all seven days for navigation.
    public var showWeekends: Bool
    /// Highlights ordinary weekends independently of their visibility.
    public var highlightWeekends: Bool
    /// Highlights public holidays and transferred days off.
    public var highlightHolidays: Bool
    /// Shows working-transfer and shortened-day markers independently of holidays.
    public var showWorkingDayMarkers: Bool
    /// Resolve dates from in-memory host data; changing observable data redraws views.
    public var dayInfoProvider: KalendsDayInfoProvider?

    /// All dates, highlights and markers are enabled by default.
    public init(
        showWeekends: Bool = true,
        highlightWeekends: Bool = true,
        highlightHolidays: Bool = true,
        showWorkingDayMarkers: Bool = true,
        dayInfoProvider: KalendsDayInfoProvider? = nil
    ) {
        self.showWeekends = showWeekends
        self.highlightWeekends = highlightWeekends
        self.highlightHolidays = highlightHolidays
        self.showWorkingDayMarkers = showWorkingDayMarkers
        self.dayInfoProvider = dayInfoProvider
    }

    /// Resolves a date once, preferring explicit host data over weekday rules.
    @MainActor
    public func info(for date: Date, calendar: Calendar) -> KalendsDayInfo {
        let day = calendar.startOfDay(for: date)
        if let info = dayInfoProvider?(day) { return info }
        let weekday = calendar.component(.weekday, from: day)
        return KalendsDayInfo(kind: weekday == 1 || weekday == 7 ? .weekend : .working)
    }
}

private struct KalendsDayConfigurationKey: EnvironmentKey {
    static let defaultValue = KalendsDayConfiguration()
}

extension EnvironmentValues {
    var kalendsDays: KalendsDayConfiguration {
        get { self[KalendsDayConfigurationKey.self] }
        set { self[KalendsDayConfigurationKey.self] = newValue }
    }
}

public extension View {
    /// Applies day classification and display options to all descendant Kalends
    /// views, including views used individually and ``MiniCalendarView``.
    func kalendsDays(_ configuration: KalendsDayConfiguration) -> some View {
        environment(\.kalendsDays, configuration)
    }
}
