import AppKit

enum Key {
    static let x: CGKeyCode = 7, c: CGKeyCode = 8, v: CGKeyCode = 9   // physical keys, so any keyboard layout works

    static func code(_ e: CGEvent) -> CGKeyCode { CGKeyCode(e.getIntegerValueField(.keyboardEventKeycode)) }
    static func isRepeat(_ e: CGEvent) -> Bool { e.getIntegerValueField(.keyboardEventAutorepeat) != 0 }

    /// The modifier keys that matter for shortcuts (ignores caps lock, fn, etc.).
    static func modifiers(_ e: CGEvent) -> CGEventFlags {
        e.flags.intersection([.maskCommand, .maskAlternate, .maskControl, .maskShift])
    }
}

/// One system-wide keyboard tap shared by the shortcut features. Needs Accessibility permission.
/// It runs on its own thread, so a busy main thread (or a slow clipboard) never delays typing.
/// Handlers run on that thread for every key press: they return true to swallow it, and may
/// change the event (e.g. its modifier flags) before it is delivered.
final class KeyboardTap {
    static let syntheticMarker: Int64 = 0x4F574C   // "OWL": tags key presses we send ourselves

    var handlers: [(CGEvent) -> Bool] = []
    private var tap: CFMachPort?

    func start() -> Bool {
        if tap != nil { return true }
        guard Accessibility.isTrusted,
              let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
                callback: { _, type, event, refcon in
                    Unmanaged<KeyboardTap>.fromOpaque(refcon!).takeUnretainedValue().handle(type, event)
                },
                userInfo: Unmanaged.passUnretained(self).toOpaque())
        else { return false }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        let thread = Thread {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            CFRunLoopRun()
        }
        thread.name = "Owl Switch keyboard"
        thread.qualityOfService = .userInteractive
        thread.start()
        return true
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown, event.getIntegerValueField(.eventSourceUserData) != Self.syntheticMarker else {
            return Unmanaged.passUnretained(event)
        }
        for handler in handlers where handler(event) { return nil }
        return Unmanaged.passUnretained(event)
    }

    /// Sends a key press to the frontmost app as if typed, tagged so our own tap lets it through.
    static func post(_ key: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        for down in [true, false] {
            guard let e = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down) else { continue }
            e.flags = flags
            e.setIntegerValueField(.eventSourceUserData, value: syntheticMarker)
            e.post(tap: .cghidEventTap)
        }
    }
}
