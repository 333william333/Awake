import AppKit

// Plain AppKit entry point: no SwiftUI App lifecycle, no scene graph, no
// storyboard loading. One window, one hosting view, ~nothing else.
let application = NSApplication.shared
let controller = AppDelegate()
application.delegate = controller
application.run()
