import AppKit
import IOKit.ps

/// Everything the window needs to know about the machine, gathered without a
/// polling loop: power changes arrive on a run-loop source, app launches and
/// quits arrive as workspace notifications.
final class SystemProbe {

    static let claudeBundleID = "com.anthropic.claudefordesktop"

    private var powerSource: CFRunLoopSource?
    private var onChange: (() -> Void)?

    /// Registered so the C callback below can reach the live instance.
    private static var active: SystemProbe?

    func start(onChange: @escaping () -> Void) {
        self.onChange = onChange
        SystemProbe.active = self

        let context = UnsafeMutableRawPointer(bitPattern: 0)
        if let source = IOPSNotificationCreateRunLoopSource(systemProbePowerChanged, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            powerSource = source
        }

        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.onChange?()
            }
        }
    }

    fileprivate func notifyChanged() { onChange?() }
    fileprivate static func fire() { active?.notifyChanged() }

    // MARK: - Readings

    var claudeIsRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: SystemProbe.claudeBundleID).isEmpty
    }

    /// e.g. "Adapter · 87%", "Battery · 64%", "Adapter"
    var powerSummary: String {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef],
              let first = sources.first,
              let description = IOPSGetPowerSourceDescription(blob, first)?.takeUnretainedValue() as? [String: Any]
        else { return "Adapter" }

        let onAC = (description[kIOPSPowerSourceStateKey as String] as? String) == (kIOPSACPowerValue as String)
        let charging = description[kIOPSIsChargingKey as String] as? Bool ?? false
        let current = description[kIOPSCurrentCapacityKey as String] as? Int
        let maximum = description[kIOPSMaxCapacityKey as String] as? Int ?? 100

        var label = onAC ? (charging ? "Charging" : "Adapter") : "Battery"
        if let current, maximum > 0 {
            label += " · \(Int((Double(current) / Double(maximum) * 100).rounded()))%"
        }
        return label
    }
}

/// C entry point for `IOPSNotificationCreateRunLoopSource`; it runs on the main
/// run loop, so hopping threads is unnecessary.
private func systemProbePowerChanged(_ context: UnsafeMutableRawPointer?) {
    SystemProbe.fire()
}
