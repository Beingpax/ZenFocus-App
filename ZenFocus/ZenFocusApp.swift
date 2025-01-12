//
//  ZenFocusApp.swift
//  ZenFocus
//
//  Created by Prakash Joshi on 04/09/2024.
//

import SwiftUI
import Sparkle
import os
import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleQuickAdd = Self("toggleQuickAdd", default: .init(.space, modifiers: [.command, .shift]))
}

@main
struct ZenFocusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var quickAddManager = QuickAddManager()
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(appState)
                .environmentObject(appDelegate)
                .environmentObject(quickAddManager)
                .onAppear {
                    checkAndTrackAppUpdate()
                    setupQuickAddManager()
                    setupQuickAddShortcut()
                    setupWindowDelegate()
                }
        }
        .commands {
            CommandGroup(after: .appSettings) {
                Button("Check for Updates...") {
                    appDelegate.updaterController.checkForUpdates(nil)
                }
                Button("Preferences...") {
                    appDelegate.showPreferences()
                }
                .keyboardShortcut(",", modifiers: .command)
                Button("Report a Problem") {
                    appDelegate.reportProblem()
                }
            }
        }
    }

    private func setupQuickAddManager() {
        let viewContext = persistenceController.container.viewContext
        quickAddManager.setup(
            viewContext: viewContext,
            categoryManager: appDelegate.categoryManager,
            onAddTask: { task in
                // Handle the newly added task here
                print("New task added: \(task.title ?? "")")
                // You might want to update your UI or perform other actions here
            }
        )
    }

    private func setupQuickAddShortcut() {
        KeyboardShortcuts.onKeyDown(for: .toggleQuickAdd) { [self] in
            quickAddManager.toggleQuickAddView()
        }
    }

    private func checkAndTrackAppUpdate() {
        let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let lastVersion = UserDefaults.standard.string(forKey: "LastAppVersion") ?? "Unknown"

        if currentVersion != lastVersion {
            UserDefaults.standard.set(currentVersion, forKey: "LastAppVersion")
        }
    }

    private func setupWindowDelegate() {
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first {
                window.delegate = appDelegate
                appDelegate.restoreWindowState(window)
            }
        }
    }
}


class AppDelegate: NSObject, ObservableObject, NSApplicationDelegate, NSWindowDelegate {
    @Published var isShowingPreferences = false
    private var preferencesWindow: NSWindow?
    let updaterController: SPUStandardUpdaterController
    @Published var quickAddManager: QuickAddManager?
    @Published var categoryManager: CategoryManager
    
    override init() {
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        let viewContext = PersistenceController.shared.container.viewContext
        categoryManager = CategoryManager(viewContext: viewContext)
        super.init()
        self.quickAddManager = QuickAddManager()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        performHealthCheck()
        updaterController.updater.checkForUpdatesInBackground()
        
        
        
        setupQuickAddManager()
        
        if let window = NSApplication.shared.windows.first {
            window.delegate = self
            restoreWindowState(window)
        }
    }
    
    private func setupQuickAddManager() {
        let viewContext = PersistenceController.shared.container.viewContext
        quickAddManager?.setup(
            viewContext: viewContext,
            categoryManager: categoryManager,
            onAddTask: { task in
                // Handle the newly added task here
                // For example, you might want to update some UI or perform some action
                print("New task added: \(task.title ?? "")")
            }
        )
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        
        if let window = NSApplication.shared.windows.first {
            saveWindowState(window)
        }
    }
    
    func showPreferences() {
        if let window = preferencesWindow {
            window.makeKeyAndOrderFront(nil)
        } else {
            createAndShowPreferencesWindow()
        }
    }
    
    private func createAndShowPreferencesWindow() {
        let preferencesView = PreferenceView()
            .environmentObject(self)
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        
        let controller = NSHostingController(rootView: preferencesView)
        let window = createWindow(withTitle: "Preferences", size: NSSize(width: 600, height: 400))
        window.contentViewController = controller
        
        centerWindowOnScreen(window)
        
        window.makeKeyAndOrderFront(nil)
        preferencesWindow = window
    }
    
    private func createWindow(withTitle title: String, size: NSSize) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.setContentSize(size)
        window.isReleasedWhenClosed = false
        return window
    }
    
    private func centerWindowOnScreen(_ window: NSWindow) {
        if let screenFrame = NSScreen.main?.visibleFrame {
            let windowFrame = NSRect(
                x: screenFrame.midX - window.frame.width / 2,
                y: screenFrame.midY - window.frame.height / 2,
                width: window.frame.width,
                height: window.frame.height
            )
            window.setFrame(windowFrame, display: true)
        }
    }
    
    func restartApp() {
        let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
        let path = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [path]
        task.launch()
        
        NSApplication.shared.terminate(nil)
    }
    
    func reportProblem() {
        let alert = createReportProblemAlert()
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            if let input = alert.accessoryView as? NSTextField {
                sendErrorReport(description: input.stringValue)
            }
        }
    }
    
    private func createReportProblemAlert() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = "Report a Problem"
        alert.informativeText = "Please describe the issue you're experiencing:"
        alert.alertStyle = .informational
        
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 100))
        input.placeholderString = "Describe the problem here..."
        alert.accessoryView = input
        
        alert.addButton(withTitle: "Send Report")
        alert.addButton(withTitle: "Cancel")
        
        return alert
    }
    
    private func sendErrorReport(description: String) {
        os_log("User reported problem: %{public}@", log: .default, type: .error, description)
        
        showConfirmationAlert()
    }
    
    private func showConfirmationAlert() {
        let alert = NSAlert()
        alert.messageText = "Thank You"
        alert.informativeText = "Your problem report has been sent. We'll investigate the issue."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func performHealthCheck() {
        if !PersistenceController.shared.isStoreAccessible() {
            os_log("Database is not accessible", log: .default, type: .error)
            showDatabaseErrorAlert()
        }
        // Add more health checks as needed
    }
    
    private func showDatabaseErrorAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Database Error"
            alert.informativeText = "There was an error accessing the database. Please restart the application. If the problem persists, please contact support."
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    func saveWindowState(_ window: NSWindow) {
        let frame = window.frame
        UserDefaults.standard.set(NSStringFromRect(frame), forKey: "MainWindowFrame")
    }

    func restoreWindowState(_ window: NSWindow) {
        if let savedFrameString = UserDefaults.standard.string(forKey: "MainWindowFrame"),
           let savedFrame = NSRectFromString(savedFrameString) as NSRect? {
            window.setFrame(savedFrame, display: true)
        }
    }

    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            saveWindowState(window)
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSApp.hide(nil)
        return false
    }
}
