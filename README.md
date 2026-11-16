<p align="center">
  <img src="icon-preview.png" width="160" alt="Owl Switch icon">
</p>

<h1 align="center">Owl Switch</h1>

<p align="center">
  The Windows habits you miss on a Mac, in one small menu bar owl.<br>
  Keep the MacBook awake with the lid closed · clipboard history like <b>Win+V</b> · cut & paste files like <b>Ctrl+X</b> · show desktop like <b>Win+D</b>.
</p>

---

## What it does

| You're used to (Windows) | On a Mac with Owl Switch |
|---|---|
| **Win+V** clipboard history | **⌥ Option+V** opens your last 25 copies (text, images, files). Press **1–9** or pick one, and it pastes. Option sits where the Windows key was. |
| **Ctrl+X → Ctrl+V** to move files | **⌘X → ⌘V** in Finder moves the files. Normally Finder can't cut files. |
| **Win+D** show desktop | **⌥ Option+D** clears every window off the screen. Press it again to bring them all back, or open one app from the Dock to bring back just that one. |
| "Never sleep" power plan | **Left-click the owl** and the Mac stays fully awake, even with the lid closed and no external display. Good for AI agents, downloads and builds. |

- 👀 Owl's eyes open: staying awake. 😌 Eyes closed: normal sleep.
- **Right-click the owl** for everything else: turn each feature on or off, show or clear the clipboard history, Open at Login, Quit.
- Text cut and paste (⌘X / ⌘V in any text) works as usual. So does renaming a file in Finder.

Works on macOS 13 Ventura or later, on Apple Silicon and Intel Macs.

## Install

Paste this into **Terminal**:

```bash
curl -fsSL -o /tmp/Owl-Switch.zip https://github.com/Yervand-M/owl-switch/releases/latest/download/Owl-Switch.zip && ditto -x -k /tmp/Owl-Switch.zip /Applications && open "/Applications/Owl Switch.app"
```

The owl appears in your menu bar at the top right of the screen.

<details>
<summary>Prefer downloading by hand?</summary>

1. Download `Owl-Switch.zip` from the [latest release](https://github.com/Yervand-M/owl-switch/releases/latest) and unzip it.
2. Move **Owl Switch.app** to **Applications**.
3. Open it. The app isn't notarised by Apple, so macOS blocks it the first time. Go to **System Settings → Privacy & Security**, scroll down and click **Open Anyway**.

</details>

## First use: two one-time permissions

**1. Accessibility (for the shortcuts).** On first launch macOS asks to let Owl Switch control your computer. Click **Open System Settings** and switch **Owl Switch** on under **Privacy & Security → Accessibility**. Without it, ⌥V, ⌥D and Finder ⌘X do nothing, but keep-awake still works.

**2. Admin password (for keep-awake).** The first time you turn keep-awake on, macOS asks for your password **once**. Owl Switch then installs a one-line permission file, `/etc/sudoers.d/owl-switch`, which lets your user run **only** these two commands without a password:

```
/usr/bin/pmset -a disablesleep 1
/usr/bin/pmset -a disablesleep 0
```

Nothing else is allowed. **Remove Keep-Awake Permission…** in the right-click menu deletes the file and restores normal sleep.

## Privacy

- Clipboard history lives **in memory only**. It's never written to disk, never sent anywhere, and disappears when you quit.
- Copies that password managers mark as private (1Password, Bitwarden and others using the `org.nspasteboard.ConcealedType` standard) are **not recorded**.
- Turning clipboard history off clears it immediately.
- The app has no network access, no analytics and no tracking.

## Pros and cons

| ✅ Pros | ⚠️ Cons |
|---|---|
| Keep-awake works with the **lid closed and no external display**. `caffeinate` and most "keep awake" apps can't do this. | **Heat:** a closed laptop cools worse. Use it on a hard surface, never in a bag. |
| Clipboard history and file cut-and-paste work like Windows, on keys your fingers already know. | **Battery:** with keep-awake on battery, it runs until empty. Plug in for long runs. |
| Keep-awake keeps running **after you quit the app**. | That also means **it's easy to forget it's on.** Check the owl before packing the laptop. |
| Tiny native app: no dependencies, no network, no tracking. Open source. | **Option+V and Option+D no longer type √ and ∂** while those features are on. Turn either off in the right-click menu. |
| History is memory-only and skips password-manager copies. | **Not notarised by Apple,** so after each update macOS may ask for Accessibility again (see below). |
| | Turning keep-awake off with the lid closed puts the Mac to sleep **immediately**. |

## Troubleshooting

**⌥V, ⌥D or Finder ⌘X stopped working after an update.** macOS ties the Accessibility permission to the exact app build. Open **System Settings → Privacy & Security → Accessibility**, select **Owl Switch**, click **−** to remove it, then switch it on again (or right-click the owl → **Allow Shortcuts in Accessibility…**).

**Turn keep-awake off without the app:**

```bash
sudo pmset -a disablesleep 0
```

## Uninstall

1. Right-click the owl → **Remove Keep-Awake Permission…** (this also restores normal sleep).
2. Quit the app and delete **Owl Switch.app** from Applications.
3. Optional: remove Owl Switch from **System Settings → Privacy & Security → Accessibility**.

## Build from source

Requires the Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/Yervand-M/owl-switch.git
cd owl-switch
./build.sh
ditto ".build/Owl Switch.app" "/Applications/Owl Switch.app"
```

The build goes into `.build/`: `Owl Switch.app` (universal: arm64 + x86_64) and `Owl-Switch.zip`.

| File | Purpose |
|---|---|
| `Sources/main.swift` | Menu bar owl, menu and settings |
| `Sources/KeepAwake.swift` | Keep-awake (`pmset disablesleep`) and its permission |
| `Sources/ClipboardHistory.swift` | Clipboard history and the ⌥V menu |
| `Sources/FinderCut.swift` | ⌘X / ⌘V file moving in Finder |
| `Sources/ShowDesktop.swift` | ⌥D show desktop and bring windows back |
| `Sources/KeyboardTap.swift` | The shared keyboard listener (runs on its own thread) |
| `Sources/Accessibility.swift` | Accessibility permission helpers |
| `Sources/Toast.swift` | The small "Cut 3 items" bubble |
| `Sources/OwlShape.swift` | The owl drawing, for the menu bar and app icons |
| `Tools/IconGen/main.swift` | Renders the app icon |
| `build.sh` | Builds, signs (ad-hoc) and zips the app |

Upgrading from **Owl Awake 1.x**: the old keep-awake permission keeps working, and **Remove Keep-Awake Permission…** cleans up both.

## License

MIT. Made by [Tech Creators Lab](https://github.com/Yervand-M).
