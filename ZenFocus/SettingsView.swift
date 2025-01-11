import SwiftUI
import CoreData
import Sparkle
import AppKit
import KeyboardShortcuts

struct SettingsView: View {
    @EnvironmentObject var appDelegate: AppDelegate
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingResetConfirmation = false
    
    @AppStorage("reminderInterval") private var reminderInterval = 600
    @AppStorage("reminderSound") private var reminderSound = "Glass"
    @AppStorage("userName") private var userName = ""
    @AppStorage("customCode") private var customCode = "Ready to get shit done?"
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @AppStorage("autoShowHideMainWindow") private var autoShowHideMainWindow = true
    @AppStorage("showFocusStartAnimation") private var showFocusStartAnimation = true
    @AppStorage("autoPlayFocusMusic") private var autoPlayFocusMusic = true
    
    let availableSounds = ["Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero", "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                personalSettingsSection
                focusSessionSection
                reminderSection
                keyboardShortcutsSection
                dataManagementSection
            }
            .padding(30)
        }
        .frame(maxWidth: 700)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var personalSettingsSection: some View {
        SettingsSection(
            title: "Personal Settings",
            icon: "person.fill",
            color: .blue
        ) {
            VStack(alignment: .leading, spacing: 16) {
                SettingsTextField(title: "Your Name", text: $userName)
                    .help("Your name will be used to personalize the app experience")
                
                SettingsTextField(title: "Custom Quote", text: $customCode)
                    .help("This quote will be shown on your dashboard")
            }
        }
    }
    
    private var focusSessionSection: some View {
        SettingsSection(
            title: "Focus Session",
            icon: "bolt.circle.fill",
            color: .orange
        ) {
            VStack(alignment: .leading, spacing: 16) {
                SettingsToggle(
                    title: "Show focus start animation",
                    description: "Display an animation when starting a focus session",
                    isOn: $showFocusStartAnimation
                )
                
                SettingsToggle(
                    title: "Auto minimize main window",
                    description: "Automatically minimize the main window during focus sessions",
                    isOn: $autoShowHideMainWindow
                )
                
                SettingsToggle(
                    title: "Auto-play focus music",
                    description: "Automatically start playing focus music when session begins",
                    isOn: $autoPlayFocusMusic
                )
            }
        }
    }
    
    private var reminderSection: some View {
        SettingsSection(
            title: "Reminders",
            icon: "bell.fill",
            color: .purple
        ) {
            VStack(alignment: .leading, spacing: 16) {
                SettingsPicker(
                    title: "Reminder Interval",
                    description: "How often you want to be reminded during focus sessions",
                    selection: $reminderInterval
                ) {
                    Text("5 minutes").tag(300)
                    Text("10 minutes").tag(600)
                    Text("15 minutes").tag(900)
                    Text("20 minutes").tag(1200)
                    Text("30 minutes").tag(1800)
                }
                
                SettingsPicker(
                    title: "Reminder Sound",
                    description: "The sound that plays for reminders",
                    selection: $reminderSound
                ) {
                    ForEach(availableSounds, id: \.self) { sound in
                        Text(sound).tag(sound)
                    }
                }
                
                Button("Test Sound") {
                    testSound()
                }
                .buttonStyle(MacButtonStyle())
            }
        }
    }
    
    private var keyboardShortcutsSection: some View {
        SettingsSection(
            title: "Keyboard Shortcuts",
            icon: "keyboard",
            color: .indigo
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Quick Add Task")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    KeyboardShortcuts.Recorder(for: .toggleQuickAdd)
                }
                
                Text("Use this shortcut to quickly add a new task from anywhere")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var dataManagementSection: some View {
        SettingsSection(
            title: "Data Management",
            icon: "externaldrive.fill",
            color: .red
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Button("Reset Settings") {
                    showingResetConfirmation = true
                }
                .buttonStyle(MacDestructiveButtonStyle())
                .alert(isPresented: $showingResetConfirmation) {
                    Alert(
                        title: Text("Reset Settings"),
                        message: Text("Are you sure you want to reset all settings? This will reset your preferences and show the onboarding view again. Your tasks and categories will be preserved."),
                        primaryButton: .destructive(Text("Reset")) {
                            resetSettings()
                        },
                        secondaryButton: .cancel()
                    )
                }
                
                Text("This will reset all settings to their default values")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func testSound() {
        if let sound = NSSound(named: NSSound.Name(reminderSound)) {
            sound.play()
        }
    }
    
    private func resetSettings() {
        // Reset UserDefaults but preserve specific keys
        if let bundleID = Bundle.main.bundleIdentifier {
            let defaults = UserDefaults.standard
            let dictionary = defaults.dictionaryRepresentation()
            dictionary.keys.forEach { key in
                // Skip resetting certain keys that should be preserved
                let keysToPreserve = [
                    "LastAppVersion",
                    // Add any other keys you want to preserve
                ]
                
                if !keysToPreserve.contains(key) {
                    defaults.removeObject(forKey: key)
                }
            }
        }
        
        // Reset settings to default values
        reminderInterval = 600
        reminderSound = "Glass"
        userName = ""
        customCode = "Ready to get shit done?"
        hasCompletedOnboarding = false // This will trigger the onboarding view
        
        // Show confirmation and restart alert
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Settings Reset Complete"
            alert.informativeText = "Settings have been reset. The app will now restart to show the onboarding view."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Restart Now")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                restartApp()
            }
        }
    }
    
    private func restartApp() {
        appDelegate.restartApp()
    }
    
    private func initializeDefaultValues() {
        // Reinitialize your default values here
        reminderInterval = 600
        reminderSound = "Glass"
        userName = ""
        customCode = "Ready to get shit done?"
        
        // You may need to reinitialize other UserDefaults values or CoreData entities here
    }
    
    struct SettingsTextField: View {
        let title: String
        @Binding var text: String
        
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                TextField("", text: $text)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
        }
    }
    
    struct SettingsToggle: View {
        let title: String
        let description: String
        @Binding var isOn: Bool
        
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Toggle(title, isOn: $isOn)
                    .toggleStyle(SwitchToggleStyle())
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    struct SettingsPicker<SelectionValue: Hashable, Content: View>: View {
        let title: String
        let description: String
        @Binding var selection: SelectionValue
        @ViewBuilder let content: () -> Content
        
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker(title, selection: $selection) {
                    content()
                }
                .pickerStyle(DefaultPickerStyle())
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    struct SettingsView_Previews: PreviewProvider {
        static var previews: some View {
            SettingsView()
                .environmentObject(AppDelegate())
                .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        }
    }
}

// Helper Views
struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content
    
    init(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
            }
            
            content
                .padding(.leading, 24)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}



struct MacDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.1))
            .foregroundColor(.red)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}
