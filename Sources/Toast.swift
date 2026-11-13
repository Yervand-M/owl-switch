import AppKit

/// Small dark bubble under the mouse pointer that fades out, e.g. "Cut 3 items — ⌘V to move them".
final class Toast {
    private var panel: NSPanel?
    private var pendingHide: DispatchWorkItem?

    func show(_ text: String) {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.sizeToFit()
        let size = NSSize(width: ceil(label.frame.width) + 28, height: 32)
        label.frame.origin = NSPoint(x: 14, y: (size.height - label.frame.height) / 2)

        let bubble = NSView(frame: NSRect(origin: .zero, size: size))
        bubble.wantsLayer = true
        bubble.layer?.backgroundColor = NSColor(white: 0.1, alpha: 0.88).cgColor
        bubble.layer?.cornerRadius = 9
        bubble.addSubview(label)

        let panel = self.panel ?? makePanel()
        self.panel = panel
        panel.contentView = bubble

        let mouse = NSEvent.mouseLocation
        var origin = NSPoint(x: mouse.x - size.width / 2, y: mouse.y - size.height - 24)
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) {
            let f = screen.visibleFrame
            origin.x = min(max(origin.x, f.minX + 8), f.maxX - size.width - 8)
            origin.y = min(max(origin.y, f.minY + 8), f.maxY - size.height - 8)
        }
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.alphaValue = 1
        panel.orderFrontRegardless()

        pendingHide?.cancel()
        let hide = DispatchWorkItem { [weak panel] in
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.3; panel?.animator().alphaValue = 0 },
                                                 completionHandler: { if panel?.alphaValue == 0 { panel?.orderOut(nil) } })
        }
        pendingHide = hide
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: hide)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        return panel
    }
}
