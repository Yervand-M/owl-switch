import AppKit

/// Windows-style "show desktop" (Win+D): Option+D clears every window off the screen, and pressing it
/// again while still on the desktop brings them all back. Opening one app (Dock, Cmd+Tab) brings back
/// just that app, like clicking a minimized window on the Windows taskbar.
///
/// Apps are hidden (instant, no animation). Finder has to stay active to show the desktop, so its
/// own windows are minimized to the Dock instead.
final class ShowDesktop {
    private var hiddenApps: [NSRunningApplication] = []
    private var minimizedFinderWindows: [AXUIElement] = []
    private var previousFront: NSRunningApplication?

    private var finder: NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == "com.apple.finder" }
    }

    /// Called on the keyboard thread for every key press. Returns true to swallow it.
    func handle(_ e: CGEvent) -> Bool {
        guard UserDefaults.standard.bool(forKey: Pref.showDesktop),
              Key.code(e) == Key.d, Key.modifiers(e) == .maskAlternate else { return false }
        if !Key.isRepeat(e) { DispatchQueue.main.async { self.toggle() } }
        return true
    }

    func toggle() {
        hiddenApps.removeAll { $0.isTerminated || !$0.isHidden }
        let onDesktop = NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder"
        if onDesktop && !(hiddenApps.isEmpty && minimizedFinderWindows.isEmpty) {
            restore()
        } else {
            clear()
        }
    }

    private func clear() {
        guard let finder else { return }
        let front = NSWorkspace.shared.frontmostApplication
        if front != finder { previousFront = front }
        // Switch to the desktop first: hiding the active app makes macOS bring up another one.
        finder.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [self] in
            let visible = NSWorkspace.shared.runningApplications.filter {
                $0.activationPolicy == .regular && !$0.isHidden && $0 != finder && $0 != .current
            }
            visible.forEach { $0.hide() }
            hiddenApps += visible
            minimizedFinderWindows += setFinderWindows(minimized: true, only: nil)
        }
    }

    private func restore() {
        hiddenApps.forEach { $0.unhide() }
        _ = setFinderWindows(minimized: false, only: minimizedFinderWindows)
        hiddenApps.removeAll()
        minimizedFinderWindows.removeAll()
        previousFront?.activate()
    }

    /// Minimizes Finder's open windows (returns the ones it changed), or un-minimizes the given ones.
    private func setFinderWindows(minimized: Bool, only targets: [AXUIElement]?) -> [AXUIElement] {
        guard let finder else { return [] }
        let windows: [AXUIElement]
        if let targets {
            windows = targets
        } else {
            let app = AXUIElementCreateApplication(finder.processIdentifier)
            AXUIElementSetMessagingTimeout(app, 0.3)
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
                  let all = value as? [AXUIElement] else { return [] }
            windows = all.filter { window in
                var subrole: CFTypeRef?, isMinimized: CFTypeRef?
                AXUIElementCopyAttributeValue(window, kAXSubroleAttribute as CFString, &subrole)
                AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &isMinimized)
                return subrole as? String == kAXStandardWindowSubrole && (isMinimized as? Bool) == false
            }
        }
        return windows.filter {
            AXUIElementSetAttributeValue($0, kAXMinimizedAttribute as CFString, minimized as CFBoolean) == .success
        }
    }
}
