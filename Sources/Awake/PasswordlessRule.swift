import Foundation

/// An opt-in way to stop the password prompt coming back.
///
/// It installs one file in `/etc/sudoers.d` that permits exactly two command
/// lines — `pmset -a disablesleep 0` and `pmset -a disablesleep 1` — for the
/// user who installed it. Nothing else. The arguments are fixed, so the rule
/// cannot be steered into running anything but the lid switch, and no daemon
/// or helper process is left behind.
///
/// Installing it costs one password. After that, Awake never asks again.
enum PasswordlessRule {

    static let path = "/etc/sudoers.d/awake"

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: path)
    }

    /// `pmset` is deliberately spelled out in full: sudoers matches the command
    /// line literally, and so must we.
    private static let pmset = "/usr/bin/pmset"

    // MARK: Using it

    /// Runs the switch without a prompt. Returns false if the rule is missing,
    /// stale, or was written for a different user — the caller then falls back
    /// to the ordinary authorisation dialog.
    static func apply(disableSleep: Bool) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-n", pmset, "-a", "disablesleep", disableSleep ? "1" : "0"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    // MARK: Installing it

    static func install() -> Result<Void, LidGuard.Failure> {
        let user = NSUserName()
        guard isPlausibleUserName(user) else {
            return .failure(.failed("Unusual user name — the rule was not written."))
        }

        let contents = """
            # Installed by Awake (com.williamlabs.awake).
            #
            # Lets \(user) switch lid-close sleep without typing a password.
            # These two command lines and nothing else — the arguments are fixed.
            #
            # Remove it from Awake's Options, or with:
            #   sudo rm \(path)

            \(user) ALL=(root) NOPASSWD: \(pmset) -a disablesleep 0
            \(user) ALL=(root) NOPASSWD: \(pmset) -a disablesleep 1

            """

        // Base64 travels through AppleScript and the shell without a single
        // character needing to be escaped, so there is nothing to inject into.
        let payload = Data(contents.utf8).base64EncodedString()
        let staging = path + ".tmp" // a dot in the name means sudo ignores it

        // Validated as root, immediately before it is put in place: a file that
        // does not parse never becomes part of the sudoers set, and a failure
        // anywhere takes the half-written staging file with it.
        let steps = [
            "echo '\(payload)' | /usr/bin/base64 -D > \(staging)",
            "/usr/sbin/visudo -cf \(staging)",
            "/usr/sbin/chown root:wheel \(staging)",
            "/bin/chmod 0440 \(staging)",
            "/bin/mv \(staging) \(path)"
        ].joined(separator: " && ")

        return authenticated("{ \(steps); } || { /bin/rm -f \(staging); exit 1; }")
    }

    static func remove() -> Result<Void, LidGuard.Failure> {
        authenticated("/bin/rm -f \(path)")
    }

    // MARK: Plumbing

    private static func isPlausibleUserName(_ name: String) -> Bool {
        !name.isEmpty && name.allSatisfy { $0.isLetter || $0.isNumber || "._-".contains($0) }
    }

    private static func authenticated(_ command: String) -> Result<Void, LidGuard.Failure> {
        let source = "do shell script \"\(command)\" with administrator privileges"
        var errorInfo: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&errorInfo)

        guard let errorInfo else { return .success(()) }
        let code = errorInfo[NSAppleScript.errorNumber] as? Int ?? 0
        if code == -128 { return .failure(.cancelled) }
        let text = errorInfo[NSAppleScript.errorMessage] as? String ?? "The rule could not be written (\(code))."
        return .failure(.failed(text))
    }
}
