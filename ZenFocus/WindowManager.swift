import SwiftUI
import AppKit
import AVFoundation

class WindowManager: ObservableObject {
    @Published var focusedWindow: NSWindow?
    @Published var isMainWindowHidden = false
    weak var mainWindow: NSWindow?
    
    private var fullScreenAnimationWindow: NSWindow?
    private var audioPlayer: AVAudioPlayer?
    private var animationWindow: NSWindow?
    private var eventMonitor: Any?
    
    private var isAnimating = false
    private let animationQueue = DispatchQueue(label: "com.zenfocus.windowanimation")
    
    @AppStorage("showFocusStartAnimation") private var showFocusStartAnimation = true
    
    private var pauseWindow: NSWindow?
    
    init() {
        DispatchQueue.main.async {
            self.mainWindow = NSApplication.shared.windows.first
            self.setMainWindowSizeAndPosition()
        }
    }
    
    func setMainWindowSizeAndPosition() {
        guard let mainWindow = mainWindow else {
            ZenFocusLogger.shared.warning("Failed to set main window size and position: mainWindow is nil")
            return
        }

        if let savedFrameString = UserDefaults.standard.string(forKey: "MainWindowFrame"),
           let savedFrame = NSRectFromString(savedFrameString) as NSRect? {
            mainWindow.setFrame(savedFrame, display: true)
        } else {
            // Use default size and position if no saved state
            guard let screen = NSScreen.main else {
                ZenFocusLogger.shared.warning("Failed to set main window size and position: screen is nil")
                return
            }
            
            let windowSize = NSSize(width: 1000, height: 600)
            let screenRect = screen.visibleFrame
            let newOrigin = NSPoint(
                x: screenRect.midX - windowSize.width / 2,
                y: screenRect.midY - windowSize.height / 2
            )
            
            mainWindow.setFrame(NSRect(origin: newOrigin, size: windowSize), display: true)
        }
        
        ZenFocusLogger.shared.info("Main window size and position set successfully")
    }
    
    func showFocusedTaskWindow(for task: ZenFocusTask, onComplete: @escaping (ZenFocusTask) -> Void, onBreak: @escaping () -> Void) {
        DispatchQueue.main.async {
            // Reset state and minimize main window
            self.isMainWindowHidden = false  // Reset state
            self.hideMainWindowWithAnimation()
            
            if self.showFocusStartAnimation {
                // Play sound and show animation
                self.playFocusSound()
                self.showFullScreenAnimation(for: task) {
                    self.removeAnimationWindow()
                    self.createAndShowFocusedTaskWindow(for: task, onComplete: onComplete, onBreak: onBreak)
                }
            } else {
                // Skip animation and sound, show focus window directly
                self.createAndShowFocusedTaskWindow(for: task, onComplete: onComplete, onBreak: onBreak)
            }
            
            ZenFocusLogger.shared.info("Focused task window shown for task: \(task.title ?? "")")
        }
    }
    
    private func showFullScreenAnimation(for task: ZenFocusTask, completion: @escaping () -> Void) {
        guard let screen = NSScreen.main else {
            ZenFocusLogger.shared.error("Failed to show full screen animation: No main screen found")
            completion()
            return
        }
        
        let animationView = FocusStartAnimationView(task: task, completion: {
            self.removeAnimationWindow()
            completion()
        })
        let hostingView = NSHostingView(rootView: animationView)
        
        let window = KeyablePanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .screenSaver
        window.ignoresMouseEvents = false
        
        self.animationWindow = window
        window.makeKeyAndOrderFront(nil)
        
        self.eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown]) { _ in
            return nil
        }
        
        ZenFocusLogger.shared.info("Full screen animation shown for task: \(task.title ?? "")")
    }
    
    
    
    private func removeAnimationWindow() {
        DispatchQueue.main.async {
            self.animationWindow?.close()
            self.animationWindow = nil
            
            if let eventMonitor = self.eventMonitor {
                NSEvent.removeMonitor(eventMonitor)
                self.eventMonitor = nil
            }
            
            ZenFocusLogger.shared.info("Animation window removed")
        }
    }

    private func playFocusSound() {
        guard let soundURL = Bundle.main.url(forResource: "focus_sound", withExtension: "mp3") else {
            ZenFocusLogger.shared.warning("Focus sound file not found")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.play()
            ZenFocusLogger.shared.info("Focus sound played successfully")
        } catch {
            ZenFocusLogger.shared.error("Error playing focus sound", error: error)
        }
    }
    
    private func createAndShowFocusedTaskWindow(for task: ZenFocusTask, onComplete: @escaping (ZenFocusTask) -> Void, onBreak: @escaping () -> Void) {
        guard let screen = NSScreen.main else {
            ZenFocusLogger.shared.error("No main screen found")
            return
        }
        
        let windowController = FocusSessionWindowController(task: task, windowManager: self)
        let focusedView = FocusSessionView(task: task, windowController: windowController)
            .environmentObject(self)
        
        windowController.contentViewController = NSHostingController(rootView: focusedView)
        
        guard let window = windowController.window else {
            ZenFocusLogger.shared.error("Failed to create focused task window")
            return
        }
        
        window.setContentSize(window.contentView!.fittingSize)
        
        let windowWidth = window.frame.width
        let padding: CGFloat = 20
        
        let newOrigin = NSPoint(
            x: screen.visibleFrame.midX - windowWidth / 2,
            y: screen.visibleFrame.minY + padding
        )
        window.setFrameOrigin(newOrigin)
        
        windowController.showWindow(nil)
        self.focusedWindow = window
        
        ZenFocusLogger.shared.info("Focused task window created and shown for task: \(task.title ?? "")")
    }
    
    func closeFocusedTaskWindow() {
        DispatchQueue.main.async {
            self.focusedWindow?.close()
            self.focusedWindow = nil
            ZenFocusLogger.shared.info("Focused task window closed")
        }
    }
    
    func hideMainWindow() {
        mainWindow?.orderOut(nil)
        isMainWindowHidden = true
        ZenFocusLogger.shared.info("Main window hidden")
    }
    
    func showMainWindow() {
        guard let mainWindow = mainWindow, isMainWindowHidden else {
            ZenFocusLogger.shared.warning("Cannot show main window: window is nil or not hidden")
            return
        }
        setMainWindowSizeAndPosition()
        mainWindow.makeKeyAndOrderFront(nil)
        isMainWindowHidden = false
        ZenFocusLogger.shared.info("Main window shown")
    }
    
    func showTaskCompletionAnimation(
        for task: ZenFocusTask,
        onStartNextTask: @escaping (ZenFocusTask) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        // Close the focused task window if it's still open
        closeFocusedTaskWindow()

        guard let screen = NSScreen.main else {
            ZenFocusLogger.shared.error("No main screen found for task completion animation")
            onDismiss()
            return
        }
        
        let animationView = EnhancedTaskCompletionView(
            completedTask: task,
            onStartNextTask: onStartNextTask,
            onDismiss: onDismiss
        )
        .environmentObject(self)
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        
        let hostingView = NSHostingView(rootView: animationView)
        
        let window = KeyablePanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .screenSaver
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        window.styleMask.insert(.nonactivatingPanel)
        window.hidesOnDeactivate = false
        
        self.animationWindow = window
        
        DispatchQueue.main.async {
            window.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
        }
        
        self.playTaskCompletionSound()
        
        ZenFocusLogger.shared.info("Enhanced task completion animation shown for task: \(task.title ?? "")")
    }
    
    private func playTaskCompletionSound() {
        guard let soundURL = Bundle.main.url(forResource: "task_complete", withExtension: "mp3") else {
            ZenFocusLogger.shared.warning("Task completion sound file not found")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.play()
            ZenFocusLogger.shared.info("Task completion sound played successfully")
        } catch {
            ZenFocusLogger.shared.error("Error playing task completion sound", error: error)
        }
    }
    
    @AppStorage("autoShowHideMainWindow") private var autoShowHideMainWindow = true

    func hideMainWindowWithAnimation() {
        guard autoShowHideMainWindow else {
            ZenFocusLogger.shared.debug("Auto show/hide is disabled. Skipping minimize.")
            return
        }
        
        guard let mainWindow = mainWindow else {
            ZenFocusLogger.shared.error("Main window is nil. Cannot minimize.")
            return
        }
        
        guard !isMainWindowHidden else {
            ZenFocusLogger.shared.debug("Main window is already minimized. Skipping minimize.")
            return
        }
        
        guard !isAnimating else {
            ZenFocusLogger.shared.debug("Animation already in progress. Skipping minimize.")
            return
        }
        
        isAnimating = true
        
        // Use native macOS minimize animation
        mainWindow.miniaturize(nil)
        isMainWindowHidden = true
        isAnimating = false
        ZenFocusLogger.shared.info("Main window minimized")
    }
    
    func showMainWindowWithAnimation() {
        guard autoShowHideMainWindow else {
            ZenFocusLogger.shared.debug("Auto show/hide is disabled. Skipping deminimize.")
            return
        }
        
        guard let mainWindow = mainWindow else {
            ZenFocusLogger.shared.error("Main window is nil. Cannot deminimize.")
            return
        }
        
        guard isMainWindowHidden else {
            ZenFocusLogger.shared.debug("Main window is already visible. Skipping deminimize.")
            return
        }
        
        guard !isAnimating else {
            ZenFocusLogger.shared.debug("Animation already in progress. Skipping deminimize.")
            return
        }
        
        isAnimating = true
        
        // Deminiaturize the window
        mainWindow.deminiaturize(nil)
        
        // Add a small delay to ensure the window is fully deminiaturized
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isMainWindowHidden = false
            self.isAnimating = false
            
            // Make sure the window is in front
            mainWindow.makeKeyAndOrderFront(nil)
            
            ZenFocusLogger.shared.info("Main window deminiaturized")
        }
    }

    private func handleAnimationError(_ error: Error) {
        ZenFocusLogger.shared.error("Animation error occurred", error: error)
        DispatchQueue.main.async { [weak self] in
            self?.isAnimating = false
            self?.isMainWindowHidden = self?.mainWindow?.isVisible == false
        }
    }
    
    func closeTaskCompletionAnimationWindow() {
        DispatchQueue.main.async {
            self.animationWindow?.close()
            self.animationWindow = nil
            ZenFocusLogger.shared.info("Task completion animation window closed")
        }
    }
    
    func showFocusPauseScreen(onResume: @escaping () -> Void) {
        guard let screen = NSScreen.main else { return }
        
        let pauseView = FocusSessionPauseView(
            dismissing: .constant(false),
            onResume: {
                self.closePauseWindow()
                onResume()
            },
            onHide: {
                self.closePauseWindow()
            }
        )
        
        let window = KeyablePanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.contentView = NSHostingView(rootView: pauseView)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.ignoresMouseEvents = false
        window.hidesOnDeactivate = false
        
        self.pauseWindow = window
        window.makeKeyAndOrderFront(nil)
        
        ZenFocusLogger.shared.info("Focus pause screen shown")
    }
    
    func closePauseWindow() {
        DispatchQueue.main.async {
            self.pauseWindow?.close()
            self.pauseWindow = nil
            ZenFocusLogger.shared.info("Focus pause screen closed")
        }
    }
}

