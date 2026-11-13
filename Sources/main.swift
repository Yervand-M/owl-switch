import AppKit
import ServiceManagement

// Owl Switch — small menu bar helpers for people moving from Windows to macOS:
//  • Keep awake: one click keeps the Mac running, even with the lid closed.
//  • Clipboard history: Option+V (where the Windows key sits) lists the last 25 copies, like Win+V.
//  • Finder cut & paste: Cmd+X then Cmd+V moves files, like Ctrl+X / Ctrl+V.

enum Pref {
    static let clipboardHistory = "clipboardHistoryEnabled"
    static let finderCut = "finderCutEnabled"
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let defaults = UserDefaults.standard
    private let toast = Toast()
    private let history = ClipboardHistory()
    private let keyboard = KeyboardTap()
    private lazy var historyMenu = HistoryMenu(history: history, toast: toast)
    private lazy var finderCut = FinderCut(toast: toast)
    private var statusItem: NSStatusItem!
    private var awake = false
    private var keyboardTimer: Timer?

    private var shortcutsWanted: Bool {
        defaults.bool(forKey: Pref.clipboardHistory) || defaults.bool(forKey: Pref.finderCut)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        defaults.register(defaults: [Pref.clipboardHistory: true, Pref.finderCut: true])

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        refreshAwake()
        // Pick up changes made outside the app (e.g. pmset in Terminal).
        Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in self?.refreshAwake() }

        history.isEnabled = defaults.bool(forKey: Pref.clipboardHistory)
        history.start()
        let finderCut = self.finderCut
        keyboard.handlers = [{ [weak self] in self?.handleHistoryKey($0) ?? false }, finderCut.handle]
        if shortcutsWanted && !Accessibility.isTrusted { Accessibility.prompt() }
        startKeyboardWhenAllowed()
    }

    // MARK: Keyboard shortcuts

    /// Option+V opens the clipboard history. Runs on the keyboard thread, so it only hands off to the main thread.
    private func handleHistoryKey(_ e: CGEvent) -> Bool {
        guard defaults.bool(forKey: Pref.clipboardHistory),
              Key.code(e) == Key.v, Key.modifiers(e) == .maskAlternate else { return false }
        if !Key.isRepeat(e) { DispatchQueue.main.async { self.historyMenu.show() } }
        return true
    }

    /// The keyboard tap needs Accessibility permission; keep trying until the user allows it.
    private func startKeyboardWhenAllowed() {
        guard !keyboard.start(), keyboardTimer == nil else { return }
        keyboardTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            guard let self, self.keyboard.start() else { return }
            timer.invalidate()
            self.keyboardTimer = nil
        }
    }

    // MARK: Keep awake

    private func refreshAwake() {
        awake = KeepAwake.isOn
        statusItem.button?.image = OwlShape.menuBarImage(awake: awake)
        statusItem.button?.toolTip = (awake
            ? "Owl Switch: Mac stays awake, even with the lid closed"
            : "Owl Switch: normal sleep") + "\nRight-click for clipboard history and more"
    }

    @objc private func clicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showMenu()
        } else {
            toggleAwake()
        }
    }

    @objc private func toggleAwake() {
        let target = !awake
        if !KeepAwake.set(target) {
            guard KeepAwake.installPermission(), KeepAwake.set(target) else {
                refreshAwake()
                return
            }
        }
        refreshAwake()
    }

    // MARK: Menu

    private func showMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(item("Keep Mac Awake (lid can be closed)", #selector(toggleAwake), on: awake))
        menu.addItem(.separator())

        let historyOn = defaults.bool(forKey: Pref.clipboardHistory)
        menu.addItem(item("Clipboard History   ⌥V", #selector(toggleHistory), on: historyOn))
        if historyOn {
            for sub in [item("Show Clipboard History", #selector(showHistory)),
                        item("Clear Clipboard History", #selector(clearHistory))] {
                sub.indentationLevel = 1
                menu.addItem(sub)
            }
        }
        menu.addItem(item("Cut & Paste Files in Finder   ⌘X ⌘V", #selector(toggleFinderCut),
                          on: defaults.bool(forKey: Pref.finderCut)))
        if shortcutsWanted && !Accessibility.isTrusted {
            menu.addItem(item("⚠︎ Allow Shortcuts in Accessibility…", #selector(openAccessibility)))
        }
        menu.addItem(.separator())

        let login = item("Open at Login", #selector(toggleLogin), on: SMAppService.mainApp.status == .enabled)
        menu.addItem(login)
        menu.addItem(item("Remove Keep-Awake Permission…", #selector(uninstall)))
        menu.addItem(.separator())
        menu.addItem(item("Quitting stops shortcuts; keep-awake stays as it is", nil))
        menu.addItem(withTitle: "Quit Owl Switch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil   // keep left-click as a one-click toggle
    }

    private func item(_ title: String, _ action: Selector?, on: Bool? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.isEnabled = action != nil
        if let on { item.state = on ? .on : .off }
        return item
    }

    @objc private func toggleHistory() {
        let on = !defaults.bool(forKey: Pref.clipboardHistory)
        defaults.set(on, forKey: Pref.clipboardHistory)
        history.isEnabled = on
        if on { askForAccessibility() }
    }

    @objc private func toggleFinderCut() {
        let on = !defaults.bool(forKey: Pref.finderCut)
        defaults.set(on, forKey: Pref.finderCut)
        if on { askForAccessibility() }
    }

    @objc private func showHistory() {
        DispatchQueue.main.async { self.historyMenu.show() }   // after the status menu has closed
    }

    @objc private func clearHistory() { history.clear() }

    @objc private func openAccessibility() {
        Accessibility.prompt()
        Accessibility.openSettings()
    }

    private func askForAccessibility() {
        guard !Accessibility.isTrusted else { return }
        Accessibility.prompt()
        startKeyboardWhenAllowed()
    }

    @objc private func toggleLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled { try service.unregister() } else { try service.register() }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't change Open at Login"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    @objc private func uninstall() {
        _ = KeepAwake.removePermission()
        refreshAwake()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
