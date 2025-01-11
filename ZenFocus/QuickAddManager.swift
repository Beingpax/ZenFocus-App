import SwiftUI
import AppKit
import KeyboardShortcuts
import CoreData

class QuickAddManager: NSObject, ObservableObject {
    @Published var isQuickAddVisible = false
    private var quickAddWindow: BorderlessWindow?
    private var viewContext: NSManagedObjectContext?
    private var categoryManager: CategoryManager?
    private var onAddTask: ((ZenFocusTask) -> Void)?

    func setup(viewContext: NSManagedObjectContext, categoryManager: CategoryManager, onAddTask: @escaping (ZenFocusTask) -> Void) {
        self.viewContext = viewContext
        self.categoryManager = categoryManager
        self.onAddTask = onAddTask
        createQuickAddWindow()
    }
 
    func toggleQuickAddView() {
        if isQuickAddVisible {
            hideQuickAddView()
        } else {
            showQuickAddView()
        }
    }

    private func createQuickAddWindow() {
        guard let viewContext = viewContext, let categoryManager = categoryManager, let onAddTask = onAddTask else { return }
        
        let contentView = QuickAddView(onSubmit: { task in
            onAddTask(task)
            self.hideQuickAddView()
        }, onCancel: {
            self.hideQuickAddView()
        })
        .environment(\.managedObjectContext, viewContext)
        .environmentObject(categoryManager)

        let window = BorderlessWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 60),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.backgroundColor = NSColor.clear
        window.level = NSWindow.Level.popUpMenu // Changed from .floating to .popUpMenu
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle] // Added .ignoresCycle
        window.contentView = NSHostingView(rootView: contentView)
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.delegate = self

        self.quickAddWindow = window
    }

    func showQuickAddView() {
        guard let window = quickAddWindow else { return }
        
        // Ensure the window is created and ready
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.center()
            self.isQuickAddVisible = true
            
            // Force the window to be the key window
            window.makeKey()
            
            // Focus on the text field immediately
            self.focusTextField()
        }
    }

    func hideQuickAddView() {
        DispatchQueue.main.async {
            self.quickAddWindow?.orderOut(nil)
            self.isQuickAddVisible = false
        }
    }

    private func focusTextField() {
        guard let window = quickAddWindow,
              let contentView = window.contentView as? NSHostingView<QuickAddView> else { return }
        
        // Find and focus the NSTextField
        if let textField = findTextField(in: contentView) {
            window.makeFirstResponder(textField)
        }
    }

    private func findTextField(in view: NSView) -> NSTextField? {
        if let textField = view as? NSTextField {
            return textField
        }
        for subview in view.subviews {
            if let textField = findTextField(in: subview) {
                return textField
            }
        }
        return nil
    }
}

extension QuickAddManager: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        hideQuickAddView()
    }
}

class BorderlessWindow: NSWindow {
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        
        self.isOpaque = false
        self.hasShadow = true
        self.level = NSWindow.Level.popUpMenu // Changed from .floating to .popUpMenu
        self.backgroundColor = NSColor.clear
    }
    
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // 53 is the key code for Esc
            (self.delegate as? QuickAddManager)?.hideQuickAddView()
        } else {
            super.keyDown(with: event)
        }
    }
}
