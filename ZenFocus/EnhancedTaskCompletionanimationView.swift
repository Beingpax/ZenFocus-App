import SwiftUI

struct EnhancedTaskCompletionView: View {
    // MARK: - Environment & Observed Properties
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var windowManager: WindowManager
    @AppStorage("userName") private var userName = "Pax"
    
    // MARK: - State Properties
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.8
    @State private var confettiCounter = 0
    @State private var userCongratulation: String = ""
    @State private var celebrationText: String = ""
    @State private var offset: CGFloat = 50
    @State private var showBreakTimer = false
    @State private var breakTimeRemaining = 600 // 10 minutes in seconds
    @State private var dismissing: Bool = false
    
    // MARK: - Passed Properties
    let completedTask: ZenFocusTask
    let onStartNextTask: (ZenFocusTask) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundView
                
                if showBreakTimer {
                    breakTimerView
                        .environment(\.managedObjectContext, viewContext)
                } else {
                    mainContentView(geometry: geometry)
                }
                
                ConfettiView(counter: $confettiCounter)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .opacity(dismissing ? 0 : 1)
        .animation(.easeInOut(duration: 1.5), value: dismissing)
        .edgesIgnoringSafeArea(.all)
        .onAppear(perform: startAnimation)
    }
    
    // MARK: - Subviews
    private var backgroundView: some View {
        ZStack {
            Color.black.opacity(0.4)
            
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .edgesIgnoringSafeArea(.all)
            
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(NSColor.controlAccentColor).opacity(0.3),
                    Color(NSColor.controlAccentColor).opacity(0.1)
                ]),
                center: .center,
                startRadius: 100,
                endRadius: 300
            )
        }
        .edgesIgnoringSafeArea(.all)
    }
    
    private var breakTimerView: some View {
        BreakTimerView(
            breakTimeRemaining: $breakTimeRemaining,
            showBreakTimer: $showBreakTimer,
            onStartNextTask: {
                if let nextTask = NextTaskManager.shared.getNextTask(context: viewContext) {
                    dismissAnimationView {
                        onStartNextTask(nextTask)
                    }
                }
            },
            onDismissAll: {
                dismissAnimationView {
                    onDismiss()
                }
            },
            viewContext: viewContext,
            dismissing: $dismissing
            
        )
        .transition(.opacity)
    }
    
    private func mainContentView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 30) {
            celebrationTextView
            completionHeader
            completedTaskInfo
            nextTaskSection
            actionButtons
        }
        .padding(40)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
       
        .fixedSize(horizontal: true, vertical: true)
        .opacity(opacity)
        .scaleEffect(scale)
        .offset(y: offset)
        .transition(.opacity)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
    
    // MARK: - Components
    private var completionHeader: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(Color(NSColor.systemGreen))
                .opacity(opacity)
                .scaleEffect(scale)
            
            Text("Task Completed!")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(Color(NSColor.labelColor))
            
            Text(userCongratulation)
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .foregroundColor(Color(NSColor.secondaryLabelColor))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .opacity(opacity)
    }
    
    private var completedTaskInfo: some View {
        VStack(alignment: .leading, spacing: 16) {
            taskInfoRow(title: "Task:", value: completedTask.title ?? "")
            taskInfoRow(title: "Category:", value: completedTask.category ?? "Uncategorized")
            taskInfoRow(title: "Time Spent:", value: formatDuration(completedTask.focusedDuration))
        }
        .padding(24)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
        .opacity(opacity)
    }
    
    private func taskInfoRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(Color(NSColor.secondaryLabelColor))
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(Color(NSColor.labelColor))
        }
    }
    
    private var nextTaskSection: some View {
        Group {
            if let nextTask = NextTaskManager.shared.getNextTask(context: viewContext) {
                nextTaskView(for: nextTask)
            } else {
                allTasksCompletedView
            }
        }
    }
    
    private func nextTaskView(for task: ZenFocusTask) -> some View {
        VStack(alignment: .center, spacing: 8) {
            Text("Up Next")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(Color(NSColor.secondaryLabelColor))
            
            HStack {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(Color.orange)
                    .font(.system(size: 20))
                
                Text(task.title ?? "")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(Color(NSColor.labelColor))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
        .frame(maxWidth: .infinity)
    }
    
    private var allTasksCompletedView: some View {
        Text("All tasks completed for today. Great job!")
            .font(.system(size: 24, weight: .medium, design: .rounded))
            .foregroundColor(Color(NSColor.labelColor))
            .multilineTextAlignment(.center)
            .padding(24)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
            )
    }
    
    private var actionButtons: some View {
        HStack(spacing: 20) {
            compactButton(title: "Stop ZenFocus", color: Color(NSColor.systemRed)) {
                dismissAnimationView {
                    onDismiss()
                }
            }
            
            compactButton(title: "Take a Break", color: Color.orange) {
                withAnimation {
                    showBreakTimer = true
                }
            }
            
            if let nextTask = NextTaskManager.shared.getNextTask(context: viewContext) {
                compactButton(title: "Start Next Task", color: Color(NSColor.systemGreen)) {
                    dismissAnimationView {
                        onStartNextTask(nextTask)
                    }
                }
            }
        }
    }
    
    private func compactButton(title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var celebrationTextView: some View {
        Text(celebrationText)
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundColor(Color(NSColor.labelColor))
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .opacity(opacity)
            .scaleEffect(scale)
    }
    
    // MARK: - Helper Methods
    private func startAnimation() {
        userCongratulation = getRandomUserCongratulation()
        celebrationText = getRandomCelebrationText()
        
        withAnimation(.easeInOut(duration: 0.6)) {
            opacity = 1
            scale = 1
            offset = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.confettiCounter += 1
        }
    }
    
    private func dismissAnimationView(completion: @escaping () -> Void) {
        dismissing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            windowManager.closeTaskCompletionAnimationWindow()
            completion()
        }
    }
    
    private func formatDuration(_ duration: Double) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
    
    private func getRandomUserCongratulation() -> String {
        let congratulations = [
            "Great Job, \(userName)!",
            "Well Done, \(userName)!",
            "Stellar Work, \(userName)!",
            "Way to go, \(userName)!",
            "Superb, \(userName)!",
        ]
        return congratulations.randomElement() ?? "Great job, \(userName)!"
    }
    
    private func getRandomCelebrationText() -> String {
        let celebrations = [
            "You're crushing it today!",
            "You're a task-slaying machine!",
            "High five for getting it done!",
            "You're making it happen!",
            "You're being unstoppable!",
            "You're on fire today!",
            "You're smashing goals like a boss!",
            "You're in the zone!",
            "You're a productivity powerhouse!",
            "You're moving closer to your goal!",
            "You're making magic happen!",
            "You're knocking tasks out of the park!",
            "You're a to-do list terminator!",
            "You're blazing through your tasks!",
            "You're a task-tackling titan!",
            "You're crushing goals left and right!",
            "You're in beast mode!",
            "You're a to-do list conqueror!",
            "You're making it look easy!",
        ]
        return celebrations.randomElement() ?? "Task completed"
    }
}

// MARK: - Preview
#if DEBUG
struct EnhancedTaskCompletionView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let sampleTask = ZenFocusTask(context: context)
        sampleTask.title = "Complete Project Presentation"
        sampleTask.category = "Work"
        sampleTask.focusedDuration = 3600 // 1 hour
        sampleTask.isCompleted = true
        
        return EnhancedTaskCompletionView(
            completedTask: sampleTask,
            onStartNextTask: { _ in },
            onDismiss: {}
        )
        .environmentObject(WindowManager())
        .environment(\.managedObjectContext, context)
        .previewLayout(.sizeThatFits)
        .frame(width: 800, height: 600)
    }
}
#endif
