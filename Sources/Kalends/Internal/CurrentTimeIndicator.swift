import SwiftUI

/// The red “now” line with a time badge; moves once a minute.
struct CurrentTimeIndicator: View {
    let hourHeight: CGFloat

    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let now = context.date
            let hour = calendar.component(.hour, from: now)
            let minute = calendar.component(.minute, from: now)
            let offset = CGFloat(hour * 60 + minute) * (hourHeight / 60)

            HStack(spacing: 0) {
                Text(DateText.time(now, locale: locale))
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.red))
                    .offset(x: 8)

                Rectangle()
                    .fill(Color.red)
                    .frame(height: 2)
                    .offset(x: 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .offset(y: offset)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
