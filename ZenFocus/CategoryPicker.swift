import SwiftUI
import CoreData

struct CategoryPicker: View {
    @ObservedObject var categoryManager: CategoryManager
    @Binding var input: String
    let onSelect: (String) -> Void
    let onAddNew: (String) -> Void
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private func handleCategorySelection(_ category: Category) {
        do {
            guard let categoryName = category.name else {
                throw CategoryError.invalidCategory
            }
            
            ZenFocusLogger.shared.info("Category selected: \(categoryName)")
            onSelect(categoryName)
            
        } catch {
            handleError(error)
        }
    }
    
    private func handleError(_ error: Error) {
        ZenFocusLogger.shared.error("Category picker error", error: error)
        errorMessage = error.localizedDescription
        showingError = true
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filteredCategories, id: \.self) { category in
                    Text(category.name ?? "")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(categoryManager.colorForCategory(category).opacity(0.2))
                        .foregroundColor(categoryManager.colorForCategory(category))
                        .cornerRadius(4)
                        .onTapGesture {
                            handleCategorySelection(category)
                        }
                }
                
                if !input.isEmpty && !filteredCategories.contains(where: { $0.name == input }) {
                    Text(input)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                        .onTapGesture {
                            onAddNew(input)
                        }
                }
            }
        }
        .frame(height: 30)
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var filteredCategories: [Category] {
        let childCategories = categoryManager.getChildCategories()
        if input.isEmpty {
            return childCategories
        } else {
            return childCategories.filter { 
                ($0.name ?? "").lowercased().contains(input.lowercased()) 
            }
        }
    }
}