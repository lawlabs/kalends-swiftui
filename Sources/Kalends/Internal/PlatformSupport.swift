import SwiftUI

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

extension Color {
    static var kalendsWindowBackground: Color {
        #if os(macOS)
        Color(NSColor.windowBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }

    static var kalendsControlBackground: Color {
        #if os(macOS)
        Color(NSColor.controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemBackground)
        #endif
    }

    /// Opaque backdrop under an event block's tint, so a block drawn over
    /// another hides it instead of letting its text show through.
    static var kalendsEventBackdrop: Color {
        #if os(macOS)
        Color(NSColor.textBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }

    static var kalendsSeparator: Color {
        #if os(macOS)
        Color(NSColor.separatorColor)
        #else
        Color(uiColor: .separator)
        #endif
    }

    /// Text color over a fill of this color.
    ///
    /// An unselected block is a light tint (≈25 %) over the window backdrop,
    /// so in dark mode the backdrop is dark and the text must be light, and
    /// vice versa. A selected block is filled almost opaquely with the pastel
    /// color, on which dark text reads well in both schemes.
    func eventTextColor(isSelected: Bool, colorScheme: ColorScheme) -> Color {
        if isSelected || colorScheme == .light {
            return mix(with: .black, by: 0.5)
        }
        return mix(with: .white, by: 0.55)
    }
}

extension View {
    @ViewBuilder
    func onHoverIfSupported(_ action: @escaping (Bool) -> Void) -> some View {
        #if os(macOS)
        onHover(perform: action)
        #else
        self
        #endif
    }

    @ViewBuilder
    func resizeCursorIfAvailable() -> some View {
        #if os(macOS)
        onHover { isHovering in
            if isHovering {
                NSCursor.resizeUpDown.push()
            } else {
                NSCursor.pop()
            }
        }
        #else
        self
        #endif
    }
}
