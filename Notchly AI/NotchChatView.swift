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
    var setupWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if needsOpenAISetup() {
            showOpenAISetup()
        } else {
            showMainWindow()
        }
    }

    private func needsOpenAISetup() -> Bool {
        let key = UserDefaults.standard.string(forKey: "openai_api_key")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return key.isEmpty
    }

    private func showOpenAISetup() {
        let setupView = OpenAISetupView(isPresented: .constant(true))
        let hostingController = NSHostingController(rootView: setupView)

        setupWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 340),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        setupWindow?.center()
        setupWindow?.contentView = hostingController.view
        setupWindow?.title = "OpenAI Setup"
        setupWindow?.isReleasedWhenClosed = false
        setupWindow?.level = .floating
        setupWindow?.makeKeyAndOrderFront(nil)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(setupCompleted),
            name: NSNotification.Name("OpenAISetupCompleted"),
            object: nil
        )
    }

    private func showMainWindow() {
        hoverWindow = HoverWindow()
        hoverWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func setupCompleted() {
        setupWindow?.close()
        setupWindow = nil

        showMainWindow()

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("OpenAISetupCompleted"), object: nil)
    }
}
