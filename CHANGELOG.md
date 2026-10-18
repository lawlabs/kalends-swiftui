# Changelog

All notable changes to this project are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and the project adheres to [Semantic Versioning](https://semver.org).

## [Unreleased]

### Added

- Host-supplied `KalendsDayInfo` for holidays, weekends, transferred days off and working days; shortened status can accompany a working transfer.
- `.kalendsDays(_:)` shares classification, independent highlight/marker switches and Saturday/Sunday visibility across calendar views.
- Localized date markers, tooltips and accessibility descriptions in day, week, month, year and sidebar calendars. Compact calendars use `*` for shortened days.

### Changed

- `EventLayoutCalculator` lays out overlapping events like Apple Calendar. Events whose title bands overlap sit side by side and no longer overlap each other; a later event covers an earlier one only below its title and `staggerOffset` right of its left edge; each event takes the widest free space. `overlapDepth` is now the cascade level. `EventLayoutConfiguration` drops `horizontalSpacing` and now uses `minEventWidth` (16), `minEventHeight` (20) and `staggerOffset` (10).
- Event blocks are opaque, so a block drawn over another hides its text. A cascaded block has a thin rim, back-to-back events keep a 1-point gap.
- An event title wraps into the part of its block that no later block covers (`EventLayout.visibleHeight`); the time line is shown only when it fits there under one title line, so a covering block never cuts it in half, and in a narrow block it drops the clock, then the end time, then itself.
- Times on a 24-hour clock have two-digit hours (“08:15”), matching the hour labels.
- The day and week timelines keep the hour the user scrolled to. In `KalendsView` the two modes share it, so switching between them, or to the month and back, opens at the same time of day without scrolling there visibly; the first opening still goes to two hours before now (today) or 8:00.

### Fixed

- The day view's all-day section is as tall as its rows instead of always 100 points.
- An English `\.locale` gets English text when the process prefers another language. English is the source language and has no `.lproj`, so the lookup used to fall back to the process language.
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
