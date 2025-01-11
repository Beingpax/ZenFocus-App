import SwiftUI
import CoreData

struct TasksView: View {
    @ObservedObject var categoryManager: CategoryManager
    @Binding var showDailyPlan: Bool
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("dailyGoalMinutes") private var dailyGoalMinutes: Int = 120
    @State private var animateProgress = false
    var onPlanDay: () -> Void
    var onStartDay: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            TaskListView(categoryManager: categoryManager)
                .frame(minWidth: 350, idealWidth: 400, maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
            
            VStack(spacing: 20) {
                todayProgressSection
                dailyHighlightsSection
                Spacer()
                planYourDayButton
            }
            .frame(minWidth: 200)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
        }
        .padding()
        .onAppear {
            animateProgress = true
        }
    }
    
    private var todayProgressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            CardHeaderView(title: "Today's Focus", icon: "chart.pie.fill", color: .purple)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(formatDuration(focusedDurationToday))
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Goal: \(formatDuration(Double(dailyGoalMinutes * 60)))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(min(focusedDurationToday / Double(dailyGoalMinutes * 60), 1.0) * 100))% Complete")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 20)
                    
                    Circle()
                        .trim(from: 0, to: animateProgress ? CGFloat(min(focusedDurationToday / Double(dailyGoalMinutes * 60), 1.0)) : 0)
                        .stroke(
                            LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]),
                                           startPoint: .topLeading,
                                           endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 20, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 1.0), value: animateProgress)
                    
                    VStack {
                        Text("\(Int(min(focusedDurationToday / Double(dailyGoalMinutes * 60), 1.0) * 100))%")
                            .font(.system(size: 32, weight: .bold))
                        Text("of daily goal")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 150, height: 150)
            }
        }
    }
    
    private var dailyHighlightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            CardHeaderView(title: "Daily Highlights", icon: "star.fill", color: .yellow)
            
            HStack(spacing: 20) {
                highlightCard(title: "Tasks Completed", value: "\(completedTasksToday)", icon: "checkmark.circle.fill", color: .green)
                highlightCard(title: "Avg. Focus per Task", value: formatDuration(averageFocusDurationPerTask), icon: "timer", color: .orange)
            }
        }
    }
    
    private func highlightCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.2))
                    .clipShape(Circle())
                
                Spacer()
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var planYourDayButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                onPlanDay()
            }
        }) {
            Text("Plan Your Day")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.accentColor)
                .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // Computed properties
    
    private var focusedDurationToday: Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let request: NSFetchRequest<ZenFocusTask> = ZenFocusTask.fetchRequest()
        request.predicate = NSPredicate(format: "completedAt >= %@ AND completedAt < %@ AND isCompleted == YES", today as NSDate, tomorrow as NSDate)
        
        do {
            let tasks = try viewContext.fetch(request)
            return tasks.reduce(0) { $0 + $1.focusedDuration }
        } catch {
            ZenFocusLogger.shared.error("Error fetching focused duration: \(error)")
            return 0
        }
    }

    private var completedTasksToday: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let request: NSFetchRequest<ZenFocusTask> = ZenFocusTask.fetchRequest()
        request.predicate = NSPredicate(format: "completedAt >= %@ AND completedAt < %@ AND isCompleted == YES", today as NSDate, tomorrow as NSDate)
        
        do {
            return try viewContext.count(for: request)
        } catch {
            ZenFocusLogger.shared.error("Error fetching completed tasks: \(error)")
            return 0
        }
    }

    private var averageFocusDurationPerTask: Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let request: NSFetchRequest<ZenFocusTask> = ZenFocusTask.fetchRequest()
        request.predicate = NSPredicate(format: "completedAt >= %@ AND completedAt < %@ AND isCompleted == YES", today as NSDate, tomorrow as NSDate)
        
        do {
            let tasks = try viewContext.fetch(request)
            let totalDuration = tasks.reduce(0) { $0 + $1.focusedDuration }
            return tasks.isEmpty ? 0 : totalDuration / Double(tasks.count)
        } catch {
            ZenFocusLogger.shared.error("Error fetching average focus duration: \(error)")
            return 0
        }
    }
    
    private var incompleteTasks: [ZenFocusTask] {
        let request: NSFetchRequest<ZenFocusTask> = ZenFocusTask.fetchRequest()
        request.predicate = NSPredicate(format: "isCompleted == NO")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ZenFocusTask.createdAt, ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            ZenFocusLogger.shared.error("Error fetching incomplete tasks: \(error)")
            return []
        }
    }
    
    private func formatDuration(_ duration: Double) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return String(format: "%dh %dm", hours, minutes)
    }
}
