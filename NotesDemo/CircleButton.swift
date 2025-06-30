import SwiftUI

/// A circular icon‐only button that carries its own accessibility label.
struct CircleButton: View {
    let image: String
    var bg: Color = .blue
    var fg: Color = .white
    /// Optional override for what VoiceOver should read.
    var accessibilityLabel: String? = nil
    let action: () -> Void

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
        // if you passed in a label use that, otherwise fall back to the SF symbol name
        .accessibilityLabel(accessibilityLabel ?? image)
    }
}


#if DEBUG
struct CircleButton_Previews: PreviewProvider {
    static var previews: some View {
        CircleButton(
            image: "plus",
            bg: Color.green,
            fg: Color.white,
            action: { print("Tapped +") }
        )
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
