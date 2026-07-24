import AppKit

// The app is assembled entirely in code: no MainMenu.xib, no storyboard. Those
// are machine-generated XML — the same merge-conflict source this project uses
// XcodeGen to keep out of the project file (ADR-0006). This file is the
// executable's entry point, standing in for @NSApplicationMain.
let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.regular)
application.run()
