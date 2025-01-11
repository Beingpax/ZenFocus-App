import AppKit

class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
}