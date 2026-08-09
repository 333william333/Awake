import Foundation
import IOKit

/// Controls the one setting that actually survives the lid closing.
///
/// Power assertions stop *idle* sleep. Closing the lid is not idle sleep — it is
/// an explicit sleep request from the hardware, and no user-space assertion can
/// veto it. The only supported switch is `pmset disablesleep`, which flips
/// `IOPMrootDomain.SleepDisabled` and requires root, so the change is made
/// through an authenticated `do shell script`. The user sees the standard macOS
/// password sheet, and nothing runs with elevated rights beyond that one line.
enum LidGuard {

    enum Failure: Error {
        case cancelled
        case failed(String)

        var message: String {
            switch self {
            case .cancelled: return "Authorisation cancelled."
            case .failed(let text): return text
            }
        }
    }

    /// Reads `SleepDisabled` straight from the IO registry — no privileges, no
    /// subprocess, a few microseconds.
    static var isEngaged: Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }
        let value = IORegistryEntryCreateCFProperty(service, "SleepDisabled" as CFString, kCFAllocatorDefault, 0)
        guard let boolean = value?.takeRetainedValue() as? Bool else { return false }
        return boolean
    }

    static let manualCommand = "sudo pmset -a disablesleep 0"

    /// Must be called from the main thread: it can present the authorisation sheet.
    ///
    /// If the switch is already where we want it there is nothing to authorise —
    /// which is also how a session left behind by a crash gets adopted instead
    /// of asking for a password to change nothing.
    static func set(_ enabled: Bool) -> Result<Void, Failure> {
        if isEngaged == enabled { return .success(()) }

        let command = "/usr/bin/pmset -a disablesleep \(enabled ? "1" : "0")"
        let source = "do shell script \"\(command)\" with administrator privileges"

        var errorInfo: NSDictionary?
        if let script = NSAppleScript(source: source) {
            script.executeAndReturnError(&errorInfo)
            if errorInfo == nil { return verify(enabled) }
        }

        guard let errorInfo else { return verify(enabled) }
        let code = errorInfo[NSAppleScript.errorNumber] as? Int ?? 0
        if code == -128 { return .failure(.cancelled) }

        // -1743 means the process is not allowed to send the event at all
        // (rare, but possible under some TCC states). Retry out of process.
        if code == -1743, runViaOSAScript(source) { return verify(enabled) }

        let text = errorInfo[NSAppleScript.errorMessage] as? String ?? "pmset failed (\(code))."
        return .failure(.failed(text))
    }

    private static func verify(_ expected: Bool) -> Result<Void, Failure> {
        isEngaged == expected ? .success(()) : .failure(.failed("The system did not accept the change."))
    }

    private static func runViaOSAScript(_ source: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
