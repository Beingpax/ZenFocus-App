import Foundation

enum DateParsingError: LocalizedError {
    case invalidFormat
    case invalidDate
    case invalidWeekday
    case invalidNumber
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid date format"
        case .invalidDate:
            return "Invalid date"
        case .invalidWeekday:
            return "Invalid weekday"
        case .invalidNumber:
            return "Invalid number"
        }
    }
}

struct DateParser {
    // MARK: - Public Methods
    static func parseDate(from input: String) -> Date? {
        let lowercasedInput = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try parsing in order of precedence
        return parseSpecialKeyword(lowercasedInput) ??
               parseRelativeDate(lowercasedInput) ??
               parseWeekday(lowercasedInput) ??
               parseMonthDay(lowercasedInput) ??
               parseCustomFormat(lowercasedInput)
    }
    
    // MARK: - Private Methods
    private static func parseSpecialKeyword(_ input: String) -> Date? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        switch input {
        case "today":
            return today
            
        case "tomorrow":
            return calendar.date(byAdding: .day, value: 1, to: today)
            
        case "next week":
            return calendar.date(byAdding: .weekOfYear, value: 1, to: today)
            
        case "next month":
            return calendar.date(byAdding: .month, value: 1, to: today)
            
        case "weekend", "this weekend":
            // Find next Saturday
            var nextWeekend = today
            while calendar.component(.weekday, from: nextWeekend) != 7 {
                nextWeekend = calendar.date(byAdding: .day, value: 1, to: nextWeekend)!
            }
            return nextWeekend
            
        case "next weekend":
            // Find next Saturday after this week
            var nextWeekend = calendar.date(byAdding: .day, value: 7, to: today)!
            while calendar.component(.weekday, from: nextWeekend) != 7 {
                nextWeekend = calendar.date(byAdding: .day, value: 1, to: nextWeekend)!
            }
            return nextWeekend
            
        case "end of week":
            return calendar.date(byAdding: .day, value: 7 - calendar.component(.weekday, from: today), to: today)
            
        case "end of month":
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: today) else { return nil }
            return calendar.date(byAdding: .day, value: -1, to: calendar.startOfMonth(for: nextMonth))
            
        default:
            return nil
        }
    }
    
    private static func parseRelativeDate(_ input: String) -> Date? {
        let components = input.components(separatedBy: .whitespaces)
        
        // Handle "in X days/weeks/months" format
        if components.count >= 3 && components[0] == "in" {
            let number = components[1]
            let unit = components[2]
            
            let numberValue: Int
            if let num = Int(number) {
                numberValue = num
            } else if let num = wordToNumber(number) {
                numberValue = num
            } else {
                return nil
            }
            
            var dateComponents = DateComponents()
            
            switch unit {
            case "day", "days":
                dateComponents.day = numberValue
            case "week", "weeks":
                dateComponents.day = numberValue * 7
            case "month", "months":
                dateComponents.month = numberValue
            default:
                return nil
            }
            
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            return calendar.date(byAdding: dateComponents, to: today)
        }
        
        // Handle "X days/weeks/months from now" format
        if components.count >= 4 && components.suffix(2).joined(separator: " ") == "from now" {
            let number = components[0]
            let unit = components[1]
            
            let numberValue: Int
            if let num = Int(number) {
                numberValue = num
            } else if let num = wordToNumber(number) {
                numberValue = num
            } else {
                return nil
            }
            
            var dateComponents = DateComponents()
            
            switch unit {
            case "day", "days":
                dateComponents.day = numberValue
            case "week", "weeks":
                dateComponents.day = numberValue * 7
            case "month", "months":
                dateComponents.month = numberValue
            default:
                return nil
            }
            
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            return calendar.date(byAdding: dateComponents, to: today)
        }
        
        return nil
    }
    
    private static func parseWeekday(_ input: String) -> Date? {
        let weekdays = [
            "sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4,
            "thursday": 5, "friday": 6, "saturday": 7
        ]
        
        let components = input.components(separatedBy: .whitespaces)
        
        // Handle "next monday" format
        if components.count >= 2 && components[0] == "next",
           let weekdayNumber = weekdays[components[1]] {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            var dateComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
            dateComponents.weekday = weekdayNumber
            
            guard let nextWeekday = calendar.date(from: dateComponents) else { return nil }
            
            if nextWeekday <= today {
                return calendar.date(byAdding: .weekOfYear, value: 1, to: nextWeekday)
            }
            
            return nextWeekday
        }
        
        // Handle "this monday" format
        if components.count >= 2 && components[0] == "this",
           let weekdayNumber = weekdays[components[1]] {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            var dateComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
            dateComponents.weekday = weekdayNumber
            
            guard let thisWeekday = calendar.date(from: dateComponents) else { return nil }
            
            if thisWeekday < today {
                return calendar.date(byAdding: .weekOfYear, value: 1, to: thisWeekday)
            }
            
            return thisWeekday
        }
        
        return nil
    }
    
    private static func parseMonthDay(_ input: String) -> Date? {
        let months = [
            "january": 1, "february": 2, "march": 3, "april": 4, "may": 5, "june": 6,
            "july": 7, "august": 8, "september": 9, "october": 10, "november": 11, "december": 12
        ]
        
        let components = input.components(separatedBy: .whitespaces)
        
        // Handle "15 january" or "january 15" format
        if components.count >= 2 {
            let monthStr: String
            let dayStr: String
            
            if let _ = Int(components[0]) {
                dayStr = components[0]
                monthStr = components[1]
            } else {
                monthStr = components[0]
                dayStr = components[1]
            }
            
            guard let month = months[monthStr],
                  let day = Int(dayStr),
                  day >= 1 && day <= 31 else {
                return nil
            }
            
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            var components = calendar.dateComponents([.year], from: today)
            components.month = month
            components.day = day
            
            guard let date = calendar.date(from: components) else { return nil }
            
            // If the date has passed this year, use next year
            if date < today {
                components.year! += 1
                return calendar.date(from: components)
            }
            
            return date
        }
        
        return nil
    }
    
    private static func parseCustomFormat(_ input: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.current
        
        // Try common date formats
        let formats = [
            "dd/MM",
            "MM/dd",
            "dd-MM",
            "MM-dd"
        ]
        
        for format in formats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: input) {
                // Adjust year if needed
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                var components = calendar.dateComponents([.year], from: today)
                let month = calendar.component(.month, from: date)
                let day = calendar.component(.day, from: date)
                components.month = month
                components.day = day
                
                guard let adjustedDate = calendar.date(from: components) else { continue }
                
                if adjustedDate < today {
                    components.year! += 1
                    return calendar.date(from: components)
                }
                
                return adjustedDate
            }
        }
        
        return nil
    }
    
    private static func wordToNumber(_ word: String) -> Int? {
        let numberWords = [
            "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
            "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10
        ]
        return numberWords[word.lowercased()]
    }
}

// MARK: - Date Formatting
extension DateParser {
    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    static func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
} 