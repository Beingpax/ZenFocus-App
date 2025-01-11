import SwiftUI
import CoreData

struct TodayFocusView: View {
    @ObservedObject var categoryManager: CategoryManager
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var windowManager: WindowManager
    @Binding var selectedView: MainView.ViewType
    
    @AppStorage("dailyGoalMinutes") private var dailyGoalMinutes: Int = 120
    @State private var totalFocusTime: TimeInterval = 0
    @State private var completedTasks: Int = 0
    @State private var animateProgress = false
    @State private var nextIncompleteTask: ZenFocusTask?
    
    @State private var lastPlanDate: Date = UserDefaults.standard.object(forKey: "lastPlanDate") as? Date ?? Date.distantPast
    
    @FetchRequest private var todayTasks: FetchedResults<ZenFocusTask>
    
    init(categoryManager: CategoryManager, selectedView: Binding<MainView.ViewType>) {
        self.categoryManager = categoryManager
        self._selectedView = selectedView
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let predicate = NSPredicate(format: "scheduledDate >= %@ AND scheduledDate < %@ AND isCompleted == NO", today as NSDate, tomorrow as NSDate)
        self._todayTasks = FetchRequest(
            sortDescriptors: [
                NSSortDescriptor(keyPath: \ZenFocusTask.customOrder, ascending: true),
                NSSortDescriptor(keyPath: \ZenFocusTask.scheduledDate, ascending: true)
            ],
            predicate: predicate,
            animation: .default
        )
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 20) {
                // Left side
                ScrollView {
                    VStack(spacing: 24) {
                        summarySection
                    }
                    .frame(width: geometry.size.width * 0.35)
                }
                
                // Right side
                VStack(spacing: 24) {
                    taskListSection
                    nextTaskSection
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding()
        }
        .background(Color.clear)
        .onAppear {
            ZenFocusLogger.shared.info("TodayFocusView appeared")
            updateMetrics()
            animateProgress = true
        }
        .onDisappear {
            ZenFocusLogger.shared.info("TodayFocusView disappeared")
        }
        .onReceive(NotificationCenter.default.publisher(for: .taskCompleted)) { _ in
            ZenFocusLogger.shared.info("Task completed notification received")
            updateMetrics()
        }
    }
    
    private var summarySection: some View {
        VStack(spacing: 24) {
            cardView(title: "Focus Progress", icon: "chart.pie.fill", color: .purple) {
                progressView
            }
            
            cardView(title: "Daily Stats", icon: "chart.bar.fill", color: .blue) {
                statsGridView
            }
        }
    }
    
    private var progressView: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(formatDuration(totalFocusTime))
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Goal: \(formatDuration(Double(max(dailyGoalMinutes, 1) * 60)))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("\(progressPercentage)% Complete")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 20)
                
                Circle()
                    .trim(from: 0, to: animateProgress ? CGFloat(progressRatio) : 0)
                    .stroke(
                        LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]),
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: animateProgress)
                
                VStack {
                    Text("\(progressPercentage)%")
                        .font(.system(size: 32, weight: .bold))
                    Text("of daily goal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 120, height: 120)
        }
    }
    
    private var progressRatio: Double {
        guard dailyGoalMinutes > 0 else { return 0 }
        return min(totalFocusTime / Double(dailyGoalMinutes * 60), 1.0)
    }
    
    private var progressPercentage: Int {
        Int(progressRatio * 100)
    }
    
    private var statsGridView: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCard(title: "Tasks Completed", value: "\(completedTasks)", icon: "checkmark.circle.fill", color: .green)
            StatCard(title: "Remaining", value: "\(todayTasks.count)", icon: "list.bullet", color: .blue)
        }
    }
    
    private var taskListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            CardHeaderView(title: "Today's Tasks", icon: "list.bullet.rectangle", color: .green)
            
            GeometryReader { geometry in
                VStack {
                    if todayTasks.isEmpty {
                        Text("You have no tasks scheduled for today. Plan your day now to get the most out of it")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        List {
                            ForEach(todayTasks) { task in
                                BetterTaskRow(task: task, categoryManager: categoryManager, onDelete: {
                                    deleteTask(task)
                                }, onToggleCompletion: {
                                    toggleTaskCompletion(task)
                                })
                            }
                        }
                        .listStyle(PlainListStyle())
                        .background(Color.clear)
                        .scrollContentBackground(.hidden)
                    }
                }
                .frame(height: max(300, geometry.size.height - 100))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    private var nextTaskSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            CardHeaderView(
                title: todayTasks.isEmpty ? "Plan Your Day" : "Next Up",
                icon: todayTasks.isEmpty ? "calendar" : "arrow.right.circle.fill",
                color: .orange
            )
            
            HStack(spacing: 16) {
                if let nextTask = NextTaskManager.shared.getNextTask(context: viewContext) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(nextTask.title ?? "")
                            .font(.headline)
                            .lineLimit(1)
                        if let category = nextTask.categoryRef {
                            Text(category.name ?? "")
                                .font(.subheadline)
                                .foregroundColor(categoryManager.colorForCategory(category))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("You have no tasks scheduled for today.")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        if todayTasks.isEmpty {
                            selectedView = .kanbanBoard
                        } else {
                            startFocusSession()
                        }
                    }
                }) {
                    Text(todayTasks.isEmpty ? "Plan Your Day" : "Let's Crush It! 💪")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(
                            LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]),
                                           startPoint: .leading,
                                           endPoint: .trailing)
                        )
                        .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    private func cardView<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.2))
                    .clipShape(Circle())
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            content()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    private func updateMetrics() {
    ZenFocusLogger.shared.info("Updating metrics")
    DispatchQueue.global(qos: .userInitiated).async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let request: NSFetchRequest<ZenFocusTask> = ZenFocusTask.fetchRequest()
        request.predicate = NSPredicate(format: "completedAt >= %@ AND completedAt < %@ AND isCompleted == YES", today as NSDate, tomorrow as NSDate)
        
        do {
            let tasks = try self.viewContext.fetch(request)
            let focusTime = tasks.reduce(0) { $0 + $1.focusedDuration }
            let completed = tasks.count
            
            DispatchQueue.main.async {
                self.totalFocusTime = focusTime
                self.completedTasks = completed
                ZenFocusLogger.shared.info("Metrics updated - Total focus time: \(focusTime), Completed tasks: \(completed)")
            }
        } catch {
            ZenFocusLogger.shared.error("Error fetching tasks: \(error)")
        }
    }
}
    
    private func startFocusSession() {
        guard let nextTask = NextTaskManager.shared.getNextTask(context: viewContext) else {
            ZenFocusLogger.shared.warning("Attempted to start focus session with no incomplete tasks")
            return
        }
        ZenFocusLogger.shared.info("Starting focus session for task: \(nextTask.title ?? "")")
        startFocusSession(for: nextTask)
    }
    
    private func startFocusSession(for task: ZenFocusTask) {
        windowManager.showFocusedTaskWindow(
            for: task,
            onComplete: { completedTask in
                ZenFocusLogger.shared.info("Focus session completed for task: \(task.title ?? "")")
                task.isCompleted = true
                task.completedAt = Date()
                do {
                    try viewContext.save()
                    ZenFocusLogger.shared.info("Task marked as completed and saved")
                    NotificationCenter.default.post(name: .taskCompleted, object: nil)
                    updateMetrics()
                    
                    // Show the task completion animation with next task info
                    windowManager.showTaskCompletionAnimation(
                        for: task,
                        onStartNextTask: { nextTask in
                            self.startFocusSession(for: nextTask)
                        },
                        onDismiss: {
                            self.windowManager.showMainWindow()
                        }
                    )
                } catch {
                    ZenFocusLogger.shared.error("Failed to save completed task: \(error.localizedDescription)")
                    // Show an alert to the user
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "Error Saving Completed Task"
                        alert.informativeText = "There was an error saving the completed task. Please try again."
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                    }
                }
            },
            onBreak: {
                ZenFocusLogger.shared.info("Break started for task: \(task.title ?? "")")
                // Handle break
            }
        )
    }
    
    private func formatDuration(_ duration: Double) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return String(format: "%dh %dm", hours, minutes)
    }
    
    private func toggleTaskCompletion(_ task: ZenFocusTask) {
        task.isCompleted.toggle()
        if task.isCompleted {
            task.completedAt = Date()
        } else {
            task.completedAt = nil
        }
        
        do {
            try viewContext.save()
            ZenFocusLogger.shared.info("Task completion toggled: \(task.title ?? ""), Completed: \(task.isCompleted)")
            updateMetrics()
        } catch {
            ZenFocusLogger.shared.error("Failed to save task completion state: \(error.localizedDescription)")
            // Show an alert to the user
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Error Saving Task State"
                alert.informativeText = "There was an error saving the task state. Please try again."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }
    
    private func deleteTask(_ task: ZenFocusTask) {
        viewContext.delete(task)
        do {
            try viewContext.save()
            ZenFocusLogger.shared.info("Task deleted: \(task.title ?? "")")
            updateMetrics()
        } catch {
            ZenFocusLogger.shared.error("Failed to delete task: \(error.localizedDescription)")
            // Show an alert to the user
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Error Deleting Task"
                alert.informativeText = "There was an error deleting the task. Please try again."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }
}
