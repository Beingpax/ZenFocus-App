import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var currentPage = 0
    
    @AppStorage("userName") private var userName = ""
    @AppStorage("dailyGoalMinutes") private var dailyGoalMinutes = 120
    @AppStorage("reminderInterval") private var reminderInterval = 600
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color(NSColor.windowBackgroundColor)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    pages[currentPage].content()
                        .frame(height: geometry.size.height * 0.8)
                        .padding(.horizontal)
                    
                    Spacer()
                    
                    navigationButtons(geometry: geometry)
                        .padding(.bottom, geometry.size.height * 0.05)
                }
                .frame(width: geometry.size.width * 0.9, height: geometry.size.height * 0.9)
                .background(
                    VisualEffectView(material: .popover, blendingMode: .behindWindow)
                )
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
            }
        }
    }
    
    private var pages: [OnboardingPage] {
        [
            OnboardingPage(
                title: "Welcome to ZenFocus",
                description: "Your personal productivity companion designed to help you achieve deep focus and accomplish your tasks with ease.",
                image: "app.badge.checkmark.fill",
                content: { AnyView(WelcomePage()) }
            ),
            OnboardingPage(
                title: "Task Management",
                description: "Easily add, organize, and track your tasks to stay on top of your goals.",
                image: "list.bullet.clipboard",
                content: { AnyView(TaskManagementPage()) }
            ),
            OnboardingPage(
                title: "Daily Planning",
                description: "Plan your day effectively and focus on what matters most.",
                image: "calendar",
                content: { AnyView(DailyPlanningPage()) }
            ),
            OnboardingPage(
                title: "Focus Sessions",
                description: "Dive into distraction-free work sessions and boost your productivity.",
                image: "timer",
                content: { AnyView(FocusSessionPage()) }
            ),
            OnboardingPage(
                title: "Progress Tracking",
                description: "Visualize your productivity with detailed stats and insights.",
                image: "chart.bar.fill",
                content: { AnyView(ProgressTrackingPage()) }
            ),
            OnboardingPage(
                title: "Personalize Your Experience",
                description: "Let's set up ZenFocus to fit your needs.",
                image: "person.fill",
                content: { AnyView(PersonalizationPage(userName: $userName)) }
            ),
            OnboardingPage(
                title: "Set Your Daily Goal",
                description: "How much time do you want to dedicate to focused work each day?",
                image: "target",
                content: { AnyView(DailyGoalPage(dailyGoalMinutes: $dailyGoalMinutes, userName: $userName)) }
            ),
            OnboardingPage(
                title: "Reminder Settings",
                description: "How often would you like ZenFocus to check in during your focus sessions?",
                image: "bell.fill",
                content: { AnyView(ReminderSettingsPage(reminderInterval: $reminderInterval)) }
            ),
            OnboardingPage(
                title: "Getting Started",
                description: "Let's walk through the key steps to start using ZenFocus effectively.",
                image: "list.bullet.clipboard.fill",
                content: { AnyView(GettingStartedGuide()) }
            ),
            OnboardingPage(
                title: "Join the Community",
                description: "Connect with other ZenFocus users and shape the future of the app.",
                image: "bubble.left.and.bubble.right.fill",
                content: { AnyView(CommunityPage()) }
            )
        ]
    }
    
    private func navigationButtons(geometry: GeometryProxy) -> some View {
        HStack {
            if currentPage > 0 {
                Button(action: { withAnimation { currentPage -= 1 } }) {
                    Text("Previous")
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Spacer()
            
            pageIndicators
            
            Spacer()
            
            Button(action: {
                if currentPage < pages.count - 1 {
                    withAnimation { currentPage += 1 }
                } else {
                    withAnimation {
                        appState.hasCompletedOnboarding = true
                    }
                }
            }) {
                Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal)
    }
    
    private var pageIndicators: some View {
        HStack(spacing: 8) {
            ForEach(0..<pages.count, id: \.self) { index in
                Circle()
                    .fill(currentPage == index ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .scaleEffect(currentPage == index ? 1.2 : 1)
                    .animation(.spring(), value: currentPage)
            }
        }
    }
}

struct OnboardingPage {
    let title: String
    let description: String
    let image: String
    let content: () -> AnyView
}

struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "app.badge.checkmark.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .foregroundColor(.accentColor)
                .padding()
                .background(Circle().fill(Color.accentColor.opacity(0.1)))
            
            Text("Welcome to ZenFocus")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text("Your personal productivity companion designed to help you achieve deep focus and accomplish your tasks with ease.")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .foregroundColor(.secondary)
            
            Text("Let's explore the key features of ZenFocus and how they can revolutionize your productivity!")
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct TaskManagementPage: View {
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "list.bullet.clipboard")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.white)
                .padding()
                .background(Circle().fill(Color.accentColor))
            
            Text("Task Management")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 15) {
                FeatureRow(icon: "plus.circle", text: "Add tasks quickly with a simple interface")
                FeatureRow(icon: "tag", text: "Categorize tasks for better organization")
                FeatureRow(icon: "arrow.up.arrow.down", text: "Start focusing on on what matters")
                FeatureRow(icon: "checkmark.circle", text: "Mark tasks as complete to track progress")
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 15).fill(Color(.windowBackgroundColor)))
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            
            Text("Tip: Use the '@' symbol when adding a task to quickly assign a category!")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.top)
        }
        .padding()
    }
}

struct FocusSessionPage: View {
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "timer")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.white)
                .padding()
                .background(Circle().fill(Color.accentColor))
            
            Text("Focus Sessions")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 15) {
                FeatureRow(icon: "play.circle", text: "Start a focus session for any task")
                FeatureRow(icon: "bell", text: "Get reminders to stay on track")
                FeatureRow(icon: "pause.circle", text: "Take breaks when needed")
                FeatureRow(icon: "clock", text: "Track time spent on each task")
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 15).fill(Color(.windowBackgroundColor)))
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            
            Text("Tip: Use the focus session feature to enter a distraction-free work mode and boost your productivity!")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.top)
        }
        .padding()
    }
}

struct ProgressTrackingPage: View {
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "chart.bar.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.white)
                .padding()
                .background(Circle().fill(Color.accentColor))
            
            Text("Progress Tracking")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 15) {
                FeatureRow(icon: "calendar", text: "View daily and weekly progress")
                FeatureRow(icon: "chart.pie", text: "Analyze time spent on different categories")
                FeatureRow(icon: "star", text: "Set and track productivity goals")
                FeatureRow(icon: "arrow.up.right", text: "Identify trends and improve over time")
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 15).fill(Color(.windowBackgroundColor)))
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            
            Text("Tip: Regularly check your progress to stay motivated and identify areas for improvement!")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.top)
        }
        .padding()
    }
}

struct PersonalizationPage: View {
    @Binding var userName: String
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "person.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.white)
                .padding()
                .background(Circle().fill(Color.accentColor))
            
            Text("Let's Make This Personal")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text("Your name helps us tailor ZenFocus to your unique journey.")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            TextField("Enter your name", text: $userName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .padding()
            
           
        }
        .padding()
    }
}

struct DailyGoalPage: View {
    @Binding var dailyGoalMinutes: Int
    @State private var selectedHours: Int = 2
    @State private var selectedMinutes: Int = 0
    @Binding var userName: String
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "target")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.white)
                .padding()
                .background(Circle().fill(Color.accentColor))
            
            if !userName.isEmpty {
                Text("Great to meet you, \(userName)! Time to set your daily goal. ")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .transition(.opacity)
                    .animation(.easeInOut, value: userName)
            }
            
            Text("How much time do you want to dedicate to focused work each day?")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            HStack {
                Picker("Hours", selection: $selectedHours) {
                    ForEach(0...8, id: \.self) { hour in
                        Text("\(hour) h").tag(hour)
                    }
                }
                .pickerStyle(DefaultPickerStyle())
                .frame(width: 100)
                
                Picker("Minutes", selection: $selectedMinutes) {
                    ForEach([0, 15, 30, 45], id: \.self) { minute in
                        Text("\(minute) m").tag(minute)
                    }
                }
                .pickerStyle(DefaultPickerStyle())
                .frame(width: 100)
            }
            .padding()
            
            Text("Your daily goal: \(selectedHours) hours \(selectedMinutes) minutes")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            
            Text("Don't worry, you can always adjust this later in the app settings.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.top)
        }
        .padding()
        .onChange(of: selectedHours) { _ in updateDailyGoal() }
        .onChange(of: selectedMinutes) { _ in updateDailyGoal() }
    }
    
    private func updateDailyGoal() {
        dailyGoalMinutes = (selectedHours * 60) + selectedMinutes
    }
}

struct ReminderSettingsPage: View {
    @Binding var reminderInterval: Int
    @State private var selectedInterval: Int = 600 // Default to 10 minutes
    
    let intervals = [
        (300, "5 minutes"),
        (600, "10 minutes"),
        (900, "15 minutes"),
        (1200, "20 minutes"),
        (1800, "30 minutes")
    ]
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "bell.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.white)
                .padding()
                .background(Circle().fill(Color.accentColor))
            
            Text("Stay on Track with Reminders")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text("How often would you like ZenFocus to check in during your focus sessions?")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Picker("Reminder Interval", selection: $selectedInterval) {
                ForEach(intervals, id: \.0) { interval in
                    Text(interval.1).tag(interval.0)
                }
            }
            .pickerStyle(DefaultPickerStyle())
            .frame(height: 100)
            .padding()
            
            Text("We'll gently remind you every \(intervals.first { $0.0 == selectedInterval }?.1 ?? "") to help you stay focused.")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text("You can adjust this setting anytime in the app preferences.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.top)
        }
        .padding()
        .onChange(of: selectedInterval) { newValue in
            reminderInterval = newValue
        }
    }
}

struct GettingStartedGuide: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Quick Start Guide")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 16) {
                StepView(number: 1, title: "Add Your Tasks", description: "Use the task input field to add tasks to your 'Someday' list.")
                
                StepView(number: 2, title: "Plan Your Day", description: "Each morning, move tasks from 'Someday' to 'Today' to plan your daily focus.")
                
                StepView(number: 3, title: "Start a Focus Session", description: "Click the 'Let's Crush It!' button to begin a focused work session on your next task.")
                
                StepView(number: 4, title: "Track Your Progress", description: "Use the Progress tab to monitor your daily and weekly focus time.")
                
                StepView(number: 5, title: "Review and Adjust", description: "Regularly check your stats and adjust your daily goal as needed.")
            }
            
            Text("Remember, ZenFocus is here to help you stay productive and achieve your goals. You've got this!")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.top)
        }
        .padding()
    }
}

struct StepView: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text("\(number)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.accentColor))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .font(.system(size: 24))
                .frame(width: 30)
            Text(text)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .fixedSize(horizontal: false, vertical: true) // Prevents text truncation
        }
    }
}

struct DailyPlanningPage: View {
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "calendar")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.white)
                .padding()
                .background(Circle().fill(Color.accentColor))
            
            Text("Daily Planning")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 15) {
                FeatureRow(icon: "list.bullet.rectangle", text: "Plan your day each morning")
                FeatureRow(icon: "arrow.up.arrow.down", text: "Prioritize tasks for today's focus")
                FeatureRow(icon: "calendar.badge.clock", text: "Easily move tasks between 'Someday' and 'Today'")
                FeatureRow(icon: "chart.bar.fill", text: "Track daily progress towards your focus goal")
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 15).fill(Color(.windowBackgroundColor)))
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            
            Text("Tip: Start each day by reviewing and planning your tasks to stay focused and productive!")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.top)
        }
        .padding()
    }
}

struct CommunityPage: View {
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.white)
                .padding()
                .background(Circle().fill(Color.accentColor))
            
            Text("Join Our Community")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 15) {
                FeatureRow(icon: "person.3.fill", text: "Connect with other ZenFocus users")
                FeatureRow(icon: "lightbulb.fill", text: "Share ideas and productivity tips")
                FeatureRow(icon: "megaphone.fill", text: "Get early access to new features")
                FeatureRow(icon: "star.fill", text: "Help shape the future of ZenFocus")
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 15).fill(Color(.windowBackgroundColor)))
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            
            Button(action: {
                if let url = URL(string: "https://discord.gg/dRfRPREVhW") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                HStack {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("Join Discord Community")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            
            Text("Join our growing community of focused individuals!")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.top)
        }
        .padding()
    }
}

// Helper Views for Onboarding Pages
struct OnboardingPageView<Content: View>: View {
    let icon: String
    let title: String
    let color: Color
    let content: Content
    
    init(
        icon: String,
        title: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) {
        self.icon = icon
        self.title = title
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .foregroundColor(.white)
                .padding(20)
                .background(
                    Circle()
                        .fill(color)
                        .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
                )
            
            Text(title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            
            content
                .padding()
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(16)
    }
}

