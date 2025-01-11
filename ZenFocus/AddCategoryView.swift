import SwiftUI

struct AddCategoryView: View {
    @ObservedObject var categoryManager: CategoryManager
    @State private var newCategoryName = ""
    @Binding var selectedColor: Color
    @Environment(\.presentationMode) var presentationMode
    @State private var showingError = false
    @State private var errorMessage = ""
    let onDismiss: () -> Void
    let parentCategory: Category?
    
    var isParentCategory: Bool { parentCategory == nil }
    
    private func addCategory() {
        do {
            guard !newCategoryName.isEmpty else {
                throw CategoryError.invalidCategory
            }
            
            // Normalize the category name to lowercase only for child categories
            let normalizedName = isParentCategory ? newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines) : newCategoryName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Check for duplicate names using the CategoryManager method
            if categoryManager.isDuplicateName(normalizedName, parent: parentCategory) {
                throw CategoryError.duplicateName(normalizedName)
            }
            
            if isParentCategory {
                try categoryManager.addParentCategory(normalizedName, color: selectedColor)
            } else {
                try categoryManager.addChildCategory(normalizedName, parent: parentCategory!, color: selectedColor)
            }
            
            ZenFocusLogger.shared.info("Category added successfully: \(normalizedName)")
            presentationMode.wrappedValue.dismiss()
            onDismiss()
            
        } catch let error as CategoryError {
            handleError(error)
        } catch {
            handleError(.saveFailed(error))
        }
    }
    
    private func handleError(_ error: CategoryError) {
        ZenFocusLogger.shared.error("Error adding category", error: error)
        errorMessage = error.localizedDescription
        showingError = true
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text(isParentCategory ? "New Parent Category" : "New Category")
                .font(.headline)
            
            Form {
                Section(header: Text("Category Details")) {
                    TextField("Category name", text: $newCategoryName)
                    ColorPicker("Category Color", selection: $selectedColor)
                    
                    if !isParentCategory, let parent = parentCategory {
                        HStack {
                            Text("Parent Category:")
                            Text(parent.name ?? "")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text("Preset Colors")) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 30))], spacing: 10) {
                        ForEach(CategoryManager.predefinedColors, id: \.self) { color in
                            Circle()
                                .fill(color)
                                .frame(width: 30, height: 30)
                                .overlay(Circle().stroke(Color.primary, lineWidth: 2).opacity(selectedColor == color ? 1 : 0))
                                .onTapGesture { selectedColor = color }
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
                
                Button("Add") {
                    addCategory()
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