import AppKit

// Keep awake: toggles `pmset disablesleep`, a system-wide power setting that keeps
// the Mac fully running with the lid closed (no external display needed). It stays
// in effect even after the app quits, until it is switched off again.
enum KeepAwake {
    private static let pmset = "/usr/bin/pmset"
    private static let sudoersPath = "/etc/sudoers.d/owl-switch"
    private static let legacySudoersPath = "/etc/sudoers.d/owl-awake"   // written by Owl Awake 1.x

    static var isOn: Bool {
        let out = run(pmset, ["-g"]).output
        for line in out.split(separator: "\n") where line.contains("SleepDisabled") {
            return line.split(whereSeparator: { $0 == " " || $0 == "\t" }).last == "1"
        }
        return false
    }

    /// Runs `sudo -n pmset -a disablesleep <0|1>`; works only once the sudoers rule is installed.
    static func set(_ on: Bool) -> Bool {
        run("/usr/bin/sudo", ["-n", pmset, "-a", "disablesleep", on ? "1" : "0"]).status == 0
    }

    /// One-time setup: lets the current user run exactly these two pmset commands without a password.
    /// macOS shows its own admin password dialog.
    static func installPermission() -> Bool {
        let user = NSUserName()
        let rule = "\(user) ALL=(root) NOPASSWD: \(pmset) -a disablesleep 0, \(pmset) -a disablesleep 1\n"
        let tmp = NSTemporaryDirectory() + "owl-switch.sudoers"
        do { try rule.write(toFile: tmp, atomically: true, encoding: .utf8) } catch { return false }
        let cmd = "/usr/sbin/visudo -cf '\(tmp)' && /usr/bin/install -m 0440 -o root -g wheel '\(tmp)' \(sudoersPath)"
        return runAsAdmin(cmd)
    }

    static func removePermission() -> Bool {
        runAsAdmin("\(pmset) -a disablesleep 0; /bin/rm -f \(sudoersPath) \(legacySudoersPath)")
    }

    @discardableResult
    private static func run(_ path: String, _ args: [String]) -> (status: Int32, output: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        do { try task.run() } catch { return (-1, error.localizedDescription) }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return (task.terminationStatus, String(data: data, encoding: .utf8) ?? "")
    }

    private static func runAsAdmin(_ cmd: String) -> Bool {
        let escaped = cmd.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        var error: NSDictionary?
        NSAppleScript(source: "do shell script \"\(escaped)\" with administrator privileges")?.executeAndReturnError(&error)
        return error == nil
    }
}
