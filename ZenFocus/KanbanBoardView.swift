import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct KanbanBoardView: View {
    @ObservedObject var categoryManager: CategoryManager
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedView: MainView.ViewType // Add this line
    
    @State private var categorizedTasks: [KanbanColumnType: [ZenFocusTask]] = [:]
    @State private var expandedColumns: Set<KanbanColumnType> = [.today]
    @State private var availableWidth: CGFloat = 0
    
    private let columnOrder: [KanbanColumnType] = [.someday, .thisWeek, .today, .overdue, .completed]
    
    @Namespace private var animation
    
    private let minExpandedWidth: CGFloat = 400 // Minimum width for expanded columns
    private let collapsedWidth: CGFloat = 140 // Width for collapsed columns
    
    @State private var showingStartDayButton = false
    @State private var todayTasksCount = 0
    @State private var isHoveringStartButton = false
    @State private var startButtonOffset: CGSize = .zero
    
    @State private var completedTasksLimit: Int = 11
    
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 6) {
                        ForEach(columnOrder, id: \.self) { columnType in
                            KanbanColumnView(
                                column: KanbanColumn(type: columnType),
                                tasks: categorizedTasks[columnType] ?? [],
                                categoryManager: categoryManager,
                               
                                isExpanded: expandedColumns.contains(columnType),
                                onTaskMoved: moveTask,
                                onAddTask: { newTask in
                                    addTask(newTask, to: columnType)
                                },
                                onDeleteTask: deleteTask,
                                onToggleExpand: { toggleColumnExpansion(columnType) },
                                onReorderTasks: { task, newIndex in
                                    reorderTasks(task: task, in: columnType, to: newIndex)
                                },
                                onShowCompletedTasksHistory: showCompletedTasksHistory, // Add this line
                                isCompletedColumn: columnType == .completed // Add this line
                            )
                            .frame(width: columnWidth(for: columnType, totalWidth: geometry.size.width))
                            .matchedGeometryEffect(id: columnType, in: animation)
                            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: expandedColumns.contains(columnType))
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 12)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.windowBackgroundColor))
            .onAppear {
                fetchAllTasks()
            }
            .onReceive(NotificationCenter.default.publisher(for: .taskCompleted)) { _ in
                fetchAllTasks()
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    startYourDayButton
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
    }

    private var startYourDayButton: some View {
        let todayTasksCount = categorizedTasks[.today]?.count ?? 0
        let hasTasks = todayTasksCount > 0
        
        return Button(action: {
            withAnimation {
                selectedView = .todayFocus
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: hasTasks ? "sunrise.fill" : "calendar.badge.plus")
                    .font(.system(size: 16, weight: .semibold))
                Text(hasTasks ? "Start Your Day" : "Plan Your Day")
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(hasTasks ? buttonGradient : inactiveButtonGradient)
            )
            .foregroundColor(hasTasks ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!hasTasks)
        .overlay(
            startYourDayTooltip
                .offset(y: -50)
            , alignment: .top
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHoveringStartButton = hovering
            }
        }
    }

    private var buttonGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [Color.orange, Color.pink]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var inactiveButtonGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [Color.secondary.opacity(0.2), Color.secondary.opacity(0.3)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var startYourDayTooltip: some View {
        let todayTasksCount = categorizedTasks[.today]?.count ?? 0
        return Group {
            if isHoveringStartButton {
                Text(todayTasksCount > 0 ? "Start your day with \(todayTasksCount) task\(todayTasksCount == 1 ? "" : "s")" : "Plan your day to get started!")
                    .font(.caption)
                    .padding(8)
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                    .fixedSize(horizontal: true, vertical: false)
                    .offset(y: -20)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    private func startDay() {
        withAnimation {
            selectedView = .todayFocus
        }
    }
    
    private func checkIfShowStartDayButton() {
        // Implement logic to determine if the "Start Your Day" button should be shown
        // For example, check if it's a new day or if the user hasn't started their day yet
        // This is a placeholder implementation
        showingStartDayButton = true
        updateTodayTasksCount()
    }
    
    private func updateTodayTasksCount() {
        todayTasksCount = categorizedTasks[.today]?.count ?? 0
    }
    
    private func columnWidth(for columnType: KanbanColumnType, totalWidth: CGFloat) -> CGFloat {
        let availableWidth = totalWidth - 12 // Subtracting horizontal padding (6 on each side)
        
        let expandedCount = expandedColumns.count
        let collapsedCount = columnOrder.count - expandedCount
        
        let totalCollapsedWidth = CGFloat(collapsedCount) * collapsedWidth
        let totalSpacingWidth = CGFloat(columnOrder.count - 1) * 6 // Account for spacing between columns
        let remainingWidth = availableWidth - totalCollapsedWidth - totalSpacingWidth
        
        if expandedColumns.contains(columnType) {
            let expandedWidth = max(minExpandedWidth, remainingWidth / CGFloat(expandedCount))
            return min(expandedWidth, availableWidth * 0.6) // Limit to 60% of available width
        } else {
            return collapsedWidth
        }
    }
    
    private func toggleColumnExpansion(_ columnType: KanbanColumnType) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            if expandedColumns.contains(columnType) {
                expandedColumns.remove(columnType)
            } else {
                expandedColumns.insert(columnType)
            }
        }
    }
    
    private func fetchAllTasks() {
        fetchTasks { tasks in
            self.categorizedTasks = tasks
            self.updateTodayTasksCount()
        }
    }
    
    private func fetchTasks(updateTasks: @escaping ([KanbanColumnType: [ZenFocusTask]]) -> Void) {
        let fetchRequest: NSFetchRequest<ZenFocusTask> = ZenFocusTask.fetchRequest()
        
        do {
            let allTasks = try viewContext.fetch(fetchRequest)
            var categorizedTasks: [KanbanColumnType: [ZenFocusTask]] = [:]
            
            for columnType in KanbanColumnType.allCases.sorted(by: { $0.rawValue > $1.rawValue }) {
                categorizedTasks[columnType] = []
            }
            
            for task in allTasks {
                let columnType = determineColumnType(for: task)
                if columnType == .completed {
                    if task.isCompleted {
                        categorizedTasks[columnType, default: []].append(task)
                    }
                } else {
                    if !task.isCompleted {
                        categorizedTasks[columnType, default: []].append(task)
                    }
                }
            }
            
            // Sort tasks in each column
            for (columnType, tasks) in categorizedTasks {
                if columnType == .completed {
                    // Sort completed tasks by completedAt date, most recent first, and limit to 11
                    categorizedTasks[columnType] = Array(tasks.sorted { (task1, task2) -> Bool in
                        guard let date1 = task1.completedAt, let date2 = task2.completedAt else {
                            return false
                        }
                        return date1 > date2
                    }.prefix(11)) // Limit to 11 tasks and convert to Array
                } else {
                    // Keep the existing sorting for other columns
                    categorizedTasks[columnType] = tasks.sorted { (task1, task2) -> Bool in
                        if task1.customOrder != task2.customOrder {
                            return task1.customOrder < task2.customOrder
                        } else {
                            return (task1.scheduledDate ?? .distantFuture) < (task2.scheduledDate ?? .distantFuture)
                        }
                    }
                }
            }
            
            updateTasks(categorizedTasks)
        } catch {
            print("Error fetching tasks: \(error)")
            updateTasks([:])
        }
    }
    
    private func determineColumnType(for task: ZenFocusTask) -> KanbanColumnType {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!
        
        if task.isCompleted {
            return .completed
        }
        
        if let scheduledDate = task.scheduledDate {
            if scheduledDate < startOfToday {
                return .overdue
            }
            if calendar.isDateInToday(scheduledDate) {
                return .today
            }
            if scheduledDate >= startOfWeek && scheduledDate <= endOfWeek {
                return .thisWeek
            }
        }
        
        return .someday
    }
    
    private func moveTask(_ task: ZenFocusTask, to column: KanbanColumn) {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!

        switch column.type {
        case .someday:
            task.scheduledDate = nil
            task.isCompleted = false
            task.completedAt = nil
        case .thisWeek:
            task.scheduledDate = endOfWeek
            task.isCompleted = false
            task.completedAt = nil
        case .today:
            task.scheduledDate = startOfToday
            task.isCompleted = false
            task.completedAt = nil
        case .overdue:
            task.scheduledDate = calendar.date(byAdding: .day, value: -1, to: startOfToday)
            task.isCompleted = false
            task.completedAt = nil
        case .completed:
            task.isCompleted = true
            task.completedAt = now
        }
        
        do {
            try viewContext.save()
            fetchAllTasks()
            if column.type == .completed {
                NotificationCenter.default.post(name: .taskCompleted, object: nil)
            }
        } catch {
            print("Error saving task: \(error)")
        }
    }
    
    private func addTask(_ task: ZenFocusTask, to columnType: KanbanColumnType) {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let endOfWeek = calendar.date(byAdding: .day, value: 7 - calendar.component(.weekday, from: now), to: startOfToday)!

        switch columnType {
        case .someday:
            task.scheduledDate = nil
            task.isCompleted = false
            task.completedAt = nil
        case .thisWeek:
            task.scheduledDate = endOfWeek
            task.isCompleted = false
            task.completedAt = nil
        case .today:
            task.scheduledDate = startOfToday
            task.isCompleted = false
            task.completedAt = nil
        case .overdue:
            task.scheduledDate = calendar.date(byAdding: .day, value: -1, to: startOfToday)
            task.isCompleted = false
            task.completedAt = nil
        case .completed:
            task.isCompleted = true
            task.completedAt = now
        }
        
        // Set the custom order to the end of the list
        let tasksInColumn = categorizedTasks[columnType] ?? []
        task.customOrder = Int32(tasksInColumn.count)
        
        do {
            try viewContext.save()
            fetchAllTasks()
            if columnType == .completed {
                NotificationCenter.default.post(name: .taskCompleted, object: nil)
            }
        } catch {
            print("Error saving new task: \(error)")
        }
    }
    
    private func deleteTask(_ task: ZenFocusTask) {
        viewContext.delete(task)
        do {
            try viewContext.save()
            // Update the specific column's tasks
            updateColumnTasks(for: columnTypeForTask(task))
        } catch {
            print("Error deleting task: \(error)")
        }
    }
    
    private func columnTypeForTask(_ task: ZenFocusTask) -> KanbanColumnType {
        if task.isCompleted {
            return .completed
        } else if let scheduledDate = task.scheduledDate {
            let calendar = Calendar.current
            let now = Date()
            if calendar.isDateInToday(scheduledDate) {
                return .today
            } else if scheduledDate < now {
                return .overdue
            } else if calendar.isDate(scheduledDate, equalTo: now, toGranularity: .weekOfYear) {
                return .thisWeek
            }
        }
        return .someday
    }
    
    private func updateColumnTasks(for columnType: KanbanColumnType) {
        fetchTasks { tasks in
            self.categorizedTasks = tasks
        }
    }
    
    private func endOfWeek(for date: Date) -> Date {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let daysToAdd = 7 - weekday
        return calendar.date(byAdding: .day, value: daysToAdd, to: date)!
    }
    
    private func reorderTasks(task: ZenFocusTask, in columnType: KanbanColumnType, to newIndex: Int) {
        guard var tasks = categorizedTasks[columnType] else { return }
        
        guard let oldIndex = tasks.firstIndex(of: task) else { return }
        
        // Remove the task from its old position
        tasks.remove(at: oldIndex)
        
        // Insert the task at its new position
        tasks.insert(task, at: newIndex)
        
        // Update custom order for all tasks in the column
        for (index, updatedTask) in tasks.enumerated() {
            updatedTask.customOrder = Int32(index)
        }
        
        categorizedTasks[columnType] = tasks
        
        // Save the changes
        do {
            try viewContext.save()
        } catch {
            print("Error saving reordered tasks: \(error)")
        }
    }
    
    private func showCompletedTasksHistory() {
        withAnimation {
            selectedView = .history
        }
    }
}

struct KanbanColumn: Identifiable {
    let id = UUID()
    let title: String
    let type: KanbanColumnType
    let color: Color

    init(type: KanbanColumnType) {
        self.title = type.title
        self.type = type
        self.color = type.color
    }
}

enum KanbanColumnType: Int, CaseIterable {
    case overdue = 5
    case today = 4
    case thisWeek = 3
    case someday = 2
    case completed = 1
    
    var title: String {
        switch self {
        case .overdue: return "Overdue"
        case .today: return "Today"
        case .thisWeek: return "This Week"
        case .someday: return "Someday"
        case .completed: return "Completed"
        }
    }
    
    var color: Color {
        switch self {
        case .overdue: return .red
        case .today: return .green
        case .thisWeek: return .blue
        case .someday: return .orange
        case .completed: return .gray
        }
    }
}

struct KanbanColumnView: View {
    let column: KanbanColumn
    let tasks: [ZenFocusTask]
    let categoryManager: CategoryManager
    let isExpanded: Bool
    let onTaskMoved: (ZenFocusTask, KanbanColumn) -> Void
    let onAddTask: (ZenFocusTask) -> Void
    let onDeleteTask: (ZenFocusTask) -> Void
    let onToggleExpand: () -> Void
    let onReorderTasks: (ZenFocusTask, Int) -> Void
    let onShowCompletedTasksHistory: () -> Void
    let isCompletedColumn: Bool
    
    @State private var newTaskTitle = ""
    @State private var contentHeight: CGFloat = 0
    @State private var draggingTask: ZenFocusTask?
    @State private var draggingTaskIndex: Int?
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var animation
    
    private let collapsedWidth: CGFloat = 140
    
    @EnvironmentObject var windowManager: WindowManager  // Add this line
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            columnHeader
            
            if isExpanded {
                VStack(spacing: 12) {
                    taskList
                    
                    if !isCompletedColumn {
                        TaskInputView(categoryManager: categoryManager) { newTask in
                            onAddTask(newTask)
                        }
                        .padding(.horizontal, 6)
                    }
                }
                .transition(.opacity)
            }
        }
        .frame(width: isExpanded ? nil : collapsedWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.vertical, 16)
        .background(columnBackgroundColor)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .onDrop(of: [.url], delegate: ColumnDropDelegate(column: column, onTaskMoved: onTaskMoved))
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isExpanded)
        .overlay(
            Group {
                if !isExpanded {
                    taskCountBadge
                }
            },
            alignment: .topTrailing
        )
    }
    
    private var columnHeader: some View {
        CardHeaderView(title: column.title, icon: iconForColumn(column.type), color: column.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .cornerRadius(8)
            .contentShape(Rectangle())
            .matchedGeometryEffect(id: "header_\(column.id)", in: animation)
            .onTapGesture(perform: onToggleExpand)
    }
    
    private var taskCountBadge: some View {
        Text("\(tasks.count)")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(column.color)
            .padding(5)
            .background(column.color.opacity(0.2))
            .overlay(
                Circle()
                    .stroke(column.color, lineWidth: 1.5)
            )
            .clipShape(Circle())
            .offset(x: -8, y: 8)
    }
    
    private var taskList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(sortedTasks.enumerated()), id: \.element.objectID) { index, task in
                    BetterTaskRow(
                        task: task,
                        categoryManager: categoryManager,
                        onDelete: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                onDeleteTask(task)
                            }
                        },
                        onToggleCompletion: {
                            toggleTaskCompletion(task)
                        },
                        onStartFocus: {
                            windowManager.showFocusedTaskWindow(
                                for: task,
                                onComplete: { completedTask in
                                    // Handle completion
                                    task.isCompleted = true
                                    task.completedAt = Date()
                                    onTaskMoved(task, KanbanColumn(type: .completed))
                                },
                                onBreak: {
                                    // Handle break
                                }
                            )
                        }
                    )
                    .transition(.opacity)
                    .onDrag {
                        self.draggingTask = task
                        self.draggingTaskIndex = index
                        return NSItemProvider(object: task.objectID.uriRepresentation() as NSURL)
                    }
                    .onDrop(of: [UTType.url], delegate: TasksDropDelegate(
                        task: task,
                        taskIndex: index,
                        tasks: sortedTasks,
                        column: column,
                        draggingTask: $draggingTask,
                        draggingTaskIndex: $draggingTaskIndex,
                        onReorder: onReorderTasks
                    ))
                }
                
                if isCompletedColumn {
                    Button(action: onShowCompletedTasksHistory) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("View All Completed Tasks")
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 8)
                }
            }
            .padding(16)
            .animation(.default, value: tasks)
        }
    }
    
    private var columnBackgroundColor: Color {
        colorScheme == .dark ? Color(NSColor.controlBackgroundColor) : Color(NSColor.controlBackgroundColor).opacity(0.5)
    }
    
    private var taskBackgroundColor: Color {
        colorScheme == .dark ? Color(NSColor.textBackgroundColor) : Color.white
    }
    
    private func iconForColumn(_ type: KanbanColumnType) -> String {
        switch type {
        case .someday: return "calendar"
        case .thisWeek: return "calendar.badge.clock"
        case .today: return "sun.max"
        case .overdue: return "exclamationmark.triangle"
        case .completed: return "checkmark.circle"
        }
    }
    
    private func addNewTask() {
        guard !newTaskTitle.isEmpty else { return }
        let task = ZenFocusTask(context: viewContext)
        task.title = newTaskTitle
        task.createdAt = Date()
        onAddTask(task)
        newTaskTitle = ""
    }
    
    private func toggleTaskCompletion(_ task: ZenFocusTask) {
        task.isCompleted.toggle()
        if task.isCompleted {
            task.completedAt = Date()
            onTaskMoved(task, KanbanColumn(type: .completed))
        } else {
            task.completedAt = nil
            let newColumnType = determineColumnType(for: task)
            onTaskMoved(task, KanbanColumn(type: newColumnType))
        }
    }
    
    private func determineColumnType(for task: ZenFocusTask) -> KanbanColumnType {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!
        
        if task.isCompleted {
            return .completed
        }
        
        if let scheduledDate = task.scheduledDate {
            if scheduledDate < startOfToday {
                return .overdue
            }
            if calendar.isDateInToday(scheduledDate) {
                return .today
            }
            if scheduledDate >= startOfWeek && scheduledDate <= endOfWeek {
                return .thisWeek
            }
        }
        
        return .someday
    }
    
    private var sortedTasks: [ZenFocusTask] {
        tasks.sorted { (task1, task2) -> Bool in
            if task1.customOrder != task2.customOrder {
                return task1.customOrder < task2.customOrder
            } else {
                return (task1.scheduledDate ?? .distantFuture) < (task2.scheduledDate ?? .distantFuture)
            }
        }
    }
}

struct ColumnDropDelegate: DropDelegate {
    let column: KanbanColumn
    let onTaskMoved: (ZenFocusTask, KanbanColumn) -> Void
    
    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: [.url]).first else { return false }
        
        itemProvider.loadObject(ofClass: NSURL.self) { (urlObject, error) in
            if let url = urlObject as? URL,
               let objectID = PersistenceController.shared.container.persistentStoreCoordinator.managedObjectID(forURIRepresentation: url),
               let task = try? PersistenceController.shared.container.viewContext.existingObject(with: objectID) as? ZenFocusTask {
                DispatchQueue.main.async {
                    onTaskMoved(task, column)
                }
            }
        }
        
        return true
    }
}

struct TasksDropDelegate: DropDelegate {
    let task: ZenFocusTask
    let taskIndex: Int
    let tasks: [ZenFocusTask]
    let column: KanbanColumn
    @Binding var draggingTask: ZenFocusTask?
    @Binding var draggingTaskIndex: Int?
    let onReorder: (ZenFocusTask, Int) -> Void
    
    func performDrop(info: DropInfo) -> Bool {
        guard let draggingTask = self.draggingTask,
              let fromIndex = self.draggingTaskIndex else { return false }
        
        let toIndex = taskIndex
        
        if fromIndex != toIndex {
            onReorder(draggingTask, toIndex)
        }
        
        DispatchQueue.main.async {
            self.draggingTask = nil
            self.draggingTaskIndex = nil
        }
        
        return true
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggingTask = self.draggingTask,
              let fromIndex = self.draggingTaskIndex else { return }
        
        let toIndex = taskIndex
        
        if fromIndex != toIndex {
            onReorder(draggingTask, toIndex)
            DispatchQueue.main.async {
                self.draggingTaskIndex = toIndex
            }
        }
    }
}

class KanbanColumnTasks: ObservableObject {
    @Published var tasks: [ZenFocusTask] = []
    
    func updateTasks(_ newTasks: [ZenFocusTask]) {
        DispatchQueue.main.async {
            self.tasks = newTasks
        }
    }
}
