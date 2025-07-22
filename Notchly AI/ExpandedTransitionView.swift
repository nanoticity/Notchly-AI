import SwiftUI

// MARK: - ExpandedTransitionView
// This view manages the transition from showing just the bubble icon
// to displaying the full ChatView when the window is expanded.
struct ExpandedTransitionView: View {
    // State to control whether to show the full ChatView or just the icon.
    @State private var showChat = false

    var body: some View {
        ZStack {
            // Conditionally display ChatView or the bubble icon.
            // Transitions are applied to make the change smooth.
            if showChat {
                ChatView()
                    .transition(.opacity) // Fade in the ChatView
            } else {
                // Display the bubble icon, centered horizontally by ZStack,
                // and adjusted vertically using .offset.
                Image(systemName: "bubble.left")
                    .font(.largeTitle) // Makes the icon more prominent
                    .foregroundColor(.primary)
                    .offset(y: -50) // Adjust Y to move it slightly higher than center
                    .transition(.opacity) // Fade out the icon
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Ensure ZStack fills available space
        .onAppear {
            // After a short delay (0.3 seconds), animate the transition to show ChatView.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.3)) { // Smooth animation for the transition
                    showChat = true
                }
            }
        }
    }
}
