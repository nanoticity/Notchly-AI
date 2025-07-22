import SwiftUI
import AppKit

@main
struct NotchChatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView() // No main window here
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var hoverWindow: HoverWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        hoverWindow = HoverWindow()
        hoverWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
