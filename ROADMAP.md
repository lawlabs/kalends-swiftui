# Roadmap

What is still missing or unaligned, in rough priority order. Items marked
**parity** concern the match between this package and
[Kalends.WinUI](https://github.com/lawlabs/kalends-winui); the two libraries
should behave the same on both platforms and be documented the same way.

## 1. Parity with Kalends.WinUI

- **Layout algorithm (blocking for shared fixtures).** WinUI lays out
  overlapping events in equal lanes (`EventLane`: `lane`, `laneCount`); Swift
  follows Apple Calendar: events whose title bands overlap sit side by side,
  an event starting inside a longer one covers its body right of its left
  edge, and each event takes the widest free space (`EventLayout`:
  `xFraction`, `widthFraction`, `overlapDepth`). The
  `tests/Fixtures/*.json` files of the WinUI repo therefore cannot be run
  against the Swift calculator. Decide on one canonical algorithm (the
  cascade keeps long events readable; lanes are simpler and match Outlook),
  port it to the other platform, and share the fixtures — the Swift tests in
  `Tests/KalendsTests/EventLayoutCalculatorTests.swift` encode the cascade's
  expectations and can be turned into fixtures.
- **Agenda view.** WinUI has an Agenda (schedule list) mode; Swift has none.
  Add `AgendaView` and `KalendsMode.agenda`.
- **Spanning all-day bars.** WinUI draws a multi-day all-day event as one bar
  across the week header; Swift repeats it in every day cell (week header,
  month, day). Draw spanning bars in the week header and the month grid.
- **Event contract.** Same fields on both sides (`id`, `title`,
  `start`/`startDate`, `end`/`endDate`, `isAllDay`, `color`, `isReadOnly`,
  `subtitle`; end exclusive), but the color type differs: WinUI has its own
  `KalendsColor`, Swift uses `SwiftUI.Color`. Keep the field list identical
  when either side changes; document the mapping in both READMEs.
- **Actions vs. events.** WinUI raises `EditRequested`, `TimeChanged`;
  Swift calls `KalendsActions.selectEvent`, `rescheduleEvent`, `createEvent`,
  `updateDraft`, `openDay`, `clearSelection`. Name the callbacks the same on
  both sides once the WinUI API settles (WinUI currently lacks draft drawing
  and `openDay`).
- **Move semantics.** WinUI clamps a moved event to the visible range and
  keeps its duration; Swift lets a drag cross the week edge (the week then
  navigates). Agree on one behaviour.
- **Strings and locale.** WinUI: a replaceable `KalendsStrings` object plus
  `Culture` and `FirstDayOfWeek` properties. Swift: `Localizable.xcstrings`
  (English, Russian) resolved against the SwiftUI `\.locale`, first weekday
  from `\.calendar`. Add the same languages on both sides; WinUI could ship
  the same `.xcstrings`-derived resources.
- **Styles.** Swift has touch and desktop styles for the month and year views
  (`.compact` / `.detailed` / `.cards`); WinUI has a single desktop style.
  When WinUI gets a touch layout, use the same names.
- **Sample data.** Both samples now use the same week of events and the same
  four colors; keep them in sync when adding demo cases.
- **Versioning and docs.** Both are 0.1.0, unpublished. Release together,
  keep README sections in the same order (Features, Requirements,
  Installation, Quick Start, Handling User Interaction, Customization,
  Example App, Roadmap, License).

## 2. Missing in Kalends (SwiftUI)

- **Customization points.** Everything is fixed except `hourHeight`. Add
  view factories (event cell, day header, hour label, all-day cell), an
  `EnvironmentValues` style struct for fonts and colors, and a way to change
  the 15-minute snap.
- **Time zone in date text.** Views take day boundaries and the first weekday
  from `\.calendar`, but `DateText` formats with the locale's default
  calendar and time zone. Pass the environment calendar's time zone into the
  format styles.
- **`Calendar.current` in `EventLayoutCalculator` and `KalendsEventStore`
  defaults.** Fine for hosts on the device calendar; document or remove the
  defaults once the environment is threaded everywhere.
- **Zoomable time scale** (pinch on iOS, ⌘± on macOS) — `hourHeight` is a
  plain parameter today.
- **Keyboard navigation and accessibility audit.** Labels exist on cells and
  event blocks; there is no keyboard focus model for the grid, and VoiceOver
  order has not been checked.
- **Multi-day timed events** are clamped to each day they cover; there is no
  visual hint that a block continues on the next day.
- **Performance.** `KalendsEventStore` rebuilds its whole index on every
  change; the month view asks `events(on:)` for 42 cells per section. Both
  are fine for thousands of events, not for a hundred thousand.
- **Drag to create on iOS** competes with the scroll view; the drag must be
  vertical and quick. Consider a long-press-then-drag gesture on touch.
- **Tests.** Only the layout, date helpers and the store are covered. Add
  snapshot tests for the views (both styles, light and dark) and a test that
  the string catalog has every key in every language.
- **DocC catalog** with the API overview and a "Getting started" article, so
  the Swift Package Index can host the documentation.

## 3. Release checklist

- Tag `0.1.0` in both repositories; push tags.
- Add the package to the Swift Package Index; publish `Kalends.WinUI` to
  NuGet at `1.0.0`.
- Switch LawMatic Calendar (Apple and Windows) from local path / project
  references to tagged versions.
- Set the GitHub topics and About text on all four repositories.
