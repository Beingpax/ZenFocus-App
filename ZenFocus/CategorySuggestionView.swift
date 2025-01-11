import SwiftUI

struct CategorySuggestionView: View {
    @Binding var input: String
    let onSelect: (String) -> Void
    let onAddNew: (String) -> Void
    @ObservedObject var categoryManager: CategoryManager
    let suggestions: [String]
    @Binding var selectedIndex: Int  
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private func handleCategorySelection(_ categoryName: String) {
        do {
            guard !categoryName.isEmpty else {
                throw CategoryError.invalidCategory
            }
            
            ZenFocusLogger.shared.info("Category suggestion selected: \(categoryName)")
            onSelect(categoryName)
            
        } catch {
            handleError(error)
        }
    }
    
    private func handleNewCategory(_ name: String) {
        do {
            guard !name.isEmpty else {
                throw CategoryError.invalidCategory
            }
            
            guard let uncategorized = categoryManager.uncategorizedCategory else {
                throw CategoryError.uncategorizedNotFound
            }
            
            ZenFocusLogger.shared.info("Creating new category from suggestion: \(name)")
            onAddNew(name)
            
        } catch {
            handleError(error)
        }
    }
    
    private func handleError(_ error: Error) {
        ZenFocusLogger.shared.error("Category suggestion error", error: error)
        errorMessage = error.localizedDescription
        showingError = true
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(suggestions.enumerated()), id: \.element) { index, categoryName in
                    if let category = categoryManager.categories.first(where: { $0.name == categoryName }) {
                        Button(action: { handleCategorySelection(categoryName) }) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(categoryManager.colorForCategory(category))
                                    .frame(width: 12, height: 12)
                                Text(categoryName)
                                    .foregroundColor(.primary)
                                    .font(.system(size: 16))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(index == selectedIndex ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                            .cornerRadius(16)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                if !input.isEmpty && !suggestions.contains(input) {
                    Button(action: { handleNewCategory(input) }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                            Text("Add: \(input)")
                                .font(.system(size: 16))
                        }
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(16)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 50)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 5)
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
}
