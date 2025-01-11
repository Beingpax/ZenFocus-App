import Cocoa
import SwiftUI


class FocusSessionWindowController: NSWindowController {
    var task: ZenFocusTask
    weak var windowManager: WindowManager?
    
    init(task: ZenFocusTask, windowManager: WindowManager) {
        self.task = task
        self.windowManager = windowManager
        
        let panel = KeyablePanel(
            contentRect: NSRect(x: 100, y: 100, width: 400, height: 60),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.center()
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.maxSize = NSSize(width: 500, height: 50)
        
        super.init(window: panel)
        
        let contentView = FocusSessionView(task: task, windowController: self)
            .environmentObject(windowManager)
        panel.contentView = NSHostingView(rootView: contentView)
        
        // Adjust window size based on content
        if let contentView = panel.contentView {
            panel.setContentSize(contentView.fittingSize)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func close() {
        super.close()
        windowManager?.focusedWindow = nil
    }
    
    func endSession() {
        self.close()
    }
}