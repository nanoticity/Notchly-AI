import AppKit
import SwiftUI
import QuartzCore // Import QuartzCore for CAMediaTimingFunction

class HoverWindow: NSWindow {
    private var isExpanded = false
    private var trackingArea: NSTrackingArea?

    // Approximate real notch size (tweak as needed)
    // Note: The actual "hitbox" for mouse events is determined by the window's frame.
    // We're making the collapsedSize shorter to reduce interference.
    private let notchSize = CGSize(width: 219, height: 37) // Original notch visual size reference
    private var collapsedSize = CGSize(width: 219, height: 37) // Adjusted: Made collapsed window shorter
    private var inBetween = CGSize(width: 250, height: 50)
    private let expandedSize = CGSize(width: 460, height: 360)
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    init() {
        // Use the new, shorter collapsedSize for initial window creation
        let localCollapsedSize = collapsedSize

        guard let screen = NSScreen.main else {
            fatalError("No screen available")
        }

        let screenFrame = screen.frame
        // Position the window at the top center of the screen
        let origin = CGPoint(
            x: screenFrame.midX - localCollapsedSize.width / 2,
            y: screenFrame.maxY - localCollapsedSize.height // Adjusted for new height
        )

        super.init(
            contentRect: NSRect(origin: origin, size: localCollapsedSize),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Window setup
        isOpaque = false
        backgroundColor = .clear
        level = .statusBar
        hasShadow = false
        ignoresMouseEvents = false
        isMovable = false
        isReleasedWhenClosed = false
        hidesOnDeactivate = false

        // Set the initial content view with blur
        setContentViewCollapsed()
        updateTrackingArea()
    }

    // Sets the content view for the collapsed state with a blur effect
    private func setContentViewCollapsed() {
        let view = CollapsedContentView(onClick: { [weak self] in
            self?.expandWindow()
        })
        setContentViewWithBlur(view: view, size: collapsedSize)
    }

    // Sets the content view for the expanded state with a blur effect
    private func setContentViewExpanded() {
        // Now using the new ExpandedTransitionView to handle the icon and ChatView transition
        let view = ExpandedTransitionView()
        setContentViewWithBlur(view: view, size: expandedSize)
    }

    // Generic method to set content view with an NSVisualEffectView blur background
    private func setContentViewWithBlur<T: View>(view: T, size: CGSize) {
        // Create an NSVisualEffectView for the blur background
        let visualEffectView = NSVisualEffectView()
        visualEffectView.frame = NSRect(origin: .zero, size: size)
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.isEmphasized = true

        // Crucial for rounding the NSVisualEffectView itself
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 20 // Apply corner radius to the visual effect view's layer
        visualEffectView.layer?.masksToBounds = true // Ensure content (including blur) is clipped to the rounded corners

        // Create the NSHostingView for the SwiftUI content
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = visualEffectView.bounds // Make SwiftUI view fill the effect view
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        // Add the hosting view as a subview of the visual effect view
        visualEffectView.addSubview(hostingView)
        
        // Set the visual effect view as the window's content view
        contentView = visualEffectView
        updateTrackingArea()
    }

    private func updateTrackingArea() {
        guard let contentView = contentView else { return }

        if let oldTracking = trackingArea {
            contentView.removeTrackingArea(oldTracking)
        }

        trackingArea = NSTrackingArea(
            rect: contentView.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )

        contentView.addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        if !isExpanded {
            expandWindow()
        }
    }

    override func mouseExited(with event: NSEvent) {
        let mouseLocation = NSEvent.mouseLocation
        if !frame.contains(mouseLocation) {
            collapseWindow()
        }
    }

    func expandWindow() {
        guard !isExpanded else { return }
        isExpanded = true

        guard let screen = NSScreen.main else { return }

        let newOrigin = CGPoint(
            x: screen.frame.midX - expandedSize.width / 2,
            y: screen.frame.maxY - expandedSize.height - 10
        )

        let newFrame = NSRect(origin: newOrigin, size: expandedSize)

        // Set initial alpha to 0 for fade-in, and make the window visible
        self.alphaValue = 0.0
        makeKeyAndOrderFront(nil)

        // Set the content view for the expanded state *before* animation starts
        setContentViewExpanded()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            self.animator().setFrame(newFrame, display: true)
            self.animator().alphaValue = 1.0
        } completionHandler: {
            // No need to set content here as it's already done
        }
    }

    func collapseWindow() {
        guard isExpanded else { return }
        isExpanded = false

        guard let screen = NSScreen.main else { return }

        let origin = CGPoint(
            x: screen.frame.midX - collapsedSize.width / 2,
            y: screen.frame.maxY - collapsedSize.height - 2
        )

        let newFrame = NSRect(origin: origin, size: collapsedSize)

        // Set the content view for the collapsed state *before* animation starts
        setContentViewCollapsed()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            self.animator().setFrame(newFrame, display: true)
            self.animator().alphaValue = 0.0
        } completionHandler: {
            // Optionally, if you want the window to be completely hidden when collapsed:
            // self.orderOut(nil)
        }
    }

    override func resignKey() {
        super.resignKey()
        let mouseLocation = NSEvent.mouseLocation
        if !frame.contains(mouseLocation) {
            collapseWindow()
        }
    }
}
