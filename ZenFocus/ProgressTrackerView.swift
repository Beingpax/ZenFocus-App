import SwiftUI
import CoreData
import Charts

struct ProgressTrackerView: View {
    @ObservedObject var categoryManager: CategoryManager
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("dailyGoalMinutes") private var dailyGoalMinutes: Int = 120
    @State private var selectedPeriod: TimePeriod = .week
    @State private var showingGoalSetter = false
    @State private var animateProgress = false
    @State private var refreshTrigger = UUID()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                todayProgressSection
                dailyHighlightsSection
                weeklyOverviewSection
            }
            .padding()
        }
        .background(Color.clear)
        .sheet(isPresented: $showingGoalSetter) {
            GoalSetterView(dailyGoalMinutes: $dailyGoalMinutes)
        }
        .onAppear { 
            animateProgress = true 
            setupNotificationObserver()
        }
        .id(refreshTrigger)
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Focus Progress")
                    .font(.system(size: 28, weight: .bold))
                Text("Keep pushing your limits!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: { showingGoalSetter = true }) {
                HStack {
                    Image(systemName: "target")
                    Text("Set Goal")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(20)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
    }
    
    private var todayProgressSection: some View {
        VStack(spacing: 20) {
           
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    CardHeaderView(title: "Today's Focus", icon: "chart.pie.fill", color: .purple)
                    
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
                .frame(width: 180, height: 180)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    private var weeklyOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            CardHeaderView(title: "Weekly Overview", icon: "calendar.badge.clock", color: .blue)
            
            Chart {
                ForEach(weeklyData, id: \.date) { item in
                    BarMark(
                        x: .value("Day", item.date, unit: .day),
                        y: .value("Focused Duration", item.focusedDuration / 3600)
                    )
                    .foregroundStyle(
                        LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]),
                                       startPoint: .bottom,
                                       endPoint: .top)
                    )
                }
                
                RuleMark(
                    y: .value("Goal", Double(dailyGoalMinutes) / 60)
                )
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                .annotation(position: .top, alignment: .trailing) {
                    Text("Daily Goal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 300)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let hours = value.as(Double.self) {
                            Text("\(Int(hours))h")
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    private var dailyHighlightsSection: some View {
        HStack(spacing: 20) {
            highlightCard(title: "Tasks Completed", value: "\(completedTasksToday)", icon: "checkmark.circle.fill", color: .green)
            highlightCard(title: "Avg. Focus per Task", value: formatDuration(averageFocusDurationPerTask), icon: "timer", color: .orange)
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
    
    // Add the following computed properties and methods
    
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

    private var weeklyData: [(date: Date, focusedDuration: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekStart = calendar.date(byAdding: .day, value: -6, to: today)!
        
        return (0...6).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart)!
            let nextDate = calendar.date(byAdding: .day, value: 1, to: date)!
            
            let request: NSFetchRequest<ZenFocusTask> = ZenFocusTask.fetchRequest()
            request.predicate = NSPredicate(format: "createdAt >= %@ AND createdAt < %@", date as NSDate, nextDate as NSDate)
            
            do {
                let tasks = try viewContext.fetch(request)
                let duration = tasks.reduce(0) { $0 + $1.focusedDuration }
                return (date: date, focusedDuration: duration)
            } catch {
                ZenFocusLogger.shared.error("Error fetching focused duration: \(error)")
                return (date: date, focusedDuration: 0)
            }
        }
    }
    
    private func formatDuration(_ duration: Double) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return String(format: "%dh %dm", hours, minutes)
    }
    
    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(forName: .taskCompleted, object: nil, queue: .main) { _ in
            refreshView()
        }
    }

    private func refreshView() {
        withAnimation {
            refreshTrigger = UUID()
        }
    }
}
