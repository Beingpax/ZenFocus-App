import SwiftUI

struct DateSuggestionView: View {
    @Binding var input: String
    let onSelect: (Date) -> Void
    
    private var suggestions: [(text: String, date: Date)] {
        var allSuggestions: [(text: String, date: Date?)] = []
        
        // Add basic suggestions
        allSuggestions += basicSuggestions()
        
        // Add relative date suggestions
        allSuggestions += relativeDateSuggestions()
        
        // Add weekday suggestions
        allSuggestions += weekdaySuggestions()
        
        // Add month suggestions if input contains a month name or number
        allSuggestions += monthDaySuggestions()
        
        // Filter suggestions based on input
        let filteredSuggestions = allSuggestions
            .filter { suggestion in
                suggestion.text.lowercased().contains(input.lowercased()) &&
                suggestion.date != nil
            }
            .map { ($0.text, $0.date!) }
        
        // Add the parsed date from user input if it's valid and different from suggestions
        if let parsedDate = DateParser.parseDate(from: input),
           !filteredSuggestions.contains(where: { Calendar.current.isDate($0.1, inSameDayAs: parsedDate) }) {
            return [(input, parsedDate)] + filteredSuggestions
        }
        
        return filteredSuggestions
    }
    
    private func basicSuggestions() -> [(text: String, date: Date?)] {
        return [
            ("today", DateParser.parseDate(from: "today")),
            ("tomorrow", DateParser.parseDate(from: "tomorrow")),
            ("next week", DateParser.parseDate(from: "next week")),
            ("this weekend", DateParser.parseDate(from: "this weekend")),
            ("next weekend", DateParser.parseDate(from: "next weekend")),
            ("next month", DateParser.parseDate(from: "next month")),
            ("end of week", DateParser.parseDate(from: "end of week")),
            ("end of month", DateParser.parseDate(from: "end of month"))
        ]
    }
    
    private func relativeDateSuggestions() -> [(text: String, date: Date?)] {
        var suggestions: [(text: String, date: Date?)] = []
        
        // Add "in X days" suggestions
        for days in [2, 3, 4, 5, 7] {
            let text = "in \(days) days"
            suggestions.append((text, DateParser.parseDate(from: text)))
        }
        
        // Add "in X weeks" suggestions
        for weeks in [2, 3, 4] {
            let text = "in \(weeks) weeks"
            suggestions.append((text, DateParser.parseDate(from: text)))
        }
        
        return suggestions
    }
    
    private func weekdaySuggestions() -> [(text: String, date: Date?)] {
        let weekdays = [
            "monday", "tuesday", "wednesday", "thursday",
            "friday", "saturday", "sunday"
        ]
        
        var suggestions: [(text: String, date: Date?)] = []
        
        for weekday in weekdays {
            // Add "next weekday" suggestions
            let nextText = "next \(weekday)"
            suggestions.append((nextText, DateParser.parseDate(from: nextText)))
            
            // Add "this weekday" suggestions
            let thisText = "this \(weekday)"
            suggestions.append((thisText, DateParser.parseDate(from: thisText)))
        }
        
        return suggestions
    }
    
    private func monthDaySuggestions() -> [(text: String, date: Date?)] {
        let currentMonth = Calendar.current.component(.month, from: Date())
        let months = [
            "january", "february", "march", "april", "may", "june",
            "july", "august", "september", "october", "november", "december"
        ]
        
        var suggestions: [(text: String, date: Date?)] = []
        
        // Only suggest dates for current and next few months
        for monthOffset in 0...2 {
            let targetMonthIndex = (currentMonth - 1 + monthOffset) % 12
            let monthName = months[targetMonthIndex]
            
            // Add suggestions for important days of the month
            for day in [1, 5, 10, 15, 20, 25, 30] {
                let text = "\(day) \(monthName)"
                if let date = DateParser.parseDate(from: text) {
                    suggestions.append((text, date))
                }
            }
        }
        
        return suggestions
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(suggestions, id: \.text) { suggestion in
                    Button(action: { onSelect(suggestion.1) }) {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.system(size: 12))
                            VStack(alignment: .leading) {
                                Text(suggestion.0)
                                    .foregroundColor(.primary)
                                    .font(.system(size: 14))
                                Text(DateParser.formatRelativeDate(suggestion.1))
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 12))
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(16)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 50)
        .cornerRadius(8)
    }
} 