# Changelog

All notable changes to this project are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and the project adheres to [Semantic Versioning](https://semver.org).

## [Unreleased]

### Added

- Host-supplied `KalendsDayInfo` for holidays, weekends, transferred days off and working days; shortened status can accompany a working transfer.
- `.kalendsDays(_:)` shares classification, independent highlight/marker switches and Saturday/Sunday visibility across calendar views.
- Localized date markers, tooltips and accessibility descriptions in day, week, month, year and sidebar calendars. Compact calendars use `*` for shortened days.

### Fixed

- Day and Week all-day backgrounds align with their hourly columns.
- Hidden weekend columns preserve month/header alignment and horizontal event dragging follows the visible week dates.

## [0.1.0] - 2026-09-20

### Added

- `DayView`, `WeekView`, `MonthView`, `YearView` and the `KalendsView` mode switcher.
- `MiniCalendarView` for sidebar navigation.
- Drag to move (in time and across days in the week view), edge drag to resize, 15-minute snapping, live time badge.
- Double tap on empty grid to create an event, drag on empty grid to draw a draft.
- `EventLayoutCalculator`: side-by-side placement for events whose title bands overlap, cascaded placement for events starting inside a longer one.
- `KalendsEvent`, `KalendsDataSource`, `KalendsActions` — the host keeps its own model, storage and editing.
- `KalendsEventStore`, an in-memory data source for samples and previews.
- Compact (touch) and detailed/cards (desktop) styles for the month and year views, chosen automatically per platform.
- Localized text (English, Russian) resolved against the SwiftUI `\.locale`, so a host that pins its locale gets matching calendar text.
- Example app with the same sample week as the Kalends.WinUI sample and `-mode`, `-date`, `-colorScheme` launch arguments.

### Known limitations

- Views take day boundaries and the first weekday from the `\.calendar` environment, but date text is formatted with the locale's default calendar and time zone; a custom time zone in `\.calendar` moves the grid, not the labels.
- No customization points for cells and headers yet; styles and metrics are fixed except for `hourHeight`.
- Events longer than a day are shown on each day they cover but are not drawn as spanning bars in the month view.
