import SwiftUI
import Charts

struct CategoryTimeBreakdownCard: View {
    let categoryTimes: [(String, TimeInterval)]
    @ObservedObject var categoryManager: CategoryManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardHeaderView(title: "Time Breakdown by Category", icon: "chart.pie.fill", color: .purple)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            
            if categoryTimes.isEmpty {
                emptyStateView
                    .padding(20)
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 150), spacing: 32)
                    ]
                ) {
                    ForEach(categoryTimes.prefix(6), id: \.0) { category, time in
                        CategoryCircle(
                            category: category,
                            time: time,
                            totalTime: totalTime,
                            color: colorForCategory(category)
                        )
                    }
                }
                .padding(24)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    private var emptyStateView: some View {
        HStack {
            Spacer()
            Text("No data available")
                .foregroundColor(.secondary)
                .padding()
            Spacer()
        }
    }
    
    private var totalTime: TimeInterval {
        categoryTimes.reduce(0) { $0 + $1.1 }
    }
    
    private func colorForCategory(_ categoryName: String) -> Color {
        if categoryName == "Uncategorized" {
            return .gray
        }
        
        let categories = categoryManager.getChildCategories()
        if let category = categories.first(where: { $0.name == categoryName }) {
            return categoryManager.colorForCategory(category)
        }
        
        return .gray
    }
}

struct CategoryCircle: View {
    let category: String
    let time: TimeInterval
    let totalTime: TimeInterval
    let color: Color
    
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                    .frame(width: 160, height: 160)
                
                Circle()
                    .trim(from: 0, to: CGFloat(time / totalTime))
                    .stroke(color, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 4) {
                    Text(String(format: "%.1f%%", (time / totalTime) * 100))
                        .font(.system(size: 20, weight: .bold))
                    Text(formatDuration(time))
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            
            Text(category)
                
                .font(.system(size: 14, weight: .medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 40)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return String(format: "%dh %dm", hours, minutes)
    }
}

struct CategoryTimeBreakdownCard_Previews: PreviewProvider {
    static var sampleData: [(String, TimeInterval)] = [
        ("Coding", 7200),     // 2 hours
        ("Reading", 5400),    // 1.5 hours
        ("Writing", 3600),    // 1 hour
        ("Exercise", 2700),   // 45 minutes
        ("Meditation", 1800), // 30 minutes
        ("Study", 1200)       // 20 minutes
    ]
    
    static var previews: some View {
        Group {
            // Preview with data
            CategoryTimeBreakdownCard(
                categoryTimes: sampleData,
                categoryManager: CategoryManager(viewContext: PersistenceController.preview.container.viewContext)
            )
            .frame(height: 350)
            .padding()
            
            // Empty state preview
            CategoryTimeBreakdownCard(
                categoryTimes: [],
                categoryManager: CategoryManager(viewContext: PersistenceController.preview.container.viewContext)
            )
            .frame(height: 350)
            .padding()
        }
    }
}


