import SwiftUI

/// One resolved status supplies colors, markers and the spoken explanation.
struct DayPresentation {
    let info: KalendsDayInfo
    let configuration: KalendsDayConfiguration
    let locale: Locale

    var foreground: Color {
        if info.shouldHighlight(weekends: configuration.highlightWeekends, holidays: configuration.highlightHolidays) {
            return info.kind == .weekend ? .secondary : .red
        }
        if configuration.showWorkingDayMarkers && !info.isNonWorking && (info.kind == .transferredWorking || info.isShortened) {
            return .blue
        }
        return .primary
    }

    var background: Color {
        guard info.shouldHighlight(weekends: configuration.highlightWeekends, holidays: configuration.highlightHolidays) else {
            return .clear
        }
        return info.kind == .weekend ? Color.secondary.opacity(0.07) : Color.red.opacity(0.08)
    }

    func marker(compact: Bool = false) -> String {
        info.marker(
            weekends: configuration.highlightWeekends,
            holidays: configuration.highlightHolidays,
            workingDays: configuration.showWorkingDayMarkers,
            compact: compact,
            locale: locale
        )
    }
}

extension KalendsDayConfiguration {
    @MainActor
    func presentation(for date: Date, calendar: Calendar, locale: Locale) -> DayPresentation {
        DayPresentation(info: info(for: date, calendar: calendar), configuration: self, locale: locale)
    }
}

struct DayBackground: View {
    let date: Date
    @Environment(\.kalendsDays) private var configuration
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    var body: some View {
        configuration.presentation(for: date, calendar: calendar, locale: locale).background
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

struct DayMarker: View {
    let date: Date
    var compact = false
    @Environment(\.kalendsDays) private var configuration
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    var body: some View {
        let presentation = configuration.presentation(for: date, calendar: calendar, locale: locale)
        Text(presentation.marker(compact: compact))
            .font(.system(size: compact ? 7 : 10, weight: .semibold))
            .foregroundColor(presentation.foreground)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            // The parent exposes the full description instead of abbreviations.
            .accessibilityHidden(true)
    }
}

private struct DayDetails: ViewModifier {
    let date: Date
    @Environment(\.kalendsDays) private var configuration
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    func body(content: Content) -> some View {
        let description = configuration.info(for: date, calendar: calendar).localizedDescription(locale: locale)
        let dateText = date.formatted(Date.FormatStyle(
            date: .complete, time: .omitted, locale: locale, calendar: calendar, timeZone: calendar.timeZone
        ))
        content
            .help(description.isEmpty ? dateText : "\(dateText)\n\(description)")
            .accessibilityValue(description)
    }
}

extension View {
    func kalendsDayDetails(_ date: Date) -> some View {
        modifier(DayDetails(date: date))
    }
}
