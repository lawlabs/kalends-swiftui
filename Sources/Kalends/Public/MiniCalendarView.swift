import SwiftUI

/// A small month grid for navigation, as in a sidebar.
///
/// The month shown follows `selectedDate`, but the user can page through
/// months independently until the selected date changes again.
public struct MiniCalendarView: View {
    @Binding private var selectedDate: Date

    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    @State private var displayMonth: Date?

    public init(selectedDate: Binding<Date>) {
        self._selectedDate = selectedDate
    }

    private var resolvedDisplayMonth: Date {
        displayMonth ?? calendar.startOfMonth(for: selectedDate)
    }

    public var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    displayMonth = calendar.date(byAdding: .month, value: -1, to: resolvedDisplayMonth)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(KalendsText.string("Previous month", locale: locale))

                Spacer()

                Text(DateText.monthYear(resolvedDisplayMonth, locale: locale))
                    .font(.caption)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    displayMonth = calendar.date(byAdding: .month, value: 1, to: resolvedDisplayMonth)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(KalendsText.string("Next month", locale: locale))
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(calendar.orderedWeekdaySymbols(.short, locale: locale).enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(calendar.weeksInMonth(of: resolvedDisplayMonth).flatMap { $0 }.enumerated()), id: \.offset) { _, date in
                    if let date {
                        MiniCalendarDayCell(
                            date: date,
                            isToday: calendar.isDateInToday(date),
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isCurrentMonth: calendar.isDate(date, equalTo: resolvedDisplayMonth, toGranularity: .month),
                            onSelect: { selectedDate = date }
                        )
                    } else {
                        Text("")
                            .frame(width: 20, height: 20)
                    }
                }
            }
        }
        .padding(8)
        .onChange(of: selectedDate) { _, newValue in
            let newMonth = calendar.startOfMonth(for: newValue)
            if newMonth != resolvedDisplayMonth {
                displayMonth = newMonth
            }
        }
    }
}

private struct MiniCalendarDayCell: View {
    let date: Date
    let isToday: Bool
    let isSelected: Bool
    let isCurrentMonth: Bool
    let onSelect: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        Button(action: onSelect) {
            Text(DateText.dayNumber(date, locale: locale))
                .font(.system(size: 10))
                .foregroundColor(isToday ? .white : (isCurrentMonth ? .primary : .gray))
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(isToday ? Color.red : (isSelected ? Color.blue.opacity(0.3) : Color.clear))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(DateText.weekdayDayMonth(date, locale: locale))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
