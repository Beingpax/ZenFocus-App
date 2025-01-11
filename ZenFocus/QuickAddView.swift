import SwiftUI

struct QuickAddView: View {
    @EnvironmentObject var categoryManager: CategoryManager
    @State private var isAppearing = false
    let onSubmit: (ZenFocusTask) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                CardHeaderView(title: "Quick Add Task", icon: "plus.circle.fill", color: .blue)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            
            Divider()
                .background(Color.gray.opacity(0.2))
            
            TaskInputView(categoryManager: categoryManager, showCategoryManagement: false, onAddTask: onSubmit)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .frame(width: 600)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .scaleEffect(isAppearing ? 1 : 0.98)
        .opacity(isAppearing ? 1 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0), value: isAppearing)
        .onAppear { isAppearing = true }
        .onExitCommand(perform: onCancel)
    }
}
