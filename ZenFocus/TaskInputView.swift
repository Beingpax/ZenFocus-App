import SwiftUI
import CoreData
import Foundation
import NaturalLanguage

struct TaskInputView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var categoryManager: CategoryManager
    @State private var newTaskTitle = ""
    @FocusState private var isInputFocused: Bool
    @State private var showCategorySuggestions = false
    @State private var currentSuggestions: [Category] = []
    @State private var categoryInput = ""
    @State private var showingCategoryManagement = false
    @State private var selectedSuggestionIndex: Int = 0
    @EnvironmentObject var quickFocusManager: QuickAddManager
    var showCategoryManagement: Bool
    var onAddTask: (ZenFocusTask) -> Void
    @State private var scheduledDate: Date?
    @State private var showDateSuggestions = false
    @State private var dateInput = ""

    init(categoryManager: CategoryManager, showCategoryManagement: Bool = true, onAddTask: @escaping (ZenFocusTask) -> Void) {
        self.categoryManager = categoryManager
        self.showCategoryManagement = showCategoryManagement
        self.onAddTask = onAddTask
    }

    var body: some View {
        VStack {
            inputField
            
            if showCategorySuggestions {
                categorySuggestionView
            }
            
            if showDateSuggestions {
                dateSuggestionView
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .sheet(isPresented: $showingCategoryManagement) {
            CategoryManagementView(categoryManager: categoryManager)
        }
    }

    private var inputField: some View {
        HStack(spacing: 12) {
            addIcon
            textField
            submitButton
            if showCategoryManagement {
                categoryManagementButton
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.9))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
        )
    }

    private var addIcon: some View {
        Image(systemName: "plus.circle.fill")
            .foregroundColor(Color.accentColor.opacity(0.8))
            .font(.system(size: 20))
            .frame(width: 24, height: 24)
    }

    private var textField: some View {
        TextField("Add a new task", text: $newTaskTitle)
            .textFieldStyle(PlainTextFieldStyle())
            .font(.system(size: 16))
            .frame(height: 30)
            .focused($isInputFocused)
            .onSubmit(handleSubmit)
            .onChange(of: newTaskTitle) { newValue in
                handleCategoryInput(newValue)
            }
    }

    private var submitButton: some View {
        Group {
            if !newTaskTitle.isEmpty {
                Button(action: handleSubmit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(Color.accentColor.opacity(0.8))
                        .font(.system(size: 20))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private var categoryManagementButton: some View {
        Button(action: { showingCategoryManagement = true }) {
            Image(systemName: "tag")
                .foregroundColor(Color.secondary.opacity(0.7))
                .font(.system(size: 18))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var categorySuggestionView: some View {
        CategorySuggestionView(
            input: $categoryInput,
            onSelect: handleCategorySelection,
            onAddNew: handleNewCategory,
            categoryManager: categoryManager,
            suggestions: currentSuggestions.map { $0.name ?? "" },
            selectedIndex: $selectedSuggestionIndex
        )
        .frame(height: 40)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.2), value: showCategorySuggestions)
    }

    private var dateSuggestionView: some View {
        DateSuggestionView(
            input: $dateInput,
            onSelect: { date in
                scheduledDate = date
                if let atIndex = newTaskTitle.lastIndex(of: "@") {
                    newTaskTitle = String(newTaskTitle[..<atIndex]) + "@" + DateParser.formatDate(date)
                }
                showDateSuggestions = false
            }
        )
        .frame(height: 40)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.2), value: showDateSuggestions)
    }

    private func handleCategoryInput(_ newValue: String) {
        // First handle date suggestions
        if let atIndex = newValue.lastIndex(of: "@") {
            showDateSuggestions = true
            dateInput = String(newValue[newValue.index(after: atIndex)...])
            if let parsedDate = DateParser.parseDate(from: dateInput) {
                scheduledDate = parsedDate
            }
        } else {
            showDateSuggestions = false
            dateInput = ""
            scheduledDate = nil
        }
        
        // Handle category suggestions
        if let hashIndex = newValue.lastIndex(of: "#") {
            let afterHash = String(newValue[newValue.index(after: hashIndex)...])
            // Only show suggestions if there's no space yet
            if let spaceIndex = afterHash.firstIndex(of: " ") {
                // If there's a space, hide suggestions as category input is complete
                showCategorySuggestions = false
                currentSuggestions = []
            } else {
                // No space yet, show suggestions for the current input
                categoryInput = afterHash
                showCategorySuggestions = true
                updateCurrentSuggestions()
                selectedSuggestionIndex = 0
            }
        } else {
            showCategorySuggestions = false
            currentSuggestions = []
        }
    }

    private func updateCurrentSuggestions() {
        let childCategories = categoryManager.getChildCategories()
        let searchTerm = categoryInput.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        if searchTerm.isEmpty {
            // Show recently used categories first, then alphabetically
            currentSuggestions = childCategories.sorted { cat1, cat2 in
                guard let name1 = cat1.name, let name2 = cat2.name else { return false }
                return name1.lowercased() < name2.lowercased()
            }
        } else {
            // Improved search with prefix matching having higher priority
            let exactMatches = childCategories.filter { ($0.name ?? "").lowercased() == searchTerm }
            let prefixMatches = childCategories.filter { 
                ($0.name ?? "").lowercased().hasPrefix(searchTerm) && !exactMatches.contains($0)
            }
            let containsMatches = childCategories.filter { 
                ($0.name ?? "").lowercased().contains(searchTerm) && 
                !exactMatches.contains($0) && 
                !prefixMatches.contains($0)
            }
            
            currentSuggestions = exactMatches + prefixMatches + containsMatches
        }
        
        // Limit number of suggestions for better performance
        if currentSuggestions.count > 10 {
            currentSuggestions = Array(currentSuggestions.prefix(10))
        }
    }

    private func handleCategorySelection(_ category: String) {
        if let hashIndex = newTaskTitle.lastIndex(of: "#") {
            let beforeHash = String(newTaskTitle[..<hashIndex])
            let afterHash = String(newTaskTitle[newTaskTitle.index(after: hashIndex)...])
            
            // If there's text after the category (after a space), preserve it
            if let spaceIndex = afterHash.firstIndex(of: " ") {
                let remainingText = String(afterHash[spaceIndex...])
                newTaskTitle = beforeHash + "#" + category + remainingText
            } else {
                newTaskTitle = beforeHash + "#" + category
            }
        }
        showCategorySuggestions = false
        currentSuggestions = []
    }

    private func handleNewCategory(_ newCategory: String) {
        guard !newCategory.isEmpty else {
            ZenFocusLogger.shared.warning("Attempted to create empty category")
            return
        }
        
        // Convert to lowercase for consistency
        let normalizedName = newCategory.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        do {
            // Check for existing category first
            if let existingCategory = findCategory(byName: normalizedName) {
                handleCategorySelection(existingCategory.name ?? "")
                return
            }
            
            // Use the new method to add child category under Uncategorized
            try categoryManager.addUncategorizedChild(normalizedName, color: categoryManager.nextPredefinedColor())
            
            if let newCat = categoryManager.categories.first(where: { $0.name?.lowercased() == normalizedName }) {
                handleCategorySelection(newCat.name ?? "")
                ZenFocusLogger.shared.info("New category created and selected: \(normalizedName)")
            }
        } catch {
            ZenFocusLogger.shared.error("Failed to create new category", error: error)
            showError("Failed to create category: \(error.localizedDescription)")
        }
    }

    private func showError(_ message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Category Error"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    private func handleSubmit() {
        if showCategorySuggestions && !currentSuggestions.isEmpty {
            handleCategorySelection(currentSuggestions[selectedSuggestionIndex].name ?? "")
        }
        do {
            let taskTitle = newTaskTitle
            guard !taskTitle.isEmpty else { return }

            let newTask = try createTask(with: taskTitle)
            try saveTask(newTask)
            
            withAnimation {
                resetInputState()
            }
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func addTask(title: String) {
        guard !title.isEmpty else { return }

        do {
            let newTask = try createTask(with: title)
            try saveTask(newTask)
            
            withAnimation {
                // Only animate UI updates
            }
        } catch {
            showError(error.localizedDescription)
        }
    }

    private struct TaskValidation {
        static let maxTitleLength = 500
        
        static func validateTitle(_ title: String) throws {
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedTitle.isEmpty {
                throw TaskError.invalidTitle("Task title cannot be empty")
            }
            
            if trimmedTitle.count > maxTitleLength {
                throw TaskError.invalidTitle("Task title cannot exceed \(maxTitleLength) characters")
            }
        }
    }

    enum TaskError: LocalizedError {
        case invalidTitle(String)
        case saveFailed(Error)
        case categoryError(Error)
        
        var errorDescription: String? {
            switch self {
            case .invalidTitle(let reason):
                return "Invalid task title: \(reason)"
            case .saveFailed(let error):
                return "Failed to save task: \(error.localizedDescription)"
            case .categoryError(let error):
                return "Category error: \(error.localizedDescription)"
            }
        }
    }

    private func createTask(with title: String? = nil) throws -> ZenFocusTask {
        let taskTitle = title ?? newTaskTitle
        
        // Validate task title
        try TaskValidation.validateTitle(taskTitle)
        
        let newTask = ZenFocusTask(context: viewContext)
        
        // Parse the title to extract category and date
        var cleanTitle = taskTitle
        
        // Extract and handle category
        if let hashIndex = taskTitle.firstIndex(of: "#") {
            let afterHash = String(taskTitle[taskTitle.index(after: hashIndex)...])
            if let spaceIndex = afterHash.firstIndex(of: " ") {
                let categoryName = String(afterHash[..<spaceIndex])
                try handleCategoryForTask(newTask, categoryName: categoryName)
                // Remove the category part from the title
                cleanTitle = String(taskTitle[..<hashIndex]) + String(afterHash[spaceIndex...])
            } else {
                let categoryName = afterHash
                try handleCategoryForTask(newTask, categoryName: categoryName)
                cleanTitle = String(taskTitle[..<hashIndex])
            }
        }
        
        // Remove the date part if present
        if let atIndex = cleanTitle.firstIndex(of: "@") {
            cleanTitle = String(cleanTitle[..<atIndex])
        }
        
        // Set the clean title
        newTask.title = cleanTitle.trimmingCharacters(in: .whitespaces)
        newTask.createdAt = Date()
        newTask.isCompleted = false
        newTask.scheduledDate = scheduledDate
        
        return newTask
    }

    private func handleCategoryForTask(_ task: ZenFocusTask, categoryName: String) throws {
        // Convert category name to lowercase for consistency
        let normalizedName = categoryName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // First try to find existing category
        if let existingCategory = findCategory(byName: normalizedName) {
            task.categoryRef = existingCategory
            return
        }
        
        // Create new category under Uncategorized
        try categoryManager.addUncategorizedChild(normalizedName, color: categoryManager.nextPredefinedColor())
        
        if let newCategory = findCategory(byName: normalizedName) {
            task.categoryRef = newCategory
        } else {
            throw TaskError.categoryError(CategoryError.invalidCategory)
        }
    }

    private func findCategory(byName name: String) -> Category? {
        let normalizedName = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return categoryManager.getChildCategories().first { 
            ($0.name ?? "").lowercased() == normalizedName
        }
    }

    private func saveTask(_ task: ZenFocusTask) throws {
        do {
            try viewContext.save()
            onAddTask(task)
        } catch {
            throw TaskError.saveFailed(error)
        }
    }

    private func resetInputState() {
        newTaskTitle = ""
        isInputFocused = true
        showCategorySuggestions = false
    }
}
