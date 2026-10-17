import SwiftUI

/// Stacks the title and detail rows (time, subtitle) of an event block from
/// the top.
///
/// The title wraps into whatever height the detail rows leave. A detail row
/// is shown only while one line of the title still fits above it, so a short
/// block shows its title rather than a title and half a time line. Rows that
/// do not fit are moved below the block, which clips them.
struct EventBlockContentLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let title = subviews.first else { return }
        let widthOnly = ProposedViewSize(width: bounds.width, height: nil)
        // The ideal size of a text is one unwrapped line.
        let titleLineHeight = title.sizeThatFits(.unspecified).height

        var details: [(subview: LayoutSubview, height: CGFloat)] = []
        var detailsHeight: CGFloat = 0
        for detail in subviews.dropFirst() {
            let height = detail.sizeThatFits(widthOnly).height
            guard titleLineHeight + detailsHeight + spacing + height <= bounds.height else { break }
            details.append((detail, height))
            detailsHeight += spacing + height
        }

        let titleHeight = title.sizeThatFits(
            ProposedViewSize(width: bounds.width, height: max(titleLineHeight, bounds.height - detailsHeight))
        ).height
        title.place(at: bounds.origin, proposal: ProposedViewSize(width: bounds.width, height: titleHeight))

        var y = bounds.minY + titleHeight
        for detail in details {
            y += spacing
            detail.subview.place(
                at: CGPoint(x: bounds.minX, y: y),
                proposal: ProposedViewSize(width: bounds.width, height: detail.height)
            )
            y += detail.height
        }

        for hidden in subviews.dropFirst(1 + details.count) {
            hidden.place(at: CGPoint(x: bounds.minX, y: bounds.maxY + 10_000), proposal: widthOnly)
        }
    }
}
