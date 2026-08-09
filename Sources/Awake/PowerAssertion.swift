import Foundation
import IOKit.pwr_mgt

/// Thin wrapper around a single IOKit power-management assertion.
///
/// An assertion is the sanctioned way to tell `powerd` "do not idle-sleep while
/// I am around". It costs nothing while held — the kernel simply keeps a
/// reference — and it is released automatically if the process dies, so we can
/// never strand the machine in a no-sleep state through a crash.
final class PowerAssertion {

    /// Keeps the machine from falling asleep on the idle timer.
    static let preventIdleSleep = "PreventUserIdleSystemSleep"
    /// Keeps the display from dimming out on the idle timer.
    static let preventDisplaySleep = "PreventUserIdleDisplaySleep"

    private let type: String
    private let reason: String
    private var identifier: IOPMAssertionID = IOPMAssertionID(0)

    private(set) var isHeld = false

    init(type: String, reason: String) {
        self.type = type
        self.reason = reason
    }

    deinit { release() }

    @discardableResult
    func acquire() -> Bool {
        guard !isHeld else { return true }
        var newID = IOPMAssertionID(0)
        let status = IOPMAssertionCreateWithName(
            type as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &newID
        )
        guard status == kIOReturnSuccess else { return false }
        identifier = newID
        isHeld = true
        return true
    }

    func release() {
        guard isHeld else { return }
        IOPMAssertionRelease(identifier)
        identifier = IOPMAssertionID(0)
        isHeld = false
    }
}
