import SwiftUI
import CoreData

struct CompletedTasksHistoryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var categoryManager: CategoryManager
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ZenFocusTask.completedAt, ascending: false)],
        predicate: NSPredicate(format: "isCompleted == YES"),
        animation: .default)
    private var completedTasks: FetchedResults<ZenFocusTask>
    
    @State private var selectedTask: ZenFocusTask?
    @State private var groupedTasks: [(key: Date, value: [Date: [ZenFocusTask]])] = []
    @State private var visibleMonths: Set<Date> = []
    @EnvironmentObject var windowManager: WindowManager
    
    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor).edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                todayTasksHeader
                
                ScrollViewReader { proxy in
                    List {
                        ForEach(groupedTasks, id: \.key) { month, dateGroups in
                            Section(header: monthHeader(for: month)) {
                                ForEach(dateGroups.keys.sorted(by: >), id: \.self) { date in
                                    DateSection(
                                        date: date,
                                        tasks: dateGroups[date] ?? [],
                                        selectedTask: $selectedTask,
                                        categoryManager: categoryManager,
                                        onDelete: deleteTask
                                    )
                                }
                            }
                            .id(month)
                        }
                    }
                    .listStyle(PlainListStyle())
                    .background(Color.clear)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .padding(20)
            .overlay(
                Group {
                    if let task = selectedTask {
                        TaskDetailView(
                            task: task,
                            categoryManager: categoryManager,
                            isPresented: Binding(
                                get: { selectedTask != nil },
                                set: { if !$0 { selectedTask = nil } }
                            ),
                            onDelete: {
                                deleteTask(task)
                                selectedTask = nil
                            }
                        )
                    }
                }
            )
        }
        .onAppear {
            groupTasks()
        }
        .onChange(of: completedTasks.count) { _ in
            groupTasks()
        }
    }
    
    private var todayTasksHeader: some View {
        HStack {
            CardHeaderView(title: "Completed Tasks", icon: "checkmark.circle", color: .green)
            Spacer()
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .bottom
        )
    }
    
    private func monthHeader(for date: Date) -> some View {
        Text(date, formatter: monthFormatter)
            .font(.title2)
            .fontWeight(.bold)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
    }
    
    private func groupTasks() {
        let calendar = Calendar.current
        let groupedByDate = Dictionary(grouping: completedTasks) { task in
            calendar.startOfDay(for: task.completedAt ?? Date())
        }
        
        let groupedByMonth = Dictionary(grouping: groupedByDate.keys) { date in
            calendar.startOfMonth(for: date)
        }.mapValues { dates in
            Dictionary(uniqueKeysWithValues: dates.map { date in (date, groupedByDate[date]!) })
        }
        
        groupedTasks = groupedByMonth.sorted { $0.key > $1.key }
    }
    
    private func deleteTask(_ task: ZenFocusTask) {
        viewContext.delete(task)
        do {
            try viewContext.save()
        } catch {
            print("Error deleting task: \(error)")
        }
    }
}

struct DateSection: View {
    let date: Date
    let tasks: [ZenFocusTask]
    @Binding var selectedTask: ZenFocusTask?
    @ObservedObject var categoryManager: CategoryManager
    let onDelete: (ZenFocusTask) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                TimelineNode(color: .accentColor, size: 16, lineWidth: 4)
                    .frame(width: 30)
                Text(date, style: .date)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
            }
            .padding(.vertical, 12)
            
            ForEach(tasks.sorted(by: { ($0.completedAt ?? Date()) > ($1.completedAt ?? Date()) })) { task in
                HStack(spacing: 0) {
                    TimelineConnector()
                        .frame(width: 30)
                    CompletedTaskRow(
                        task: task,
                        categoryManager: categoryManager,
                        isSelected: Binding(
                            get: { selectedTask == task },
                            set: { if $0 { selectedTask = task } else if selectedTask == task { selectedTask = nil } }
                        )
                    )
                }
            }
            
            if tasks.isEmpty {
                TimelineConnector(isEmpty: true)
                    .frame(width: 30)
            }
        }
    }
}

struct CompletedTaskRow: View {
    let task: ZenFocusTask
    @ObservedObject var categoryManager: CategoryManager
    @Binding var isSelected: Bool
    @State private var isHovered: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(task.title ?? "")
                .font(.system(size: 16, weight: .medium))
                .lineLimit(1)
            
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.secondary)
                    Text(formatDuration(task.focusedDuration))
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                
                if let category = task.categoryRef {
                    CategoryPill(
                        category: category,
                        categoryManager: categoryManager
                    )
                }
                
                Spacer()
                
                Text((task.completedAt ?? Date()).formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : (isHovered ? Color.gray.opacity(0.05) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovered ? Color.gray.opacity(0.2) : Color.clear, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onTapGesture {
            isSelected.toggle()
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private func formatDuration(_ duration: Double) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }
}

struct CategoryPill: View {
    let category: Category
    @ObservedObject var categoryManager: CategoryManager
    
    var body: some View {
        Text(category.name ?? "")
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(categoryManager.colorForCategory(category).opacity(0.2))
            .foregroundColor(categoryManager.colorForCategory(category))
            .cornerRadius(8)
    }
}

struct TimelineNode: View {
    var color: Color
    var size: CGFloat
    var lineWidth: CGFloat
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(color.opacity(0.3), lineWidth: lineWidth)
                    .frame(width: size + lineWidth, height: size + lineWidth)
            )
    }
}

struct TimelineConnector: View {
    var isEmpty: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.accentColor.opacity(0.3))
                .frame(width: 2)
                .frame(height: isEmpty ? 40 : 20)
            
            if !isEmpty {
                TimelineNode(color: .accentColor.opacity(0.5), size: 8, lineWidth: 2)
                
                Rectangle()
                    .fill(Color.accentColor.opacity(0.3))
                    .frame(width: 2)
                    .frame(height: 20)
            }
        }
    }
}

struct TaskDetailView: View {
    let task: ZenFocusTask
    @ObservedObject var categoryManager: CategoryManager
    @Binding var isPresented: Bool
    let onDelete: () -> Void
    @Environment(\.managedObjectContext) private var viewContext
    @State private var opacity: Double = 0
    @State private var offset: CGFloat = 20
    @State private var showingDeleteConfirmation = false
    @State private var isEditing = false
    @State private var editedTitle: String = ""
    @State private var selectedCategory: Category?
    @State private var editedCompletedAt: Date = Date()
    @State private var editedCreatedAt: Date = Date()
    @State private var editedScheduledDate: Date?
    @State private var editedFocusedDurationMinutes: Double = 0
    @State private var showingCategoryPicker = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 20) {
                    if isEditing {
                        editableContent
                    } else {
                        header
                        content
                    }
                    Spacer()
                    
                    HStack {
                        deleteButton
                        Spacer()
                        editButton
                    }
                }
                .frame(width: min(350, geometry.size.width * 0.9))
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.controlBackgroundColor))
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                )
                .offset(x: isPresented ? 0 : geometry.size.width)
                
                closeButton
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        }
        .opacity(opacity)
        .onAppear(perform: startAnimation)
        .alert(isPresented: $showingDeleteConfirmation) {
            Alert(
                title: Text("Delete Task"),
                message: Text("Are you sure you want to delete this task? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    onDelete()
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    private var editableContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Task Title", text: $editedTitle)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            categorySelector
            
            DatePicker("Completed At", selection: $editedCompletedAt, displayedComponents: [.date, .hourAndMinute])
            
            DatePicker("Created At", selection: $editedCreatedAt, displayedComponents: [.date, .hourAndMinute])
            
            Toggle("Has Scheduled Date", isOn: Binding(
                get: { editedScheduledDate != nil },
                set: { if !$0 { editedScheduledDate = nil } }
            ))
            
            if editedScheduledDate != nil {
                DatePicker("Scheduled Date", selection: Binding(
                    get: { editedScheduledDate ?? Date() },
                    set: { editedScheduledDate = $0 }
                ), displayedComponents: [.date])
            }
            
            HStack {
                Text("Focus Duration:")
                TextField("Duration", value: $editedFocusedDurationMinutes, formatter: NumberFormatter())
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Text("minutes")
            }
            
            Button(action: saveChanges) {
                Text("Save Changes")
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.accentColor)
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var deleteButton: some View {
        Button(action: {
            showingDeleteConfirmation = true
        }) {
            Text("Delete")
                .fontWeight(.medium)
                .foregroundColor(.red)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.1))
                .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var editButton: some View {
        Button(action: {
            if !isEditing {
                initializeEditableFields()
            }
            isEditing.toggle()
        }) {
            Text(isEditing ? "Cancel" : "Edit")
                .fontWeight(.medium)
                .foregroundColor(isEditing ? .secondary : .accentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isEditing ? Color.secondary.opacity(0.1) : Color.accentColor.opacity(0.1))
                .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func initializeEditableFields() {
        editedTitle = task.title ?? ""
        selectedCategory = task.categoryRef
        editedCompletedAt = task.completedAt ?? Date()
        editedCreatedAt = task.createdAt ?? Date()
        editedScheduledDate = task.scheduledDate
        editedFocusedDurationMinutes = task.focusedDuration / 60
    }
    
    private func saveChanges() {
        task.title = editedTitle
        task.categoryRef = selectedCategory
        task.completedAt = editedCompletedAt
        task.createdAt = editedCreatedAt
        task.scheduledDate = editedScheduledDate
        task.focusedDuration = editedFocusedDurationMinutes * 60
        
        do {
            try viewContext.save()
            isEditing = false
        } catch {
            print("Error saving edited task: \(error)")
        }
    }
    
    private var header: some View {
        HStack {
            Text(task.title ?? "")
                .font(.title2)
                .fontWeight(.bold)
                .lineLimit(2)
            Spacer()
        }
    }
    
    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            detailRow(icon: "checkmark.circle.fill", title: "Completed", value: (task.completedAt ?? Date()).formatted(date: .long, time: .shortened))
            detailRow(icon: "clock.fill", title: "Focus Duration", value: formatDuration(task.focusedDuration))
            if let category = task.categoryRef {
                detailRow(icon: "tag.fill", title: "Category", value: category.name ?? "")
            }
            detailRow(icon: "calendar", title: "Created", value: (task.createdAt ?? Date()).formatted(date: .long, time: .shortened))
            if let scheduledDate = task.scheduledDate {
                detailRow(icon: "calendar.badge.clock", title: "Scheduled", value: scheduledDate.formatted(date: .long, time: .omitted))
            }
        }
    }
    
    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.body)
            }
        }
    }
    
    private var closeButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                opacity = 0
                offset = 20
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isPresented = false
            }
        }) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.secondary)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(8)
    }
    
    private func formatDuration(_ duration: Double) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return String(format: "%d hours %d minutes", hours, minutes)
        } else {
            return String(format: "%d minutes", minutes)
        }
    }
    
    private func startAnimation() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            opacity = 1
            offset = 0
        }
    }
    
    private var categorySelector: some View {
        HStack {
            Text("Category")
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: { showingCategoryPicker = true }) {
                if let category = selectedCategory {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(categoryManager.colorForCategory(category))
                            .frame(width: 8, height: 8)
                        Text(category.name ?? "")
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(categoryManager.colorForCategory(category).opacity(0.1))
                    .cornerRadius(6)
                } else {
                    Text("None")
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingCategoryPicker) {
                CategoryPickerView(
                    selectedCategory: $selectedCategory,
                    categoryManager: categoryManager
                )
            }
        }
    }
}

struct CategoryPickerView: View {
    @Binding var selectedCategory: Category?
    @ObservedObject var categoryManager: CategoryManager
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search categories", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(.controlBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(spacing: 4) {
                    // None option
                    categoryButton(category: nil)
                    
                    // Filtered categories
                    ForEach(filteredCategories, id: \.self) { category in
                        Divider()
                        categoryButton(category: category)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(width: 300, height: 400)
        .background(Color(.windowBackgroundColor))
    }
    
    private var filteredCategories: [Category] {
        let childCategories = categoryManager.getChildCategories()
        if searchText.isEmpty {
            return childCategories
        }
        return childCategories.filter {
            ($0.name ?? "").lowercased().contains(searchText.lowercased())
        }
    }
    
    private func categoryButton(category: Category?) -> some View {
        Button(action: {
            selectedCategory = category
            presentationMode.wrappedValue.dismiss()
        }) {
            HStack(spacing: 12) {
                if let category = category {
                    // Category option
                    Circle()
                        .fill(categoryManager.colorForCategory(category))
                        .frame(width: 8, height: 8)
                    
                    Text(category.name ?? "")
                        .foregroundColor(.primary)
                } else {
                    // None option
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 8, height: 8)
                    
                    Text("None")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if category == selectedCategory || (category == nil && selectedCategory == nil) {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 12))
                }
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.clear)
                    .contentShape(Rectangle())
            )
        }
        .buttonStyle(.plain)
    }
}

private let monthFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM yyyy"
    return formatter
}()

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components)!
    }
}


// Preview
struct CompletedTasksHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let categoryManager = CategoryManager(viewContext: context)
        
        // Create some sample completed tasks and categories
        let categories = ["Work", "Personal", "Study"]
        var categoryRefs: [Category] = []
        
        // Create categories first
        for categoryName in categories {
            let category = Category(context: context)
            category.name = categoryName
            categoryRefs.append(category)
        }
        
        // Create sample tasks with proper category references
        for i in 0..<20 {
            let task = ZenFocusTask(context: context)
            task.title = "Completed Task \(i + 1)"
            task.isCompleted = true
            task.completedAt = Date().addingTimeInterval(TimeInterval(-i * 86400))
            task.categoryRef = categoryRefs[i % categoryRefs.count]
            task.focusedDuration = Double((i + 1) * 600)
        }
        
        // Save the context
        try? context.save()
        
        return CompletedTasksHistoryView(categoryManager: categoryManager)
            .environment(\.managedObjectContext, context)
            .previewLayout(.sizeThatFits)
            .padding()
            .frame(height: 600)
    }
}
