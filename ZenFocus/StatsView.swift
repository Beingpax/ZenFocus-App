import SwiftUI
import CoreData
import Charts

struct StatsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var categoryManager: CategoryManager
    @State private var selectedPeriod: TimePeriod = .week
    @State private var refreshTrigger = UUID()
    @State private var completedTasks: [ZenFocusTask] = []
    @State private var timeSpentPerCategory: [(String, TimeInterval)] = []
    
    let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 300), spacing: 4),
        GridItem(.adaptive(minimum: 150, maximum: 300), spacing: 4)
    ]
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                headerWithTimePeriodSelector
                summarySection
                detailedSection
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onChange(of: selectedPeriod) { _ in
            fetchData()
        }
        .onAppear(perform: fetchData)
    }
    
    private var headerWithTimePeriodSelector: some View {
        HStack {
            Text("Your Focus")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)
            
            Spacer()
            
            timePeriodDropdown
        }
    }
    
    private var timePeriodDropdown: some View {
        Menu {
            ForEach(TimePeriod.allCases, id: \.self) { period in
                Button(action: {
                    selectedPeriod = period
                }) {
                    HStack {
                        Text(period.rawValue)
                        Spacer()
                        if selectedPeriod == period {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(selectedPeriod.rawValue)
                    .font(.system(size: 13, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
            )
        }
        .menuStyle(BorderlessButtonMenuStyle())
        .frame(width: 120)
    }
    
    private var summarySection: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            StatCard(title: "Tasks Completed", value: "\(completedTasks.count)", icon: "checkmark.circle.fill", color: .green)
            StatCard(title: "Total Focus Time", value: formatDuration(totalFocusTime), icon: "clock.fill", color: .blue)
            StatCard(title: "Avg. Focus Time", value: formatDuration(averageFocusTime), icon: "timer", color: .orange)
            StatCard(title: "Most Productive", value: mostProductiveCategory.0, icon: "star.fill", color: .yellow)
            StatCard(title: "Longest Session", value: formatDuration(longestFocusSession), icon: "flame.fill", color: .red)
        }
        .padding(.vertical, 4)
    }
    
    private var detailedSection: some View {
        VStack(spacing: 16) {
            CategoryTypeBreakdownCard(completedTasks: completedTasks, categoryManager: categoryManager)
                .frame(height: 350)
            
            CategoryTimeBreakdownCard(categoryTimes: timeSpentPerCategory, categoryManager: categoryManager)
                .frame(height: 350)
            
            RecentCompletionsCard(recentCompletions: Array(completedTasks.prefix(5)))
                .frame(minHeight: 300)
        }
    }
    
    private func fetchData() {
        let dateRange = selectedPeriod.dateRange()
        let request: NSFetchRequest<ZenFocusTask> = ZenFocusTask.fetchRequest()
        
        request.predicate = NSPredicate(format: "completedAt >= %@ AND completedAt <= %@ AND isCompleted == true",
                                        dateRange.start as NSDate,
                                        dateRange.end as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ZenFocusTask.completedAt, ascending: false)]
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let fetchedTasks = try viewContext.fetch(request)
                let categoryTimes = Dictionary(grouping: fetchedTasks) { task -> String in
                    task.categoryRef?.name ?? "Uncategorized"
                }
                .mapValues { tasks in tasks.reduce(0) { $0 + $1.focusedDuration } }
                .sorted { $0.value > $1.value }
                
                DispatchQueue.main.async {
                    self.completedTasks = fetchedTasks
                    self.timeSpentPerCategory = categoryTimes
                    self.refreshTrigger = UUID()
                }
            } catch {
                ZenFocusLogger.shared.error("Error fetching tasks: \(error)")
            }
        }
    }
    
    private var totalFocusTime: TimeInterval {
        completedTasks.reduce(0) { $0 + $1.focusedDuration }
    }
    
    private var averageFocusTime: TimeInterval {
        completedTasks.isEmpty ? 0 : totalFocusTime / Double(completedTasks.count)
    }
    
    private var mostProductiveCategory: (String, TimeInterval) {
        timeSpentPerCategory.first ?? ("None", 0)
    }
    
    private var longestFocusSession: TimeInterval {
        completedTasks.map { $0.focusedDuration }.max() ?? 0
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return String(format: "%dh %dm", hours, minutes)
    }
}

struct StatsView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let categoryManager = CategoryManager(viewContext: context)
        return StatsView(categoryManager: categoryManager)
            .environment(\.managedObjectContext, context)
    }
}
