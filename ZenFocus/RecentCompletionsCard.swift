import SwiftUI

struct RecentCompletionsCard: View {
    let recentCompletions: [ZenFocusTask]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.green)
                    .frame(width: 32, height: 32)
                    .background(Color.green.opacity(0.2))
                    .clipShape(Circle())
                
                Text("Recent Completions")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            ForEach(recentCompletions, id: \.self) { task in
                HStack {
                    Text(task.title ?? "Untitled Task")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(formatDate(task.completedAt ?? Date()))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
