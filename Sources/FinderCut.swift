import AppKit

/// Windows-style cut & paste for files in Finder: Cmd+X marks the selection, Cmd+V moves it.
/// Finder can already move files with Cmd+C then Cmd+Option+V; this maps the Windows keys onto that.
/// While renaming or searching (a text field is focused) the keys keep their normal text meaning.
final class FinderCut {
    private static let textRoles: Set<String> = ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"]

    private let toast: Toast
    private let lock = NSLock()
    private var cutChangeCount: Int?   // clipboard state right after a cut; any newer copy cancels the cut

    init(toast: Toast) { self.toast = toast }

    /// Called on the keyboard thread for every key press. Returns true to swallow it.
    func handle(_ e: CGEvent) -> Bool {
        guard UserDefaults.standard.bool(forKey: Pref.finderCut),
              Key.modifiers(e) == .maskCommand,
              let finder = NSWorkspace.shared.frontmostApplication,
              finder.bundleIdentifier == "com.apple.finder" else { return false }

        switch Key.code(e) {
        case Key.x:
            if isEditingText(finder) { return false }
            if !Key.isRepeat(e) { cut() }
            return true
        case Key.v:
            guard hasPendingCut(), !isEditingText(finder) else { return false }
            e.flags.insert(.maskAlternate)   // Cmd+Option+V = Finder's "Move Item Here"
            setCut(nil)
            return false
        default:
            return false
        }
    }

    private func cut() {
        KeyboardTap.post(Key.c, flags: .maskCommand)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [self] in
            let pb = NSPasteboard.general
            let files = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) ?? []
            guard !files.isEmpty else { setCut(nil); return }
            setCut(pb.changeCount)
            toast.show(files.count == 1 ? "Cut 1 item — ⌘V to move it" : "Cut \(files.count) items — ⌘V to move them")
        }
    }

    private func isEditingText(_ app: NSRunningApplication) -> Bool {
        Accessibility.focusedRole(of: app).map(Self.textRoles.contains) ?? false
    }

    private func hasPendingCut() -> Bool {
        lock.lock(); defer { lock.unlock() }
        return cutChangeCount != nil && cutChangeCount == NSPasteboard.general.changeCount
    }

    private func setCut(_ changeCount: Int?) {
        lock.lock(); defer { lock.unlock() }
        cutChangeCount = changeCount
    }
}
