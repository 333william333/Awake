import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    private let engine = AwakeEngine.shared
    private var window: NSWindow?
    private var statusItem: NSStatusItem?
    private var signalSources: [DispatchSourceSignal] = []
    private var cancellables = Set<AnyCancellable>()
    /// Log-out and `killall` must not stall behind a dialog.
    private var isTerminatingFromSignal = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.mainMenu = MainMenu.build()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        engine.start()
        makeWindow()
        makeStatusItem()
        trapTerminationSignals()

        // Handy for scripted screenshots: `open -a Awake --args --options --dark`.
        if CommandLine.arguments.contains("--options") { engine.showingOptions = true }
        if CommandLine.arguments.contains("--dark") { NSApp.appearance = NSAppearance(named: .darkAqua) }

        // The menu bar only needs to follow one flag; `receive(on:)` lets the
        // published value settle before we read it.
        engine.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.refreshStatusItem() }
            .store(in: &cancellables)
    }

    /// Putting the lid switch back needs a password too, so quitting has to be
    /// able to fail — better a second prompt than a Mac that never sleeps again.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard engine.lidGuardNeedsRestore, !isTerminatingFromSignal else { return .terminateNow }
        if engine.restoreLidGuard() { return .terminateNow }

        let alert = NSAlert()
        alert.messageText = "Sleep is still disabled"
        alert.informativeText = """
            Awake could not restore normal sleep, so this Mac will stay awake with \
            the lid closed until it is put back.
            """
        alert.addButton(withTitle: "Try Again")
        alert.addButton(withTitle: "Quit Anyway")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return engine.restoreLidGuard() ? .terminateNow : .terminateCancel
        case .alertSecondButtonReturn:
            return .terminateNow
        default:
            return .terminateCancel
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine.shutDown()
    }

    /// Closing the window parks the app in the menu bar; it keeps working.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    // MARK: Window

    private func makeWindow() {
        let hosting = NSHostingView(rootView: AboutView(engine: engine))
        hosting.frame.size = hosting.fittingSize

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: hosting.fittingSize),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        window.title = "Awake"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = Theme.canvasTop
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        window.isReleasedWhenClosed = false
        window.setContentSize(hosting.fittingSize)
        window.center()
        window.setFrameAutosaveName("AwakeMainWindow")

        NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main
        ) { [weak self] _ in
            guard let window = self?.window else { return }
            self?.engine.setWindowVisible(window.occlusionState.contains(.visible))
        }

        self.window = window
        showWindow()
    }

    @objc func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        engine.setWindowVisible(true)
    }

    // MARK: Menu bar

    private func makeStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.imagePosition = .imageOnly
        item.menu = buildStatusMenu()
        statusItem = item
        refreshStatusItem()
    }

    private func buildStatusMenu() -> NSMenu {
        let menu = NSMenu()
        let toggle = NSMenuItem(title: "Keep Awake", action: #selector(toggleFromMenu), keyEquivalent: "")
        toggle.target = self
        toggle.tag = 1
        menu.addItem(toggle)
        let show = NSMenuItem(title: "Open Awake", action: #selector(showWindow), keyEquivalent: "")
        show.target = self
        menu.addItem(show)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Awake",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        return menu
    }

    @objc private func toggleFromMenu() { engine.toggle() }

    private func refreshStatusItem() {
        let active = engine.isActive
        let image = NSImage(systemSymbolName: active ? "bolt.fill" : "bolt.slash",
                            accessibilityDescription: active ? "Awake is on" : "Awake is off")
        image?.isTemplate = true
        statusItem?.button?.image = image
        statusItem?.button?.toolTip = active ? "Awake — keeping Claude working" : "Awake — standing by"
        if let toggle = statusItem?.menu?.item(withTag: 1) {
            toggle.title = active ? "Turn Off" : "Keep Awake"
            toggle.state = active ? .on : .off
        }
    }

    // MARK: Safety net

    /// `SIGTERM` arrives on log-out and on `killall`; make sure the lid switch
    /// and the assertions come back down before we go.
    ///
    /// Deliberately handled off the main thread. A sheet puts the main run loop
    /// into a modal mode that does not drain the main queue, so a main-queue
    /// handler would never fire — and because the raw signal is ignored, the
    /// process would have become unkillable with the Options panel open.
    private func trapTerminationSignals() {
        let queue = DispatchQueue(label: "com.williamlabs.awake.signals")
        for number in [SIGTERM, SIGINT, SIGHUP] {
            signal(number, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: number, queue: queue)
            source.setEventHandler { [weak self] in
                guard let self else { exit(0) }
                self.isTerminatingFromSignal = true
                self.engine.emergencyShutDown()
                DispatchQueue.main.async { NSApp.terminate(nil) }
                // Cleanup is already done; never outlive the request to quit.
                queue.asyncAfter(deadline: .now() + 2) { exit(0) }
            }
            source.resume()
            signalSources.append(source)
        }
    }
}
