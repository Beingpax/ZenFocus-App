import SwiftUI
import CoreData
import AppKit

struct FocusSessionView: View {
    @ObservedObject var task: ZenFocusTask
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var isPaused: Bool = false
    @State private var lastUpdateTime: Date?
    @State private var isCompleteHovering = false
    @State private var isBreakHovering = false
    @State private var opacity: Double = 0
    @State private var yOffset: CGFloat = 20
    @State private var gradientAngle: Double = 0
    @State private var showMusicPopover = false
    @AppStorage("autoPlayFocusMusic") private var autoPlayFocusMusic = true

    @EnvironmentObject var windowManager: WindowManager
    @StateObject private var reminderSoundManager = ReminderSoundManager()
    @StateObject private var musicManager = MusicManager.shared
    weak var windowController: FocusSessionWindowController?
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        HStack(spacing: 12) {
            Text(task.title ?? "")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundColor(Color(NSColor.textColor))
            
            timerView
            
            completeButton
            
            breakButton
            
            musicButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(NSColor.controlBackgroundColor).opacity(0.3),
                        Color(NSColor.controlBackgroundColor).opacity(0.1)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
        
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.6)) {
                opacity = 1
                yOffset = 0
            }
            startTimer()
            reminderSoundManager.startReminderTimer()
            
            // Only start playing music if autoPlayFocusMusic is enabled
            if autoPlayFocusMusic {
                // Start playing first track if available
                if let firstTrack = musicManager.tracks.first {
                    musicManager.play(track: firstTrack)
                }
            }
        }
        .onDisappear {
            stopTimer()
            reminderSoundManager.stopReminderTimer()
            musicManager.stop()
        }
    }
    
    private var timerView: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .foregroundColor(Color(NSColor.secondaryLabelColor))
                .font(.system(size: 12))
            Text(timeString(from: elapsedTime))
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(Color(NSColor.labelColor))
                .frame(width: 50, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private var completeButton: some View {
        Button(action: completeTask) {
            Image(systemName: isCompleteHovering ? "checkmark.circle.fill" : "checkmark")
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color(NSColor.systemGreen))
                .clipShape(Circle())
                .scaleEffect(isCompleteHovering ? 1.1 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isCompleteHovering = hovering
            }
        }
    }
    
    private var breakButton: some View {
        Button(action: togglePause) {
            Image(systemName: isPaused ? "play.circle.fill" : "pause.fill")
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color(NSColor.systemOrange))
                .clipShape(Circle())
                .scaleEffect(isBreakHovering ? 1.1 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isBreakHovering = hovering
            }
        }
    }
    
    private var musicButton: some View {
        Button(action: { showMusicPopover.toggle() }) {
            Image(systemName: "music.note.list")
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color(NSColor.systemBlue))
                .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
        .popover(isPresented: $showMusicPopover) {
            MusicPopoverView(musicManager: musicManager)
                .frame(width: 200, height: 300)
        }
    }
    
    private func startTimer() {
        lastUpdateTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if !isPaused {
                let now = Date()
                if let lastUpdate = lastUpdateTime {
                    let timeDifference = now.timeIntervalSince(lastUpdate)
                    elapsedTime += timeDifference
                    task.focusedDuration += timeDifference
                    try? task.managedObjectContext?.save()
                }
                lastUpdateTime = now
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func togglePause() {
        isPaused.toggle()
        if isPaused {
            lastUpdateTime = nil
            reminderSoundManager.stopReminderTimer()
            musicManager.pause()
            windowManager.showFocusPauseScreen(
                onResume: {
                    self.isPaused = false
                    self.lastUpdateTime = Date()
                    self.reminderSoundManager.startReminderTimer()
                    if self.autoPlayFocusMusic {
                        self.musicManager.resume()
                    }
                }
            )
        } else {
            lastUpdateTime = Date()
            reminderSoundManager.startReminderTimer()
            if autoPlayFocusMusic {
                musicManager.resume()
            }
        }
        NotificationCenter.default.post(
            name: .taskPauseStateChanged,
            object: nil,
            userInfo: ["taskID": task.objectID, "isPaused": isPaused]
        )
    }
    
    private func completeTask() {
        // Stop the timer
        stopTimer()
        
        // Stop music regardless of autoPlayFocusMusic setting
        // since the session is ending
        musicManager.stop()
        
        // Update the task
        task.isCompleted = true
        task.completedAt = Date()
        
        // Save the context
        do {
            try task.managedObjectContext?.save()
            print("Task saved successfully")
        } catch {
            print("Error saving task: \(error)")
        }
        
        // Post notification
        NotificationCenter.default.post(name: .taskCompleted, object: nil)
        
        // Close the focused task window
        windowController?.close()
        
        windowManager.showTaskCompletionAnimation(
            for: task,
            onStartNextTask: { nextTask in
                // Handle starting the next task
                windowManager.showFocusedTaskWindow(
                    for: nextTask,
                    onComplete: { _ in },
                    onBreak: {}
                )
            },
            onDismiss: {
                // This is now handled by closing the window earlier
            }
        )
        
        reminderSoundManager.stopReminderTimer()
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// Add this new view to create the frosted glass effect
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }

    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}

// Update only the FocusSessionView_Previews struct at the end of the file

struct FocusSessionView_Previews: PreviewProvider {
    static var previews: some View {
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        let task = ZenFocusTask(context: context)
        task.title = "Sample Task"
        task.focusedDuration = 300 // 5 minutes
        
        return FocusSessionView(task: task)
            .environmentObject(WindowManager())
            .previewLayout(.sizeThatFits)
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            .environment(\.managedObjectContext, context)
    }
}
