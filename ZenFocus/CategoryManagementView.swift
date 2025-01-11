import SwiftUI
import UniformTypeIdentifiers

private let categoryUTType = "com.zenfocus.category"

struct CategoryManagementView: View {
    @ObservedObject var categoryManager: CategoryManager
    @State private var editingCategory: Category?
    @State private var isAddingNewCategory = false
    @State private var selectedParentCategory: Category?
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedColor: Color = .blue
    @State private var draggingCategory: Category?
    @State private var showingDeleteError = false
    @State private var showingDeleteConfirmation = false
    @State private var categoryToDelete: Category?
    
    private let columns = [
        GridItem(.flexible(minimum: 300), spacing: 16),
        GridItem(.flexible(minimum: 300), spacing: 16),
        GridItem(.flexible(minimum: 300), spacing: 16)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            
           
            
            kanbanBoard

             HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Pro tip: Quickly add child categories by typing '#category' when adding a task")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.yellow.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .frame(width: 1000, height: 700)
        .background(Color(.windowBackgroundColor))
        .sheet(item: $editingCategory) { category in
            CategoryEditView(
                categoryManager: categoryManager,
                category: category
            ) {
                editingCategory = nil
            }
        }
        .sheet(isPresented: $isAddingNewCategory) {
            AddCategoryView(
                categoryManager: categoryManager,
                selectedColor: $selectedColor,
                onDismiss: { 
                    isAddingNewCategory = false
                    selectedParentCategory = nil  // Reset the selected parent
                },
                parentCategory: selectedParentCategory
            )
        }
        .alert("Cannot Delete Category", isPresented: $showingDeleteError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This category contains child categories. Please delete or move all child categories first.")
        }
        .alert("Delete Category", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let category = categoryToDelete {
                    do {
                        try categoryManager.deleteCategory(category)
                    } catch {
                        showError("Failed to delete category: \(error.localizedDescription)")
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this category? This action cannot be undone.")
        }
    }
    
    private var headerSection: some View {
        HStack {
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            
            Spacer()
            
            Text("Categories")
                .font(.headline)
            
            Spacer()
            
            Button(action: { 
                selectedParentCategory = nil  // Ensure no parent is selected
                isAddingNewCategory = true    // Use single state variable
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("n", modifiers: [.command])
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.windowBackgroundColor))
    }
    
    private var kanbanBoard: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                if let uncategorized = categoryManager.uncategorizedCategory {
                    categoryColumn(uncategorized)
                }
                
                ForEach(categoryManager.categories.filter { $0.parent == nil && $0.name != "Uncategorized" }, id: \.self) { parentCategory in
                    categoryColumn(parentCategory)
                }
            }
            .padding()
        }
    }
    
    private func categoryColumn(_ parentCategory: Category) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            columnHeader(for: parentCategory)
            categoryList(for: parentCategory)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
                .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
        )
        .onDrop(
            of: [.text],
            delegate: CategoryDropDelegate(
                parentCategory: parentCategory,
                draggingCategory: $draggingCategory,
                categoryManager: categoryManager,
                viewContext: categoryManager.viewContext
            )
        )
    }
    
    private func columnHeader(for parentCategory: Category) -> some View {
        HStack {
            Text(parentCategory.name ?? "")
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            HStack(spacing: 12) {
                if parentCategory.name != "Uncategorized" {
                    Menu {
                        Button(action: { editingCategory = parentCategory }) {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive, action: {
                            handleCategoryDelete(parentCategory)
                        }) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                }
                
                Button(action: { 
                    selectedParentCategory = parentCategory
                    isAddingNewCategory = true 
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    private func categoryList(for parentCategory: Category) -> some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(categoryManager.getChildCategories(for: parentCategory), id: \.self) { category in
                    CategoryCard(
                        category: category,
                        categoryManager: categoryManager,
                        onEdit: { editingCategory = category },
                        onDelete: { handleCategoryDelete(category) }
                    )
                    .onDrag {
                        draggingCategory = category
                        return NSItemProvider(object: (category.name ?? "") as NSString)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .frame(height: 300)
    }
    
    private func handleCategoryDelete(_ category: Category) {
        do {
            // Check if category has children
            if let children = category.children as? Set<Category>, !children.isEmpty {
                showingDeleteError = true
                return
            }
            
            categoryToDelete = category
            showingDeleteConfirmation = true
            
        } catch {
            showError("Failed to prepare category deletion: \(error.localizedDescription)")
        }
    }
    
    private func showError(_ message: String) {
        ZenFocusLogger.shared.error("Category operation error: \(message)")
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Category Error"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}

struct CategoryCard: View {
    let category: Category
    let categoryManager: CategoryManager
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        HStack {
            Circle()
                .fill(categoryManager.colorForCategory(category))
                .frame(width: 8, height: 8)
            
            Text(category.name ?? "")
                .lineLimit(1)
                .font(.system(size: 13))
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
            }
            .foregroundColor(.secondary.opacity(isHovered ? 1 : 0))
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(categoryManager.colorForCategory(category).opacity(0.3), lineWidth: 1)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onHover { hovering in
            if hovering {
                NSCursor.dragLink.push()
            } else {
                NSCursor.pop()
            }
        }
    }
    
    private func showError(_ message: String) {
        ZenFocusLogger.shared.error("Category operation error: \(message)")
        errorMessage = message
        showingError = true
    }
}

struct CategoryDropDelegate: DropDelegate {
    let parentCategory: Category
    @Binding var draggingCategory: Category?
    let categoryManager: CategoryManager
    let viewContext: NSManagedObjectContext
    
    func performDrop(info: DropInfo) -> Bool {
        guard let draggingCategory = self.draggingCategory else {
            ZenFocusLogger.shared.error("Drop failed: No dragging category found")
            return false
        }
        
        // Prevent dropping on itself
        if draggingCategory == parentCategory {
            ZenFocusLogger.shared.warning("Attempted to drop category onto itself")
            return false
        }
        
        // Prevent creating circular references
        if isCircularReference(draggingCategory, newParent: parentCategory) {
            ZenFocusLogger.shared.error("Drop failed: Would create circular reference")
            showCircularReferenceError()
            return false
        }
        
        do {
            // Update the parent of the dragged category
            draggingCategory.parent = parentCategory
            try viewContext.save()
            categoryManager.loadCategories()
            
            ZenFocusLogger.shared.info("Category '\(draggingCategory.name ?? "")' moved to parent '\(parentCategory.name ?? "")'")
            return true
        } catch {
            ZenFocusLogger.shared.error("Error updating category parent", error: error)
            showErrorAlert(error)
            return false
        }
    }
    
    func validateDrop(info: DropInfo) -> Bool {
        // Add validation logic
        guard let draggingCategory = draggingCategory else { return false }
        return draggingCategory != parentCategory && !isCircularReference(draggingCategory, newParent: parentCategory)
    }
    
    func dropEntered(info: DropInfo) {
        // Add visual feedback if needed
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
    
    private func isCircularReference(_ category: Category, newParent: Category) -> Bool {
        var current = newParent
        while let parent = current.parent {
            if parent == category {
                return true
            }
            current = parent
        }
        return false
    }
    
    private func showCircularReferenceError() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Invalid Operation"
            alert.informativeText = "Cannot move a category into one of its descendants."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    private func showErrorAlert(_ error: Error) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Error Moving Category"
            alert.informativeText = "Failed to move category: \(error.localizedDescription)"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}

// Make Category conform to Identifiable
