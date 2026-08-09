import AppKit
import Combine

/// The whole product, in one object: hold the assertions, optionally flip the
/// lid switch, and publish just enough state for the window to draw itself.
final class AwakeEngine: ObservableObject {

    static let shared = AwakeEngine()

    // MARK: Published state

    @Published private(set) var isActive = false
    @Published private(set) var claudeIsRunning = false
    @Published private(set) var lidIsGuarded = LidGuard.isEngaged
    @Published private(set) var powerSummary = "Adapter"
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var notice: String?
    @Published var showingOptions = false

    // MARK: Preferences

    @Published var holdDisplayAwake: Bool {
        didSet {
            Defaults.holdDisplayAwake = holdDisplayAwake
            guard isActive else { return }
            if holdDisplayAwake {
                displayAssertion.acquire()
            } else {
                displayAssertion.release()
            }
        }
    }

    @Published var guardLidClose: Bool {
        didSet {
            Defaults.guardLidClose = guardLidClose
            guard isActive, guardLidClose != lidIsGuarded else { return }
            applyLidGuard(guardLidClose)
        }
    }

    @Published var followClaude: Bool {
        didSet {
            Defaults.followClaude = followClaude
            reconcileWithClaude()
        }
    }

    // MARK: Internals

    private let systemAssertion = PowerAssertion(type: PowerAssertion.preventIdleSleep,
                                                 reason: "Awake is keeping Claude working")
    private let displayAssertion = PowerAssertion(type: PowerAssertion.preventDisplaySleep,
                                                  reason: "Awake is keeping the display on")
    private let probe = SystemProbe()
    private var ticker: Timer?
    private var startedAt: Date?
    /// True only when *this* app turned the lid switch on, so we never undo a
    /// setting somebody else owns.
    private var lidGuardIsOurs = false
    private var windowIsVisible = true

    private init() {
        holdDisplayAwake = Defaults.holdDisplayAwake
        guardLidClose = Defaults.guardLidClose
        followClaude = Defaults.followClaude
        claudeIsRunning = probe.claudeIsRunning
        powerSummary = probe.powerSummary
    }

    func start() {
        probe.start { [weak self] in self?.refreshEnvironment() }
        refreshEnvironment()
        if followClaude && claudeIsRunning { activate() }
    }

    // MARK: Actions

    func toggle() { isActive ? deactivate() : activate() }

    func activate() {
        guard !isActive else { return }
        notice = nil
        systemAssertion.acquire()
        if holdDisplayAwake { displayAssertion.acquire() }
        if guardLidClose { applyLidGuard(true) }
        startedAt = Date()
        elapsed = 0
        isActive = true
        retimeTicker()
    }

    func deactivate() {
        guard isActive else { return }
        systemAssertion.release()
        displayAssertion.release()
        if lidGuardIsOurs { restoreLidGuard() }
        startedAt = nil
        elapsed = 0
        isActive = false
        retimeTicker()
    }

    /// Called on quit, log-out and SIGTERM: never leave the machine unable to sleep.
    func shutDown() {
        systemAssertion.release()
        displayAssertion.release()
        if lidGuardIsOurs { _ = restoreLidGuard() }
        ticker?.invalidate()
        ticker = nil
    }

    /// True while the lid switch is ours to put back.
    var lidGuardNeedsRestore: Bool { lidGuardIsOurs }

    /// Undo the lid switch — on quit, on request, or after a crash left it on.
    @discardableResult
    func restoreLidGuard() -> Bool {
        switch LidGuard.set(false) {
        case .success:
            lidGuardIsOurs = false
            lidIsGuarded = LidGuard.isEngaged
            notice = nil
            return true
        case .failure(let failure):
            notice = failure.message
            lidIsGuarded = LidGuard.isEngaged
            return false
        }
    }

    // MARK: Environment

    func setWindowVisible(_ visible: Bool) {
        guard windowIsVisible != visible else { return }
        windowIsVisible = visible
        if visible { refreshEnvironment() }
        retimeTicker()
    }

    private func refreshEnvironment() {
        let running = probe.claudeIsRunning
        let power = probe.powerSummary
        let guarded = LidGuard.isEngaged
        if running != claudeIsRunning { claudeIsRunning = running }
        if power != powerSummary { powerSummary = power }
        if guarded != lidIsGuarded { lidIsGuarded = guarded }
        reconcileWithClaude()
    }

    private func reconcileWithClaude() {
        guard followClaude else { return }
        if claudeIsRunning && !isActive { activate() }
        if !claudeIsRunning && isActive { deactivate() }
    }

    private func applyLidGuard(_ enabled: Bool) {
        switch LidGuard.set(enabled) {
        case .success:
            lidGuardIsOurs = enabled
            notice = nil
        case .failure(let failure):
            // The preference survives a cancelled password prompt — the user
            // asked for this, they just did not authorise it this time.
            notice = enabled
                ? "\(failure.message) The Mac will still sleep when the lid closes."
                : failure.message
        }
        lidIsGuarded = LidGuard.isEngaged
    }

    // MARK: Ticking

    /// One timer, and only while there is something to see: a second-by-second
    /// clock when the window is up, a lazy half-minute heartbeat otherwise.
    private func retimeTicker() {
        ticker?.invalidate()
        ticker = nil
        guard isActive else { return }
        let interval: TimeInterval = windowIsVisible ? 1 : 30
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in self?.tick() }
        timer.tolerance = interval * 0.25
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
        tick()
    }

    private func tick() {
        guard let startedAt else { return }
        elapsed = Date().timeIntervalSince(startedAt)
    }
}

// MARK: - Defaults

enum Defaults {
    private static let store = UserDefaults.standard

    static var holdDisplayAwake: Bool {
        get { store.object(forKey: "holdDisplayAwake") as? Bool ?? false }
        set { store.set(newValue, forKey: "holdDisplayAwake") }
    }

    static var guardLidClose: Bool {
        get { store.object(forKey: "guardLidClose") as? Bool ?? true }
        set { store.set(newValue, forKey: "guardLidClose") }
    }

    static var followClaude: Bool {
        get { store.object(forKey: "followClaude") as? Bool ?? false }
        set { store.set(newValue, forKey: "followClaude") }
    }
}

// MARK: - Formatting

extension TimeInterval {
    var clockText: String {
        let total = Int(self)
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }
}
