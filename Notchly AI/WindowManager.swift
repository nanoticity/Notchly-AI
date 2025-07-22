import AppKit
import SwiftUI

class WindowManager: ObservableObject {
    private var chatWindow: NSWindow?

    func toggleChatWindow() {
        if chatWindow == nil {
            let hosting = NSHostingController(rootView: ChatView())
            let screen = NSScreen.main?.visibleFrame ?? .zero
            let windowSize = NSSize(width: 460, height: 360)

            chatWindow = NSWindow(
                contentRect: NSRect(
                    x: screen.midX - windowSize.width / 2,
                    y: screen.maxY - windowSize.height,
                    width: windowSize.width,
                    height: windowSize.height
                ),
                styleMask: [.titled, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )

            chatWindow?.contentView = hosting.view
            chatWindow?.isReleasedWhenClosed = false
            chatWindow?.level = .floating
            chatWindow?.makeKeyAndOrderFront(nil)
        } else {
            chatWindow?.close()
            chatWindow = nil
        }
    }
}
