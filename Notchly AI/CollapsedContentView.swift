import SwiftUI

struct CollapsedContentView: View {
    var onClick: () -> Void = {}
    // Removed 'let screen = NSScreen.main?.visibleFrame ?? .zero' as it's not needed here
    // and can cause issues with SwiftUI's layout system.

    var body: some View {
        VStack { // Use VStack to control vertical positioning
            Spacer() // Pushes the content to the bottom
            // Removed the explicit RoundedRectangle here.
            // The NSVisualEffectView in HoverWindow will now handle the rounding of the background.
            Image(systemName: "bubble.left")
                .foregroundColor(.primary)
                .frame(width: 200, height: 25) // Adjusted width and height for the bubble icon's frame
        }
        // The VStack will naturally expand to fill the space provided by HoverWindow (200x70).
        // The Spacer will push the content to the bottom.
        // The overall view itself will be clipped by the NSVisualEffectView's cornerRadius.
        .frame(width: 200, height: 70) // Adjusted overall frame of the collapsed window
        .background(Color.clear) // Ensure the background is clear to show NSVisualEffectView
        .cornerRadius(20) // Apply corner radius to the SwiftUI view itself to match the window
        .padding(.horizontal) // Adds horizontal padding around the content if desired
    }
}
