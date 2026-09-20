import Kalends
import SwiftUI

struct ContentView: View {
    /// Launch with `-date 2026-09-21` to open on that day (the sample week
    /// is built around it) and `-mode day|week|month|year` to open in that
    /// mode — handy for screenshots.
    @State private var store = SampleEvents.makeStore(around: ContentView.launchDate)
    @State private var mode = KalendsMode(rawValue: UserDefaults.standard.string(forKey: "mode") ?? "") ?? .week
    @State private var selectedDate = ContentView.launchDate

    private static var launchDate: Date {
        guard let text = UserDefaults.standard.string(forKey: "date") else { return Date() }
        return (try? Date(text, strategy: .iso8601.year().month().day())) ?? Date()
    }
    @State private var selectedEventID: SampleEvent.ID?
    /// The event being drawn by a drag on empty space, until the user
    /// taps elsewhere.
    @State private var draftID: SampleEvent.ID?

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        NavigationStack {
            KalendsView(
                mode: mode,
                source: store,
                selectedDate: $selectedDate,
                selectedEventID: selectedEventID,
                actions: actions
            )
            .safeAreaInset(edge: .top, spacing: 0) {
                // On a phone the segmented picker does not fit in the bar.
                if isCompact {
                    modePicker
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
            }
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Button { move(by: -1) } label: { Image(systemName: "chevron.left") }
                    Button("Today") { selectedDate = Date() }
                    Button { move(by: 1) } label: { Image(systemName: "chevron.right") }
                }
                if !isCompact {
                    ToolbarItem(placement: .principal) {
                        modePicker
                            .frame(maxWidth: 320)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    if let selectedEventID, let event = store.events.first(where: { $0.id == selectedEventID }), !event.isReadOnly {
                        Button(role: .destructive) {
                            store.remove(id: selectedEventID)
                            self.selectedEventID = nil
                        } label: {
                            Image(systemName: "trash")
                        }
                        .help("Delete the selected event")
                    }
                }
            }
        }
    }

    private var modePicker: some View {
        Picker("Mode", selection: $mode) {
            ForEach(KalendsMode.allCases, id: \.self) { mode in
                Text(mode.rawValue.capitalized).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    private var title: String {
        switch mode {
        case .day: selectedDate.formatted(date: isCompact ? .abbreviated : .complete, time: .omitted)
        case .week: "Week of " + Calendar.current.dateInterval(of: .weekOfYear, for: selectedDate)!.start.formatted(.dateTime.day().month())
        case .month: selectedDate.formatted(.dateTime.month(.wide).year())
        case .year: selectedDate.formatted(.dateTime.year())
        }
    }

    private func move(by value: Int) {
        let component: Calendar.Component = switch mode {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        }
        selectedDate = Calendar.current.date(byAdding: component, value: value, to: selectedDate) ?? selectedDate
    }

    private var actions: KalendsActions<SampleEvent> {
        KalendsActions(
            selectEvent: { event in
                if event.id != draftID { draftID = nil }
                selectedEventID = event.id
            },
            clearSelection: {
                selectedEventID = nil
                draftID = nil
            },
            rescheduleEvent: { event, interval in
                var moved = event
                moved.startDate = interval.start
                moved.endDate = interval.end
                store.upsert(moved)
            },
            createEvent: { start in
                let event = SampleEvent(
                    title: "New event",
                    startDate: start,
                    endDate: start.addingTimeInterval(3600)
                )
                store.upsert(event)
                selectedEventID = event.id
            },
            updateDraft: { interval in
                if let draftID, var draft = store.events.first(where: { $0.id == draftID }) {
                    draft.startDate = interval.start
                    draft.endDate = interval.end
                    store.upsert(draft)
                } else {
                    let draft = SampleEvent(title: "", startDate: interval.start, endDate: interval.end)
                    store.upsert(draft)
                    draftID = draft.id
                    selectedEventID = draft.id
                }
            },
            openDay: { date in
                selectedDate = date
                mode = .day
            }
        )
    }
}

#Preview {
    ContentView()
}
