import SwiftUI
import CoreData
import AppKit

struct BetterTaskRow: View {
    @ObservedObject var task: ZenFocusTask
    @ObservedObject var categoryManager: CategoryManager
    var onDelete: (() -> Void)?
    var onToggleCompletion: (() -> Void)?
    var onStartFocus: (() -> Void)?
    
    @State private var isPaused: Bool = false
    @State private var isDisappearing = false
    @State private var isEditing = false
    @State private var editedTitle: String = ""
    @FocusState private var isTextFieldFocused: Bool
    @Environment(\.managedObjectContext) private var viewContext
    @State private var editedCategory: Category?
    @State private var editedScheduledDate: Date?
    @State private var showingCategoryPicker = false
    @State private var showingDatePicker = false
    @EnvironmentObject var windowManager: WindowManager
    
    private var categoryButton: some View {
        Button(action: { 
            showingCategoryPicker = true 
        }) {
            HStack(spacing: 4) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 12))
                if let category = editedCategory {
                    Text(category.name ?? "")
                        .font(.system(size: 12))
                        .foregroundColor(categoryManager.colorForCategory(category))
                } else {
                    Text("No Category")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(editedCategory != nil ? 
                        categoryManager.colorForCategory(editedCategory!).opacity(0.2) : 
                        Color.secondary.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .popover(isPresented: $showingCategoryPicker) {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Select Category")
                        .font(.headline)
                    Spacer()
                    Button("Done") {
                        showingCategoryPicker = false
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Category List
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(categoryManager.getChildCategories(), id: \.self) { category in
                            Button(action: {
                                editedCategory = category
                                showingCategoryPicker = false
                            }) {
                                HStack {
                                    Circle()
                                        .fill(categoryManager.colorForCategory(category))
                                        .frame(width: 8, height: 8)
                                    Text(category.name ?? "")
                                        .lineLimit(1)
                                    Spacer()
                                    if category == editedCategory {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                                .contentShape(Rectangle())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(category == editedCategory ? 
                                    Color.accentColor.opacity(0.1) : 
                                    Color.clear)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Divider()
                
                // Footer with clear button
                Button(action: {
                    editedCategory = nil
                    showingCategoryPicker = false
                }) {
                    Text("Clear Category")
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
                .padding()
            }
            .frame(width: 250, height: 300)
            .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
        }
    }
    
    private var editingView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title TextField with better styling
            HStack(spacing: 8) {
                Image(systemName: "pencil")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                TextField("Task title", text: $editedTitle, onCommit: {
                    if !showingCategoryPicker && !showingDatePicker {
                        saveEdit()
                    }
                })
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 18, weight: .bold))
                .focused($isTextFieldFocused)
            }
            
            Divider()
            
            // Category and Date controls in a more organized layout
            HStack(spacing: 16) {
                categoryButton
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                
                // Date Button
                Button(action: { showingDatePicker = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        if let date = editedScheduledDate {
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                .font(.system(size: 12))
                                .foregroundColor(.primary)
                        } else {
                            Text("Set date")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(editedScheduledDate != nil ? 
                                Color.secondary.opacity(0.1) : 
                                Color.secondary.opacity(0.05))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                .popover(isPresented: $showingDatePicker) {
                    DatePickerView(
                        selectedDate: $editedScheduledDate,
                        showDatePicker: $showingDatePicker
                    )
                }
                
                Spacer()
                
                // Save button
                Button(action: saveEdit) {
                    Text("Save")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accentColor)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .opacity(editedTitle.isEmpty ? 0.5 : 1)
                .disabled(editedTitle.isEmpty)
            }
        }
        .padding(12)
        .background(VisualEffectView(material: .popover, blendingMode: .withinWindow))
        .cornerRadius(10)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Completion button
            completionButton
            
            // Main content
            if isEditing {
                editingView
            } else {
                normalView
            }
        }
        .padding(.horizontal, 16)
        .frame(height: isEditing ? 100 : 50)  // Adjust height when editing
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .scaleEffect(isEditing ? 1.01 : 1.0)
        .zIndex(isEditing ? 1 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isEditing)
        .opacity(isDisappearing ? 0 : 1)
        .animation(.easeOut(duration: 1.5), value: isDisappearing)
        .onChange(of: task.isCompleted) { newValue in
            if newValue {
                withAnimation {
                    isDisappearing = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    onDelete?()
                }
            }
        }
        .contextMenu {
            Button(action: deleteTask) {
                Label("Delete", systemImage: "trash")
                    .foregroundColor(.red)
            }
            
            Button(action: startEditing) {
                Label("Edit", systemImage: "pencil")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .taskPauseStateChanged)) { notification in
            if let taskID = notification.userInfo?["taskID"] as? NSManagedObjectID,
               let pauseState = notification.userInfo?["isPaused"] as? Bool,
               taskID == task.objectID {
                isPaused = pauseState
            }
        }
        .onExitCommand {
            if !showingCategoryPicker && !showingDatePicker {
                saveEdit()
            }
        }
    }
    
    private func startEditing() {
        editedTitle = task.title ?? ""
        editedCategory = task.categoryRef
        editedScheduledDate = task.scheduledDate
        isEditing = true
        isTextFieldFocused = true
    }
    
    private func saveEdit() {
        if !showingCategoryPicker && !showingDatePicker {
            guard !editedTitle.isEmpty else { return }
            
            if task.title != editedTitle {
                task.title = editedTitle
            }
            if task.categoryRef != editedCategory {
                task.categoryRef = editedCategory
            }
            if task.scheduledDate != editedScheduledDate {
                task.scheduledDate = editedScheduledDate
            }
            
            try? viewContext.save()
            isEditing = false
            isTextFieldFocused = false
        }
    }
    
    private func categoryPill(_ category: Category) -> some View {
        Text(category.name ?? "")
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(categoryManager.colorForCategory(category))
            .foregroundColor(CategoryManager.textColor)
            .cornerRadius(6)
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
    
    private func deleteTask() {
        withAnimation(.easeOut(duration: 0.3)) {
            isDisappearing = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDelete?()
        }
    }
    
    private var completionButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                onToggleCompletion?()
            }
        }) {
            ZStack {
                Circle()
                    .stroke(task.isCompleted ? Color.green : Color.secondary.opacity(0.5), lineWidth: 2)
                    .frame(width: 26, height: 26)
                
                if task.isCompleted {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 18, height: 18)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Circle()
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: 18, height: 18)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var normalView: some View {
        HStack {
            Text(task.title ?? "")
                .strikethrough(task.isCompleted)
                .foregroundColor(task.isCompleted ? .secondary : .primary)
                .font(.system(size: 18, weight: .bold))
                .lineLimit(1)
                .truncationMode(.tail)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        startEditing()
                    }
                }
            
            Spacer()
            
            HStack(spacing: 8) {
                if task.focusedDuration > 0 {
                    Text(formatDuration(task.focusedDuration))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isPaused ? .secondary : .primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isPaused ? Color.secondary.opacity(0.08) : Color.accentColor.opacity(0.1))
                        .cornerRadius(4)
                }
                
                if let category = task.categoryRef {
                    categoryPill(category)
                }
                
                if !task.isCompleted {
                    Button(action: { onStartFocus?() }) {
                        Image(systemName: "bolt.circle.fill")
                            .foregroundColor(windowManager.focusedWindow == nil ? .orange : .gray)
                            .font(.system(size: 18))
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(windowManager.focusedWindow == nil ? 
                                        Color.orange.opacity(0.1) : 
                                        Color.gray.opacity(0.1))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(windowManager.focusedWindow == nil ? 
                        "Start Focus Session" : 
                        "Complete current focus session before starting a new one")
                    .disabled(windowManager.focusedWindow != nil)
                }
            }
        }
    }
}

// Helper Views
struct DatePickerView: View {
    @Binding var selectedDate: Date?
    @Binding var showDatePicker: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Select Date")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    showDatePicker = false
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Calendar
            DatePicker(
                "Select Date",
                selection: Binding(
                    get: { selectedDate ?? Date() },
                    set: { selectedDate = $0 }
                ),
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .padding()
            
            Divider()
            
            // Footer
            HStack {
                Button(action: {
                    selectedDate = nil
                    showDatePicker = false
                }) {
                    Text("Clear Date")
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Text(selectedDate?.formatted(date: .abbreviated, time: .omitted) ?? "No date selected")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 300)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
    }
}

#if DEBUG
struct BetterTaskRow_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Regular task
            previewRow(title: "Complete project presentation", 
                      isCompleted: false, 
                      focusedDuration: 3600)
            
            // Completed task
            previewRow(title: "Write documentation", 
                      isCompleted: true, 
                      focusedDuration: 1800)
            
            // Task with category
            previewRow(title: "Research new features",
                      isCompleted: false,
                      focusedDuration: 2400,
                      categoryName: "Development")
            
            // Task in editing mode
            previewRow(title: "Design user interface",
                      isCompleted: false,
                      focusedDuration: 1200,
                      isEditing: true)
            
            // Task with scheduled date
            previewRow(title: "Review pull requests",
                      isCompleted: false,
                      focusedDuration: 900,
                      scheduledDate: Date().addingTimeInterval(86400))
        }
        .padding()
        .frame(width: 600)
        .previewLayout(.sizeThatFits)
    }
    
    static func previewRow(
        title: String,
        isCompleted: Bool,
        focusedDuration: TimeInterval,
        categoryName: String? = nil,
        scheduledDate: Date? = nil,
        isEditing: Bool = false
    ) -> some View {
        let context = PersistenceController.preview.container.viewContext
        let categoryManager = CategoryManager(viewContext: context)
        
        // Create preview task
        let task = ZenFocusTask(context: context)
        task.title = title
        task.isCompleted = isCompleted
        task.focusedDuration = focusedDuration
        task.scheduledDate = scheduledDate
        
        // Create category if needed
        if let categoryName = categoryName {
            let category = Category(context: context)
            category.name = categoryName
            task.categoryRef = category
        }
        
        return BetterTaskRow(
            task: task,
            categoryManager: categoryManager,
            onDelete: {},
            onToggleCompletion: {},
            onStartFocus: {}
        )
        .environmentObject(WindowManager())
    }
}
#endif
