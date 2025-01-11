import SwiftUI
import AVFoundation
import CoreData

struct BreakTimerView: View {
    @Binding var breakTimeRemaining: Int
    @Binding var showBreakTimer: Bool
    let onStartNextTask: () -> Void
    let onDismissAll: () -> Void
    let viewContext: NSManagedObjectContext
    
    @State private var timer: Timer?
    @State private var showEndBreakAlert: Bool = false
    @State private var isBreakPaused: Bool = false
    @State private var isBreakCompleted: Bool = false
    
    @State private var initialBreakTime: Int
    @State private var progress: CGFloat = 0

    @Binding var dismissing: Bool

    @EnvironmentObject var windowManager: WindowManager
    
    @State private var errorMessage: String?
    @State private var audioPlayer: AVAudioPlayer?
    
    init(breakTimeRemaining: Binding<Int>, showBreakTimer: Binding<Bool>, onStartNextTask: @escaping () -> Void, onDismissAll: @escaping () -> Void, viewContext: NSManagedObjectContext, dismissing: Binding<Bool>) {
        self._breakTimeRemaining = breakTimeRemaining
        self._showBreakTimer = showBreakTimer
        self.onStartNextTask = onStartNextTask
        self.onDismissAll = onDismissAll
        self.viewContext = viewContext
        self._dismissing = dismissing
        self._initialBreakTime = State(initialValue: breakTimeRemaining.wrappedValue)
    }

    private let dos = [
        "Stretch your body",
        "Hydrate yourself",
        "Go out & take a walk",
        "Reflect on your progress",
        "Talk to someone you love"
    ]
    
    private let donts = [
        "Don't check social media",
        "Don't check mails",
        "Avoid Screen time",
        "Don't skip breaks",
        "Don't quit ZenFocus"
    ]

    private var nextTask: ZenFocusTask? {
        NextTaskManager.shared.getNextTask(context: viewContext)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dynamic Color Mesh background
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    .edgesIgnoringSafeArea(.all)
                    .overlay(
                        ZStack {
                            Color.black.opacity(0.7)
                            
                            // Top-left accent
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 300, height: 300)
                                .blur(radius: 100)
                                .offset(x: -100, y: -100)
                            
                            // Bottom-right accent
                            Circle()
                                .fill(Color.purple.opacity(0.15))
                                .frame(width: 300, height: 300)
                                .blur(radius: 100)
                                .offset(x: 100, y: 100)
                            
                            // Particles overlay
                            ForEach(0..<15) { _ in
                                ParticleView()
                            }
                        }
                    )
                
                VStack(spacing: 30) {
                    if isBreakCompleted {
                        breakCompletionView
                    } else {
                        breakTimerView(geometry: geometry)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .opacity(dismissing ? 0 : 1)
            .animation(.easeInOut(duration: 1.5), value: dismissing)
            .onAppear(perform: startBreakTimer)
            .alert(isPresented: $showEndBreakAlert) {
                if let errorMessage = errorMessage {
                    return Alert(
                        title: Text("Error"),
                        message: Text(errorMessage),
                        dismissButton: .default(Text("OK")) {
                            self.errorMessage = nil
                        }
                    )
                } else {
                    return Alert(
                        title: Text("End Break Early?"),
                        message: Text("Are you sure you want to end your break now?"),
                        primaryButton: .destructive(Text("Yes")) {
                            endBreak()
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
        }
    }
    
    private func breakTimerView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 30) {
            // Break Timer Title
            Text("Break Time")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 2)
            
            // Timer Display with enhanced styling
            Text(timeString(from: breakTimeRemaining))
                .font(.system(size: 120, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            .white,
                            .white.opacity(0.8)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .white.opacity(0.5), radius: 15)
                .padding(.bottom, 10)
                .overlay(
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.15),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 150
                            )
                        )
                        .frame(width: 250, height: 250)
                        .blur(radius: 20)
                        .offset(y: -20)
                        .blendMode(.overlay),
                    alignment: .center
                )
            
            // Progress bar
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 24)
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.orange, Color.red]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * 0.6 * progress, height: 24)
                    .animation(.linear(duration: 1), value: progress)
            }
            .frame(width: geometry.size.width * 0.6)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            
            // Timer Controls
            HStack(spacing: 20) {
                Button(action: {
                    breakTimeRemaining = max(breakTimeRemaining - 60, 60)
                    updateProgress()
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color.red)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    isBreakPaused.toggle()
                    if isBreakPaused {
                        timer?.invalidate()
                    } else {
                        startBreakTimer()
                    }
                }) {
                    Image(systemName: isBreakPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 24))
                        .foregroundColor(isBreakPaused ? Color.green : Color.orange)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    breakTimeRemaining = min(breakTimeRemaining + 60, 3600)
                    initialBreakTime = max(initialBreakTime, breakTimeRemaining)
                    updateProgress()
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color.green)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.top, 10)
            
            Text("Use this break time to recharge and refresh your mind.")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.bottom, 10)
            
            // Do's and Don'ts section with glass effect
            HStack(spacing: 50) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Do's")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(Color.green)
                    ForEach(dos, id: \.self) { item in
                        Text("• \(item)")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Don'ts")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(Color.red)
                    ForEach(donts, id: \.self) { item in
                        Text("• \(item)")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding()
            .background(GlassBackground())
            .frame(maxWidth: geometry.size.width * 0.8)
            
            if let nextTask = nextTask {
                nextTaskPreview(task: nextTask)
            }
            
            // End Break Button
            Button(action: {
                showEndBreakAlert = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text("End Break Early")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.95)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(Capsule())
                .shadow(color: .white.opacity(0.3), radius: 15)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .frame(minHeight: geometry.size.height)
        .padding(.vertical, 40)
        .padding(.horizontal, 40)
    }
    
    private var breakCompletionView: some View {
        VStack(spacing: 40) {
            // Completion Status Section with glowing effect
            ZStack {
                // Glowing background
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.green.opacity(0.15),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 100
                        )
                    )
                    .frame(width: 160, height: 160)
                    .blur(radius: 20)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .green.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .green.opacity(0.5), radius: 15)
            }
            
            VStack(spacing: 16) {
                Text("Break Complete!")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2)
                
                Text("Great job taking time to recharge.\nAre you fueled up for the next task?")
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.2), radius: 1)
            }
            
            if let nextTask = nextTask {
                nextTaskPreview(task: nextTask)
            }
            
            // Action Buttons
            HStack(spacing: 20) {
                Button(action: {
                    dismissAnimationView {
                        onDismissAll()
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Stop ZenFocus")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [
                                .white,
                                .white.opacity(0.95)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: .white.opacity(0.3), radius: 15)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                
                if nextTask != nil {
                    Button(action: {
                        dismissAnimationView {
                            onStartNextTask()
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Start Next Task")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [
                                    .white,
                                    .white.opacity(0.95)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: .white.opacity(0.3), radius: 15)
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
        .padding(.vertical, 50)
        .padding(.horizontal, 40)
    }
    
    private func startBreakTimer() {
        ZenFocusLogger.shared.info("Starting break timer with \(breakTimeRemaining) seconds remaining")
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if breakTimeRemaining > 0 {
                breakTimeRemaining -= 1
                updateProgress()
            } else {
                endBreak()
            }
        }
    }
    
    private func updateProgress() {
        do {
            guard initialBreakTime > 0 else {
                throw BreakTimerError.invalidInitialTime
            }
            progress = CGFloat(initialBreakTime - breakTimeRemaining) / CGFloat(initialBreakTime)
            ZenFocusLogger.shared.debug("Updated progress: \(progress)")
        } catch {
            handleError(error)
        }
    }
    
    private func endBreak() {
        ZenFocusLogger.shared.info("Ending break")
        timer?.invalidate()
        isBreakCompleted = true
        playBreakCompletionSound()
    }
    
    private func timeString(from seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    private func dismissAnimationView(completion: @escaping () -> Void) {
        ZenFocusLogger.shared.info("Dismissing animation view")
        dismissing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            do {
                try windowManager.closeTaskCompletionAnimationWindow()
                completion()
            } catch {
                handleError(error)
            }
        }
    }
    
    private func handleError(_ error: Error) {
        let errorMessage = "An error occurred: \(error.localizedDescription)"
        ZenFocusLogger.shared.error(errorMessage, error: error)
        self.errorMessage = errorMessage
        self.showEndBreakAlert = true
    }
    
    private func playBreakCompletionSound() {
        guard let soundURL = Bundle.main.url(forResource: "break_complete", withExtension: "mp3") else {
            ZenFocusLogger.shared.warning("Break completion sound file not found")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.play()
            ZenFocusLogger.shared.info("Break completion sound played successfully")
        } catch {
            ZenFocusLogger.shared.error("Error playing break completion sound", error: error)
        }
    }
}

enum BreakTimerError: Error {
    case invalidInitialTime
}

#if DEBUG
struct BreakTimerView_Previews: PreviewProvider {
    static var previews: some View {
        BreakTimerView(
            breakTimeRemaining: .constant(600),
            showBreakTimer: .constant(true),
            onStartNextTask: {},
            onDismissAll: {},
            viewContext: PersistenceController.preview.container.viewContext,
            dismissing: .constant(false)
        )
        .environmentObject(WindowManager())
        .frame(width: 800, height: 600)
        .previewLayout(.sizeThatFits)
    }
}

extension ZenFocusTask {
    static var example: ZenFocusTask {
        let task = ZenFocusTask(context: PersistenceController.preview.container.viewContext)
        task.title = "Complete project presentation"
        task.category = "Work"
        task.isCompleted = false
        return task
    }
}#endif

// Helper Views
private func controlButton(icon: String) -> some View {
    ZStack {
        Circle()
            .fill(Color.white.opacity(0.15))
            .frame(width: 60, height: 60)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
        
        Image(systemName: icon)
            .font(.system(size: 26))
            .foregroundStyle(
                LinearGradient(
                    colors: [.white, .white.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(color: .white.opacity(0.5), radius: 5)
    }
}

private func breakActionView(icon: String, text: String, color: Color) -> some View {
    VStack(spacing: 12) {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 60, height: 60)
                .overlay(
                    Circle()
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
            
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundStyle(color)
                .shadow(color: color.opacity(0.5), radius: 5)
        }
        
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white.opacity(0.9))
    }
}

// Helper functions for break actions
private func getIconForAction(_ index: Int) -> String {
    let icons = ["figure.walk.motion", "drop.fill", "sun.max.fill", 
                 "arrow.clockwise", "heart.fill"]
    return icons[index % icons.count]
}

private func getColorForAction(_ index: Int) -> Color {
    let colors: [Color] = [.pink, .blue, .orange, .green, .purple]
    return colors[index % colors.count]
}

// New helper function for timer control buttons
private func timerControlButton(icon: String, color: Color) -> some View {
    ZStack {
        Circle()
            .fill(color.opacity(0.15))
            .frame(width: 70, height: 70)
            .overlay(
                Circle()
                    .stroke(color.opacity(0.3), lineWidth: 1.5)
            )
            .shadow(color: color.opacity(0.5), radius: 10)
        
        Image(systemName: icon)
            .font(.system(size: 30, weight: .bold))
            .foregroundStyle(
                LinearGradient(
                    colors: [color, color.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(color: color.opacity(0.5), radius: 5)
    }
}

// Helper function for next task preview - will be used by both views
private func nextTaskPreview(task: ZenFocusTask) -> some View {
    HStack(spacing: 12) {
        Text("Up Next")
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white.opacity(0.7))
        
        Image(systemName: "arrow.right.circle.fill")
            .foregroundStyle(
                LinearGradient(
                    colors: [.orange, .yellow],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .font(.system(size: 20))
        
        Text(task.title ?? "")
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.white)
            .lineLimit(1)
    }
    .padding(.vertical, 12)
    .padding(.horizontal, 20)
    .background(GlassBackground())
    .frame(maxWidth: 600)
}


