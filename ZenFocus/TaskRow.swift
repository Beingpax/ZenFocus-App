import SwiftUI
import CoreData

struct TaskRow: View {
    @ObservedObject var task: ZenFocusTask
    @ObservedObject var categoryManager: CategoryManager
    @EnvironmentObject var windowManager: WindowManager
    var onDelete: () -> Void
    var onStartFocus: (ZenFocusTask) -> Void
    
    @State private var isPaused: Bool = false
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        HStack(spacing: 12) {
            Text(task.title ?? "")
                .strikethrough(task.isCompleted)
                .foregroundColor(task.isCompleted ? .secondary : .primary)
                .font(.system(size: 18, weight: .bold))
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer()
            
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
            
            HStack(spacing: 16) {
                Button(action: toggleCompletion) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle.dotted")
                        .foregroundColor(task.isCompleted ? .green : .secondary)
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(task.isCompleted ? Color.green.opacity(0.1) : Color.secondary.opacity(0.1))
                        )
                        .accessibilityLabel(task.isCompleted ? "Mark as incomplete" : "Mark as complete")
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    onStartFocus(task)
                }) {
                    Image(systemName: "bolt.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(task.isCompleted)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .background(Color.clear)
        .contentShape(Rectangle())
        .contextMenu {
            Button(action: {
                showingDeleteConfirmation = true
            }) {
                Label("Delete", systemImage: "trash")
            }
        }
        .alert(isPresented: $showingDeleteConfirmation) {
            Alert(
                title: Text("Delete Task"),
                message: Text("Are you sure you want to delete this task?"),
                primaryButton: .destructive(Text("Delete")) {
                    onDelete()
                },
                secondaryButton: .cancel()
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .taskPauseStateChanged)) { notification in
            if let taskID = notification.userInfo?["taskID"] as? NSManagedObjectID,
               let pauseState = notification.userInfo?["isPaused"] as? Bool,
               taskID == task.objectID {
                isPaused = pauseState
            }
        }
    }
    
    private func categoryPill(_ category: Category) -> some View {
        Text(category.name ?? "")
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(categoryManager.colorForCategory(category))
            .foregroundColor(CategoryManager.textColor)
            .cornerRadius(6)
    }
    
    private func toggleCompletion() {
        withAnimation {
            task.isCompleted.toggle()
            if task.isCompleted {
                task.completedAt = Date()
                NotificationCenter.default.post(name: .taskCompleted, object: nil)
            } else {
                task.completedAt = nil
            }
            try? task.managedObjectContext?.save()
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