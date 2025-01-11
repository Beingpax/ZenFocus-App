import SwiftUI

struct CategoryEditView: View {
    @ObservedObject var categoryManager: CategoryManager
    let category: Category
    @State private var newCategoryName: String
    @State private var categoryColor: Color
    @Environment(\.presentationMode) var presentationMode
    let onDismiss: () -> Void
    @State private var showingError = false
    @State private var errorMessage = ""
    
    init(categoryManager: CategoryManager, category: Category, onDismiss: @escaping () -> Void) {
        self.categoryManager = categoryManager
        self.category = category
        self._newCategoryName = State(initialValue: category.name ?? "")
        self._categoryColor = State(initialValue: categoryManager.colorForCategory(category))
        self.onDismiss = onDismiss
    }
    
    private func saveChanges() {
        do {
            guard !newCategoryName.isEmpty else {
                throw CategoryError.invalidCategory
            }
            
            // Check for duplicate names
            let siblings = category.parent?.children?.allObjects as? [Category] ?? categoryManager.categories
            if siblings.contains(where: { $0 != category && $0.name == newCategoryName }) {
                throw CategoryError.duplicateName(newCategoryName)
            }
            
            categoryManager.updateCategory(category, newName: newCategoryName, color: categoryColor)
            ZenFocusLogger.shared.info("Category updated successfully: \(newCategoryName)")
            presentationMode.wrappedValue.dismiss()
            onDismiss()
            
        } catch let error as CategoryError {
            handleError(error)
        } catch {
            handleError(.saveFailed(error))
        }
    }
    
    private func handleError(_ error: CategoryError) {
        ZenFocusLogger.shared.error("Category edit error", error: error)
        errorMessage = error.localizedDescription
        showingError = true
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Category")
                .font(.headline)
            
            Form {
                Section(header: Text("Category Details")) {
                    TextField("Category name", text: $newCategoryName)
                    ColorPicker("Category Color", selection: $categoryColor)
                }
                
                Section(header: Text("Preset Colors")) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 30))], spacing: 10) {
                        ForEach(CategoryManager.predefinedColors, id: \.self) { color in
                            Circle()
                                .fill(color)
                                .frame(width: 30, height: 30)
                                .overlay(Circle().stroke(Color.primary, lineWidth: 2).opacity(categoryColor == color ? 1 : 0))
                                .onTapGesture { categoryColor = color }
                        }
                    }
                }
            }
            .formStyle(GroupedFormStyle())
            
            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Save") {
                    saveChanges()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newCategoryName.isEmpty)
            }
            .padding(.top)
        }
        .padding()
        .frame(width: 350, height: 400)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
} 