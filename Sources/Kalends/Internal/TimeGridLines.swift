import SwiftUI

/// Grid lines of a time grid — one per hour, plus vertical lines between day
/// columns — drawn in a single `Canvas` instead of hundreds of rectangles.
struct TimeGridLines: View {
    let hourHeight: CGFloat
    let hourCount: Int
    let columnCount: Int

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            var path = Path()

            for hour in 0 ..< hourCount {
                let y = (CGFloat(hour) * hourHeight).rounded() + 0.5
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }

            if columnCount > 1 {
                let columnWidth = size.width / CGFloat(columnCount)
                for column in 1 ..< columnCount {
                    let x = (CGFloat(column) * columnWidth).rounded() - 0.5
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
            }

            context.stroke(path, with: .color(Color.kalendsSeparator), lineWidth: 1)
        }
        .frame(height: CGFloat(hourCount) * hourHeight)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The hour labels of a time column next to the grid.
struct HourLabelsColumn: View {
    let hours: [Int]
    let hourHeight: CGFloat
    let trailingPadding: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            ForEach(hours, id: \.self) { hour in
                Text(DateText.hourLabel(hour))
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(width: 50, height: hourHeight, alignment: .topTrailing)
                    .padding(.trailing, trailingPadding)
            }
        }
    }
}
