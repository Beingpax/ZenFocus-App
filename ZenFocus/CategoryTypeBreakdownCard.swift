import SwiftUI

struct CategoryTypeBreakdownCard: View {
    let completedTasks: [ZenFocusTask]
    @ObservedObject var categoryManager: CategoryManager
    @State private var selectedSegment: String?
    @State private var hoveredSegment: String?
    
    private var typeBreakdown: [(String, TimeInterval)] {
        let groupedByType = Dictionary(grouping: completedTasks) { task -> String in
            if let category = task.categoryRef {
                return category.parent?.name ?? category.name ?? "Uncategorized"
            }
            return "Uncategorized"
        }
        
        let typeTimePairs = groupedByType.mapValues { tasks in
            tasks.reduce(0) { $0 + $1.focusedDuration }
        }
        
        return typeTimePairs.sorted { $0.value > $1.value }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardHeaderView(title: "Focus Distribution", icon: "chart.pie.fill", color: .indigo)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            
            if typeBreakdown.isEmpty {
                emptyStateView
                    .padding(20)
            } else {
                GeometryReader { geometry in
                    let chartSize = min(geometry.size.height - 64, geometry.size.width * 0.45)
                    
                    HStack(alignment: .top, spacing: 24) {
                        // Donut Chart
                        VStack {
                            Spacer()
                            DonutChart(
                                data: typeBreakdown,
                                selected: $selectedSegment,
                                hovered: $hoveredSegment,
                                colorForType: colorForType
                            )
                            .frame(width: chartSize, height: chartSize)
                            .frame(maxWidth: 200)
                            Spacer()
                        }
                        .frame(width: geometry.size.width * 0.4)
                        .padding(.leading, 24)
                        
                        // Legend
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Breakdown")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                                .padding(.top, 16)
                            
                            ScrollView(showsIndicators: false) {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(typeBreakdown, id: \.0) { type, time in
                                        LegendItem(
                                            type: type,
                                            time: time,
                                            totalTime: totalTime,
                                            color: colorForType(type),
                                            isSelected: type == selectedSegment,
                                            isHovered: type == hoveredSegment
                                        )
                                        .onTapGesture {
                                            withAnimation(.easeInOut) {
                                                selectedSegment = selectedSegment == type ? nil : type
                                            }
                                        }
                                        .onHover { isHovered in
                                            hoveredSegment = isHovered ? type : nil
                                        }
                                    }
                                }
                                
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.trailing, 24)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
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
        typeBreakdown.reduce(0) { $0 + $1.1 }
    }
    
    private func colorForType(_ typeName: String) -> Color {
        if typeName == "Uncategorized" {
            return .gray
        }
        
        let categories = categoryManager.getParentCategories()
        if let category = categories.first(where: { $0.name == typeName }) {
            return categoryManager.colorForCategory(category)
        }
        
        return .indigo
    }
}

struct DonutChart: View {
    let data: [(String, TimeInterval)]
    @Binding var selected: String?
    @Binding var hovered: String?
    let colorForType: (String) -> Color
    
    private var total: Double {
        data.reduce(0) { $0 + $1.1 }
    }
    
    var body: some View {
        ZStack {
            ForEach(data.indices, id: \.self) { index in
                let (type, value) = data[index]
                let percentage = value / total
                let isSelected = type == selected
                let isHovered = type == hovered
                
                PieSegment(
                    startAngle: startAngle(for: index),
                    endAngle: endAngle(for: index),
                    color: colorForType(type),
                    isSelected: isSelected,
                    isHovered: isHovered
                )
                .onTapGesture {
                    withAnimation(.easeInOut) {
                        selected = selected == type ? nil : type
                    }
                }
            }
            
            // Center hole
            Circle()
                .fill(Color(NSColor.controlBackgroundColor))
                .frame(width: 100, height: 100)
            
            // Center text
            if let selectedType = selected,
               let selectedValue = data.first(where: { $0.0 == selectedType })?.1 {
                VStack(spacing: 4) {
                    Text(formatPercentage(selectedValue / total))
                        .font(.system(size: 20, weight: .bold))
                    Text(selectedType)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(spacing: 4) {
                    Text(formatDuration(total))
                        .font(.system(size: 16, weight: .bold))
                    Text("Total")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func startAngle(for index: Int) -> Double {
        let precedingTotal = data.prefix(index).reduce(0) { $0 + $1.1 }
        return (precedingTotal / total) * 360 - 90
    }
    
    private func endAngle(for index: Int) -> Double {
        let precedingTotal = data.prefix(index + 1).reduce(0) { $0 + $1.1 }
        return (precedingTotal / total) * 360 - 90
    }
    
    private func formatPercentage(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return String(format: "%dh %dm", hours, minutes)
    }
}

struct PieSegment: View {
    let startAngle: Double
    let endAngle: Double
    let color: Color
    let isSelected: Bool
    let isHovered: Bool
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                let radius = min(geometry.size.width, geometry.size.height) / 2
                let innerRadius = radius * 0.6
                
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(startAngle),
                    endAngle: .degrees(endAngle),
                    clockwise: false
                )
                
                path.addArc(
                    center: center,
                    radius: innerRadius,
                    startAngle: .degrees(endAngle),
                    endAngle: .degrees(startAngle),
                    clockwise: true
                )
                
                path.closeSubpath()
            }
            .fill(color.opacity(isSelected || isHovered ? 1 : 0.7))
            .shadow(color: isSelected ? color.opacity(0.3) : .clear, radius: 5)
            .scaleEffect(isSelected ? 1.05 : 1)
            .animation(.spring(response: 0.3), value: isSelected)
        }
    }
}

struct LegendItem: View {
    let type: String
    let time: TimeInterval
    let totalTime: TimeInterval
    let color: Color
    let isSelected: Bool
    let isHovered: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Color indicator and type name
            HStack(spacing: 8) {
                Circle()
                    .fill(color.opacity(isSelected || isHovered ? 1 : 0.7))
                    .frame(width: 8, height: 8)
                
                Text(type)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Time and percentage
            HStack(spacing: 8) {
                Text(formatDuration(time))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Text("•")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Text(String(format: "%.1f%%", (time / totalTime) * 100))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(minWidth: 45, alignment: .trailing)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected || isHovered ? color.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return String(format: "%dh %dm", hours, minutes)
    }
}

