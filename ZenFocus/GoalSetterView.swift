import SwiftUI
import AppKit

struct GoalSetterView: View {
    @Binding var dailyGoalMinutes: Int
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedHours: Int
    @State private var selectedMinutes: Int
    
    init(dailyGoalMinutes: Binding<Int>) {
        self._dailyGoalMinutes = dailyGoalMinutes
        _selectedHours = State(initialValue: dailyGoalMinutes.wrappedValue / 60)
        _selectedMinutes = State(initialValue: (dailyGoalMinutes.wrappedValue % 60) / 5 * 5)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            header
            quoteSection
            timeSelectionSection
            totalTimeSection
            buttonSection
        }
        .padding(24)
        .background(.thinMaterial)
        
    }
    
    private var header: some View {
        Text("Set Your Daily Focus Goal")
            .font(.system(size: 24, weight: .bold))
            .foregroundColor(.primary)
    }
    
    private var quoteSection: some View {
        Text("Setting goals is the first step in turning the invisible into the visible.")
            .font(.system(size: 14))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
    }
    
    private var timeSelectionSection: some View {
        HStack(spacing: 24) {
            timePickerView(label: "Hours", selection: $selectedHours, range: 0...23)
            timePickerView(label: "Minutes", selection: $selectedMinutes, range: 0...55, step: 5)
        }
        .padding(.vertical, 8)
    }
    
    private var totalTimeSection: some View {
        Text("Total: \(formatDuration(Double(selectedHours * 3600 + selectedMinutes * 60)))")
            .font(.system(size: 18, weight: .medium))
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(8)
    }
    
    private var buttonSection: some View {
        HStack {
            Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            }
            .keyboardShortcut(.cancelAction)
            .buttonStyle(MacButtonStyle(isDestructive: true))
            
            Spacer()
            
            Button("Save") {
                dailyGoalMinutes = selectedHours * 60 + selectedMinutes
                presentationMode.wrappedValue.dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(MacButtonStyle())
        }
    }
    
    private func timePickerView(label: String, selection: Binding<Int>, range: ClosedRange<Int>, step: Int = 1) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            Picker(label, selection: selection) {
                ForEach(Array(stride(from: range.lowerBound, through: range.upperBound, by: step)), id: \.self) { value in
                    Text("\(value)").tag(value)
                }
            }
            .labelsHidden()
            .frame(width: 100)
            .pickerStyle(DefaultPickerStyle())
        }
    }
    
    private func formatDuration(_ duration: Double) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return String(format: "%dh %dm", hours, minutes)
    }
}

struct MacButtonStyle: ButtonStyle {
    var isDestructive: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isDestructive ? Color.red.opacity(0.1) : Color.accentColor.opacity(0.1))
            .foregroundColor(isDestructive ? .red : .accentColor)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

