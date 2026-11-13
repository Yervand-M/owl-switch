import AppKit
import ApplicationServices

/// Accessibility permission: needed to see and send key presses (Option+V, Finder Cmd+X / Cmd+V, auto-paste).
enum Accessibility {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows macOS's "allow accessibility" prompt (does nothing once allowed).
    static func prompt() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func openSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    /// Role of the focused UI element in an app, e.g. "AXTextField".
    /// Uses a short timeout so a busy app can never stall typing.
    static func focusedRole(of app: NSRunningApplication) -> String? {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(appElement, 0.15)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let element = focused as! AXUIElement
        AXUIElementSetMessagingTimeout(element, 0.15)
        var role: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success else { return nil }
        return role as? String
    }
}
