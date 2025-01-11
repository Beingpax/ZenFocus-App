import SwiftUI
import CoreData
import AppKit

/// Manages categories for tasks in the ZenFocus app.
class CategoryManager: ObservableObject {
    /// The Core Data managed object context.
    let viewContext: NSManagedObjectContext
    
    /// A dictionary of categories and their associated colors.
    @Published var categories: [Category] = []
    
    static let predefinedColors: [Color] = [
        Color(red: 0.65, green: 0.95, blue: 0.75),  // Mint Green
        Color(red: 0.65, green: 0.75, blue: 0.95),  // Ocean Blue
        Color(red: 0.95, green: 0.95, blue: 0.65),  // Sunshine Yellow
        Color(red: 0.75, green: 0.65, blue: 0.95),  // Lavender Purple
        Color(red: 0.65, green: 0.95, blue: 0.95),  // Aqua Cyan
        Color(red: 0.95, green: 0.75, blue: 0.65),  // Peach Orange
        Color(red: 0.75, green: 0.95, blue: 0.65),  // Lime Green
        Color(red: 0.65, green: 0.85, blue: 0.95),  // Sky Blue
        Color(red: 0.95, green: 0.65, blue: 0.75),  // Rose Pink
        Color(red: 0.85, green: 0.70, blue: 0.50),  // Terracotta
        Color(red: 0.50, green: 0.85, blue: 0.70),  // Teal Green
        Color(red: 0.70, green: 0.50, blue: 0.85),  // Amethyst Purple
        Color(red: 0.85, green: 0.85, blue: 0.50),  // Pale Gold
        Color(red: 0.50, green: 0.85, blue: 0.85),  // Turquoise
        Color(red: 0.85, green: 0.50, blue: 0.50),  // Coral Red
        Color(red: 0.50, green: 0.70, blue: 0.85),  // Slate Blue
        Color(red: 0.85, green: 0.65, blue: 0.50),  // Amber
        Color(red: 0.70, green: 0.85, blue: 0.50),  // Olive Green
        Color(red: 0.85, green: 0.50, blue: 0.70),  // Magenta
    ]

    static let textColor = Color.black  // Black text for better contrast

    public var uncategorizedCategory: Category? {
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", "Uncategorized")
        return try? viewContext.fetch(request).first
    }

    /// Initializes a new CategoryManager with the given managed object context.
    /// - Parameter viewContext: The Core Data managed object context to use.
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
        ensureUncategorizedExists()
        migrateExistingCategories()
        loadCategories()
    }
    
    private func ensureUncategorizedExists() {
        if uncategorizedCategory == nil {
            let uncategorized = Category(context: viewContext)
            uncategorized.name = "Uncategorized"
            uncategorized.children = NSSet()
            
            do {
                try viewContext.save()
            } catch {
                print("Error creating Uncategorized category: \(error)")
            }
        }
    }
    
    private static var migrationInProgress = false
    private let migrationStatusKey = "ZenFocus.categoryMigrationCompleted"

    private func migrateExistingCategories() {
        // Check if migration is already in progress or completed
        if Self.migrationInProgress || UserDefaults.standard.bool(forKey: migrationStatusKey) {
            return
        }
        
        // Set migration in progress flag
        Self.migrationInProgress = true
        
        guard let uncategorized = uncategorizedCategory else {
            print("Error: Uncategorized category not found")
            Self.migrationInProgress = false
            return
        }
        
        // Fetch ONLY tasks that need migration
        let request: NSFetchRequest<ZenFocusTask> = ZenFocusTask.fetchRequest()
        request.predicate = NSPredicate(format: "category != nil AND categoryRef == nil")
        
        do {
            let tasks = try viewContext.fetch(request)
            if tasks.isEmpty {
                // No migration needed, mark as completed
                UserDefaults.standard.set(true, forKey: migrationStatusKey)
                Self.migrationInProgress = false
                return
            }
            
            // Show migration warning only once
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                let alert = NSAlert()
                alert.messageText = "Data Migration Required"
                alert.informativeText = "ZenFocus needs to update \(tasks.count) tasks to support the new category system. This process is automatic and your existing categories will be preserved. Would you like to proceed?"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Proceed")
                alert.addButton(withTitle: "Cancel")
                
                // Create backup before proceeding
                self.backupExistingData()
                
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    self.performMigration(tasks: tasks, uncategorized: uncategorized)
                } else {
                    // Show warning that app might not work correctly
                    let warningAlert = NSAlert()
                    warningAlert.messageText = "Migration Skipped"
                    warningAlert.informativeText = "Some tasks may not display correctly until the migration is completed. You can restart the app to try again."
                    warningAlert.alertStyle = .critical
                    warningAlert.addButton(withTitle: "OK")
                    warningAlert.runModal()
                    
                    // Reset migration flag since it was cancelled
                    Self.migrationInProgress = false
                }
            }
        } catch {
            ZenFocusLogger.shared.error("Error checking for migration needs", error: error)
            Self.migrationInProgress = false
        }
    }

    private func performMigration(tasks: [ZenFocusTask], uncategorized: Category) {
        let backgroundContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        backgroundContext.parent = viewContext
        
        let uncategorizedID = uncategorized.objectID
        
        backgroundContext.perform {
            do {
                guard let uncategorizedInBackground = backgroundContext.object(with: uncategorizedID) as? Category else {
                    throw NSError(domain: "CategoryManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get uncategorized category in background context"])
                }
                
                // First, try to match with existing categories
                let existingCategoriesRequest: NSFetchRequest<Category> = Category.fetchRequest()
                let existingCategories = try backgroundContext.fetch(existingCategoriesRequest)
                
                var categoryMap: [String: Category] = [:]
                
                // Create or find Category entities for each task that needs migration
                for task in tasks {
                    guard let oldCategoryName = task.category else { continue }
                    
                    if let existingCategory = categoryMap[oldCategoryName] {
                        // Use already processed category
                        let taskInBackground = backgroundContext.object(with: task.objectID) as! ZenFocusTask
                        taskInBackground.categoryRef = existingCategory
                        taskInBackground.category = nil
                        continue
                    }
                    
                    // Try to find matching existing category first
                    if let matchingCategory = existingCategories.first(where: { $0.name == oldCategoryName }) {
                        categoryMap[oldCategoryName] = matchingCategory
                        let taskInBackground = backgroundContext.object(with: task.objectID) as! ZenFocusTask
                        taskInBackground.categoryRef = matchingCategory
                        taskInBackground.category = nil
                        continue
                    }
                    
                    // Create new category only if no matching category exists
                    let newCategory = Category(context: backgroundContext)
                    newCategory.name = oldCategoryName
                    newCategory.parent = uncategorizedInBackground
                    
                    // Handle color data...
                    if let colorComponents = UserDefaults.standard.array(forKey: "category_color_\(oldCategoryName)") as? [CGFloat] {
                        let color = Color(red: colorComponents[0], green: colorComponents[1], blue: colorComponents[2], opacity: colorComponents[3])
                        let components = ColorComponents(color: color)
                        if let colorData = try? JSONEncoder().encode(components) {
                            newCategory.colorData = colorData
                        }
                    } else {
                        let color = self.nextPredefinedColor()
                        let components = ColorComponents(color: color)
                        if let colorData = try? JSONEncoder().encode(components) {
                            newCategory.colorData = colorData
                        }
                    }
                    
                    categoryMap[oldCategoryName] = newCategory
                    
                    let taskInBackground = backgroundContext.object(with: task.objectID) as! ZenFocusTask
                    taskInBackground.categoryRef = newCategory
                    taskInBackground.category = nil
                }
                
                // Save the background context
                try backgroundContext.save()
                
                // Save the main context
                try self.viewContext.performAndWait {
                    do {
                        try self.viewContext.save()
                        
                        DispatchQueue.main.async {
                            // Show success alert with restart prompt
                            let alert = NSAlert()
                            alert.messageText = "Migration Complete"
                            alert.informativeText = "Your categories have been successfully migrated. The app needs to restart to complete the process."
                            alert.alertStyle = .informational
                            alert.addButton(withTitle: "Restart Now")
                            alert.addButton(withTitle: "Restart Later")
                            
                            let response = alert.runModal()
                            if response == .alertFirstButtonReturn {
                                // Restart the app
                                let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
                                let path = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
                                let task = Process()
                                task.launchPath = "/usr/bin/open"
                                task.arguments = [path]
                                task.launch()
                                
                                NSApplication.shared.terminate(nil)
                            }
                        }
                    } catch {
                        throw error
                    }
                }
                
                ZenFocusLogger.shared.info("Category migration completed successfully")
                
                // After successful migration, mark as completed
                UserDefaults.standard.set(true, forKey: self.migrationStatusKey)
                Self.migrationInProgress = false
                
            } catch {
                // If migration fails, reset flags
                Self.migrationInProgress = false
                UserDefaults.standard.set(false, forKey: self.migrationStatusKey)
                
                DispatchQueue.main.async {
                    self.handleMigrationError(error, backupURL: nil)
                }
                ZenFocusLogger.shared.error("Category migration failed", error: error)
            }
        }
    }
    
    func loadCategories() {
        do {
            let request: NSFetchRequest<Category> = Category.fetchRequest()
            categories = try viewContext.fetch(request)
            objectWillChange.send()
            ZenFocusLogger.shared.info("Categories loaded successfully")
        } catch {
            handleCategoryError(.saveFailed(error))
        }
    }
    
    func addCategory(_ name: String, parent: Category?, color: Color? = nil) throws {
        do {
            // Validate category name
            try validateCategoryName(name)
            
            // Validate parent if provided
            if let parent = parent {
                try validateCategoryOperation(parent)
            }
            
            // Check for duplicate names
            if isDuplicateName(name, parent: parent) {
                throw CategoryError.duplicateName(name)
            }
            
            let category = Category(context: viewContext)
            category.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            category.parent = parent
            
            let newColor = color ?? nextPredefinedColor()
            let components = ColorComponents(color: newColor)
            
            guard let colorData = try? JSONEncoder().encode(components) else {
                throw CategoryError.colorEncodingFailed
            }
            category.colorData = colorData
            
            try viewContext.save()
            loadCategories()
            
            ZenFocusLogger.shared.info("Category added successfully: \(name)")
            
        } catch let error as CategoryError {
            ZenFocusLogger.shared.error("Failed to add category", error: error)
            throw error
        } catch {
            ZenFocusLogger.shared.error("Unexpected error adding category", error: error)
            throw CategoryError.saveFailed(error)
        }
    }

    // Modify these two methods to properly handle throws
    func addParentCategory(_ name: String, color: Color? = nil) throws {
        // Explicitly create a parent category with no parent
        try addCategory(name, parent: nil, color: color)
    }

    func addChildCategory(_ name: String, parent: Category, color: Color? = nil) throws {
        // Explicitly create a child category with the specified parent
        try addCategory(name, parent: parent, color: color)
    }
    
    func updateCategory(_ category: Category, newName: String, color: Color) {
        do {
            guard !newName.isEmpty else {
                throw CategoryError.invalidCategory
            }
            
            // Check for duplicate names at the same level
            let siblings = category.parent?.children?.allObjects as? [Category] ?? categories
            if siblings.contains(where: { $0 != category && $0.name == newName }) {
                throw CategoryError.duplicateName(newName)
            }
            
            category.name = newName
            
            let components = ColorComponents(color: color)
            guard let colorData = try? JSONEncoder().encode(components) else {
                throw CategoryError.colorEncodingFailed
            }
            category.colorData = colorData
            
            try viewContext.save()
            loadCategories()
            
            ZenFocusLogger.shared.info("Category updated successfully: \(newName)")
            
        } catch let error as CategoryError {
            handleCategoryError(error)
        } catch {
            handleCategoryError(.saveFailed(error))
        }
    }
    
    func deleteCategory(_ category: Category) throws {
        do {
            try validateCategoryOperation(category)
            
            // Check for children
            if let children = category.children, children.count > 0 {
                throw CategoryError.invalidOperation("Cannot delete category with child categories")
            }
            
            // Remove category reference from tasks
            if let tasks = category.tasks as? Set<ZenFocusTask> {
                for task in tasks {
                    task.categoryRef = nil
                    ZenFocusLogger.shared.info("Removed category reference from task: \(task.title ?? "")")
                }
            }
            
            viewContext.delete(category)
            try viewContext.save()
            loadCategories()
            
            ZenFocusLogger.shared.info("Category deleted successfully: \(category.name ?? "")")
            
        } catch let error as CategoryError {
            ZenFocusLogger.shared.error("Failed to delete category", error: error)
            throw error
        } catch {
            ZenFocusLogger.shared.error("Unexpected error deleting category", error: error)
            throw CategoryError.saveFailed(error)
        }
    }
    
    func colorForCategory(_ category: Category) -> Color {
        if let colorData = category.colorData,
           let components = try? JSONDecoder().decode(ColorComponents.self, from: colorData) {
            return components.color
        }
        
        // If no color is found or there's an error, assign and save a new color
        let newColor = nextPredefinedColor()
        let components = ColorComponents(color: newColor)
        if let colorData = try? JSONEncoder().encode(components) {
            category.colorData = colorData
            
            do {
                try viewContext.save()
            } catch {
                print("Error saving new category color: \(error)")
            }
        }
        
        return newColor
    }
    
    func getRootCategories() -> [Category] {
        return categories.filter { $0.parent?.name == "Uncategorized" }
    }
    
    func getChildCategories(for parent: Category) -> [Category] {
        return categories.filter { $0.parent == parent }
    }
    
    func getChildCategories() -> [Category] {
        return categories.filter { category in
            // Return true if the category has a parent (making it a child category)
            category.parent != nil
        }
    }
    
    public func nextPredefinedColor() -> Color {
        // Get all currently used colors
        let usedColors = categories.compactMap { category -> Color? in
            guard let colorData = category.colorData,
                  let components = try? JSONDecoder().decode(ColorComponents.self, from: colorData) else {
                return nil
            }
            return components.color
        }
        
        // Find the first unused color from predefined colors
        for predefinedColor in Self.predefinedColors {
            if !usedColors.contains(where: { areColorsEqual($0, predefinedColor) }) {
                return predefinedColor
            }
        }
        
        // If all colors are used, return a random color from predefined colors
        return Self.predefinedColors.randomElement() ?? Self.predefinedColors[0]
    }

    // Add this helper function at the bottom of CategoryManager class
    private func areColorsEqual(_ color1: Color, _ color2: Color) -> Bool {
        let components1 = ColorComponents(color: color1)
        let components2 = ColorComponents(color: color2)
        
        return abs(components1.red - components2.red) < 0.01 &&
               abs(components1.green - components2.green) < 0.01 &&
               abs(components1.blue - components2.blue) < 0.01
    }

    func getParentCategories() -> [Category] {
        let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "parent == nil")
        
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            print("Error fetching parent categories: \(error)")
            return []
        }
    }

    private func backupExistingData() {
        guard let storeURL = viewContext.persistentStoreCoordinator?.persistentStores.first?.url else { return }
        
        let fileManager = FileManager.default
        let backupDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ZenFocus/Backups", isDirectory: true)
        
        do {
            try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
            let timestamp = dateFormatter.string(from: Date())
            
            let backupURL = backupDirectory.appendingPathComponent("ZenFocus-\(timestamp).backup")
            
            try fileManager.copyItem(at: storeURL, to: backupURL)
            ZenFocusLogger.shared.info("Database backup created successfully at \(backupURL.path)")
        } catch {
            ZenFocusLogger.shared.error("Failed to create database backup", error: error)
        }
    }

    private func handleMigrationError(_ error: Error, backupURL: URL?) {
        DispatchQueue.main.async {
            let errorAlert = NSAlert()
            errorAlert.messageText = "Migration Error"
            errorAlert.informativeText = """
                An error occurred during migration: \(error.localizedDescription)
                
                Your data has been preserved in a backup file.
                Would you like to:
                """
            errorAlert.alertStyle = .critical
            errorAlert.addButton(withTitle: "Try Again")
            errorAlert.addButton(withTitle: "Quit App")
            errorAlert.addButton(withTitle: "Continue Without Migration")
            
            if let backupPath = backupURL?.path {
                errorAlert.informativeText += "\n\nBackup location: \(backupPath)"
            }
            
            let response = errorAlert.runModal()
            switch response {
            case .alertFirstButtonReturn:  // Try Again
                self.migrateExistingCategories()
            case .alertSecondButtonReturn:  // Quit App
                NSApplication.shared.terminate(nil)
            default:  // Continue Without Migration
                let warningAlert = NSAlert()
                warningAlert.messageText = "Warning"
                warningAlert.informativeText = "Some features may not work correctly. You can try migration again by restarting the app."
                warningAlert.alertStyle = .warning
                warningAlert.runModal()
            }
        }
    }

    private func handleCategoryError(_ error: CategoryError) {
        let message: String
        let title: String
        
        switch error {
        case .uncategorizedNotFound:
            message = "The Uncategorized category could not be found."
            title = "Category Error"
        case .invalidCategory:
            message = "The category name cannot be empty."
            title = "Invalid Category"
        case .duplicateName(let name):
            message = "A category with the name '\(name)' already exists at this level."
            title = "Duplicate Category"
        case .saveFailed(let underlyingError):
            message = "Failed to save changes: \(underlyingError.localizedDescription)"
            title = "Save Error"
        case .migrationFailed(let underlyingError):
            message = "Failed to migrate categories: \(underlyingError.localizedDescription)"
            title = "Migration Error"
        case .colorEncodingFailed:
            message = "Failed to encode category color."
            title = "Color Error"
        case .contextSaveFailed(let underlyingError):
            message = "Failed to save context: \(underlyingError.localizedDescription)"
            title = "Save Error"
        case .invalidName(let reason):
            message = "Invalid category name: \(reason)"
            title = "Invalid Category"
        case .invalidOperation(let reason):
            message = "Invalid operation: \(reason)"
            title = "Invalid Operation"
        case .maxDepthExceeded:
            message = "Maximum category nesting depth exceeded (limit: 5 levels)."
            title = "Depth Error"
        case .systemCategoryModification:
            message = "System categories cannot be modified."
            title = "System Error"
        }
        
        ZenFocusLogger.shared.error("\(title): \(message)")
        
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    // Add this method to CategoryManager class
    func isDuplicateName(_ name: String, parent: Category?) -> Bool {
        // For parent categories, check among other parent categories
        if parent == nil {
            return categories.contains { 
                $0.parent == nil && $0.name?.lowercased() == name.lowercased() 
            }
        }
        
        // For child categories, check among ALL child categories regardless of parent
        let allChildCategories = categories.filter { $0.parent != nil }
        return allChildCategories.contains { 
            $0.name?.lowercased() == name.lowercased() 
        }
    }

    // Add validation methods
    private func validateCategoryName(_ name: String) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedName.isEmpty {
            throw CategoryError.invalidName("Category name cannot be empty")
        }
        
        if trimmedName.count > 50 {
            throw CategoryError.invalidName("Category name cannot exceed 50 characters")
        }
        
        if trimmedName.contains(where: { $0.isNewline }) {
            throw CategoryError.invalidName("Category name cannot contain line breaks")
        }
        
        // Check for special characters that might cause issues
        let invalidCharacters = CharacterSet(charactersIn: "/@#$%^&*(){}[]\\|;:\"<>")
        if trimmedName.rangeOfCharacter(from: invalidCharacters) != nil {
            throw CategoryError.invalidName("Category name contains invalid characters")
        }
    }
    
    private func validateCategoryOperation(_ category: Category?) throws {
        guard let category = category else {
            throw CategoryError.invalidCategory
        }
        
        // Only prevent direct modification of Uncategorized category
        // Allow adding children to it
        if category.name == "Uncategorized" && category == uncategorizedCategory {
            throw CategoryError.systemCategoryModification
        }
        
        // Check category depth
        if categoryDepth(category) >= 5 {
            throw CategoryError.maxDepthExceeded
        }
    }
    
    private func categoryDepth(_ category: Category) -> Int {
        var depth = 0
        var current: Category? = category
        
        while let parent = current?.parent {
            depth += 1
            current = parent
            
            // Prevent infinite loops from corrupted data
            if depth > 100 {
                ZenFocusLogger.shared.error("Possible circular reference detected in category hierarchy")
                break
            }
        }
        
        return depth
    }

    // Add a helper method for creating child categories under Uncategorized
    func addUncategorizedChild(_ name: String, color: Color? = nil) throws {
        guard let uncategorized = uncategorizedCategory else {
            throw CategoryError.uncategorizedNotFound
        }
        
        // Skip validation of Uncategorized as parent but validate the new category
        try validateCategoryName(name)
        
        // Check for duplicate names among all child categories
        if isDuplicateName(name, parent: uncategorized) {
            throw CategoryError.duplicateName(name)
        }
        
        let category = Category(context: viewContext)
        category.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        category.parent = uncategorized
        
        let newColor = color ?? nextPredefinedColor()
        let components = ColorComponents(color: newColor)
        
        guard let colorData = try? JSONEncoder().encode(components) else {
            throw CategoryError.colorEncodingFailed
        }
        category.colorData = colorData
        
        try viewContext.save()
        loadCategories()
        
        ZenFocusLogger.shared.info("Child category added to Uncategorized: \(name)")
    }
}

// Add this struct at the top of the file, outside the class
private struct ColorComponents: Codable {
    let red: Double
    let green: Double
    let blue: Double
    let opacity: Double
    
    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }
    
    init(color: Color) {
        // Convert to CGColor space first to handle dynamic system colors
        let nsColor = NSColor(color)
        if let rgbColor = nsColor.usingColorSpace(.deviceRGB) {
            self.red = Double(rgbColor.redComponent)
            self.green = Double(rgbColor.greenComponent)
            self.blue = Double(rgbColor.blueComponent)
            self.opacity = Double(rgbColor.alphaComponent)
        } else {
            // Fallback to a default color if conversion fails
            self.red = 0.5
            self.green = 0.5
            self.blue = 0.5
            self.opacity = 1.0
            ZenFocusLogger.shared.warning("Failed to convert color to RGB space, using fallback color")
        }
    }
}

// Add these error types at the top of the file
enum CategoryError: Error {
    case uncategorizedNotFound
    case invalidCategory
    case duplicateName(String)
    case saveFailed(Error)
    case migrationFailed(Error)
    case colorEncodingFailed
    case contextSaveFailed(Error)
    case invalidName(String)           // New: For name validation failures
    case invalidOperation(String)      // New: For operation-specific errors
    case maxDepthExceeded             // New: For preventing deep nesting
    case systemCategoryModification   // New: For protecting system categories
}

// Make CategoryError more descriptive
extension CategoryError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .uncategorizedNotFound:
            return "The Uncategorized category could not be found."
        case .invalidCategory:
            return "The category is invalid or cannot be modified."
        case .duplicateName(let name):
            return "A category with the name '\(name)' already exists."
        case .invalidName(let reason):
            return "Invalid category name: \(reason)"
        case .invalidOperation(let reason):
            return "Invalid operation: \(reason)"
        case .maxDepthExceeded:
            return "Maximum category nesting depth exceeded (limit: 5 levels)."
        case .systemCategoryModification:
            return "System categories cannot be modified."
        case .saveFailed(let error):
            return "Failed to save changes: \(error.localizedDescription)"
        case .migrationFailed(let error):
            return "Failed to migrate categories: \(error.localizedDescription)"
        case .colorEncodingFailed:
            return "Failed to encode category color."
        case .contextSaveFailed(let error):
            return "Failed to save context: \(error.localizedDescription)"
        }
    }
}
