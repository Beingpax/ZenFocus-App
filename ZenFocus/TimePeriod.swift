import Foundation

enum TimePeriod: String, CaseIterable {
    case day = "Today"
    case yesterday = "Yesterday"
    case week = "This Week"
    case month = "This Month"
    case year = "This Year"
    case allTime = "All Time"
    
    func dateRange() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .day:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now)!
            return (start, end)
        case .yesterday:
            let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: now)!)
            let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: start)!
            return (start, end)
        case .week:
            let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now)!
            return (start, end)
        case .month:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now)!
            return (start, end)
        case .year:
            let start = calendar.date(from: calendar.dateComponents([.year], from: now))!
            let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now)!
            return (start, end)
        case .allTime:
            let pastDate = calendar.date(byAdding: .year, value: -10, to: now) ?? Date.distantPast
            return (pastDate, now)
        }
    }
    
    func dateRangeString() -> String {
        let dateRange = self.dateRange()
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        switch self {
        case .day:
            return "Today"
        case .yesterday:
            return "Yesterday"
        case .week, .month, .year:
            return "\(formatter.string(from: dateRange.start)) - \(formatter.string(from: dateRange.end))"
        case .allTime:
            return "All Time"
        }
    }
}