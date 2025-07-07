///
/// CircleButton.swift
/// NotesDemo
///
/// A customizable circular button displaying only an SF Symbol,
/// with built-in accessibility support and customizable colors.
///
import SwiftUI

/// A circular icon-only button that carries its own accessibility label.
///
/// - Displays a resizable SF Symbol centered in a colored circle.
/// - Applies a drop shadow for emphasis.
/// - Reads a custom accessibility label or falls back to the symbol name.
struct CircleButton: View {
    // MARK: - Configuration Properties
    /// The name of the SF Symbol to display.
    let image: String
    /// Background color of the circular button (defaults to blue).
    var bg: Color = .blue
    /// Foreground color for the symbol (defaults to white).
    var fg: Color = .white
    /// Optional VoiceOver label (if nil, uses `image` name).
    var accessibilityLabel: String? = nil
    /// Action to perform when the button is tapped.
    let action: () -> Void

    // MARK: - View Body
    var body: some View {
        Button(action: action) {
            Image(systemName: image)
                .font(.title)
                .foregroundColor(fg)
                .padding()
                .background(bg)
                .clipShape(Circle())
                .shadow(radius: 5)
        }
        // Use provided accessibility label or fallback to the symbol name
        .accessibilityLabel(accessibilityLabel ?? image)
    }
}

#if DEBUG
/// Preview provider for CircleButton
struct CircleButton_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 20) {
            CircleButton(
                image: "plus",
                bg: Color.green,
                fg: Color.white,
                accessibilityLabel: "Add note",
                action: { print("Tapped +") }
            )
            CircleButton(
                image: "mic",
                bg: Color.pink,
                fg: Color.white,
                accessibilityLabel: "Record note",
                action: { print("Tapped mic") }
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
