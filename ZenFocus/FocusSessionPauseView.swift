import SwiftUI

struct BreakAction: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
    let color: Color
}

struct GlassBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(Color.white.opacity(0.1))
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .blur(radius: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 10)
    }
}

struct FocusSessionPauseView: View {
    @Binding var dismissing: Bool
    let onResume: () -> Void
    let onHide: () -> Void
    @State private var isAnimating = false
    @State private var showingDeviceAccessAlert = false
    
    private let breakActions = [
        BreakAction(icon: "figure.walk.motion", text: "Stretch", color: Color.pink),
        BreakAction(icon: "cup.and.saucer.fill", text: "Hydrate", color: Color.blue),
        BreakAction(icon: "sun.max.fill", text: "Sunlight", color: Color.orange),
        BreakAction(icon: "figure.walk", text: "Walk", color: Color.green),
        BreakAction(icon: "lungs.fill", text: "Breathe", color: Color.purple),
        BreakAction(icon: "heart.fill", text: "Connect", color: Color.red)
    ]
    
    private let pauseMessages = [
        "Take a mindful pause to recharge your focus",
        "Step back, breathe, and reset your mind",
        "Use this moment to center yourself",
        "A brief pause can lead to better focus",
        "Take this time to refresh your energy",
        "Mindful breaks lead to better productivity",
        "Reset your mind for enhanced focus",
        "Use this pause to realign your focus"
    ]
    
    @State private var selectedMessage: String = ""
    
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
                
                // Main Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 60) {
                        // Pause Status Section
                        pauseStatusSection
                        
                        // System Notice with Glass Effect
                        systemNoticeSection
                        
                        // Break Actions Grid
                        breakActionsSection
                        
                        // Resume Button
                        resumeButton
                    }
                    .padding(.vertical, 50)
                    .padding(.horizontal, 40)
                }
            }
        }
        .onAppear {
            withAnimation {
                isAnimating = true
                selectedMessage = pauseMessages.randomElement() ?? pauseMessages[0]
            }
        }
    }
    
    // MARK: - View Components
    
    private var pauseStatusSection: some View {
        VStack(spacing: 40) {
            // Simplified and enhanced pause icon
            ZStack {
                // Glowing background
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 100
                        )
                    )
                    .frame(width: 160, height: 160)
                    .blur(radius: 20)
                
                // Main pause icon
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 120, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
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
                    .shadow(color: .white.opacity(0.5), radius: 15, x: 0, y: 0)
                    .shadow(color: .white.opacity(0.2), radius: 30, x: 0, y: 0)
            }
            
            VStack(spacing: 16) {
                Text("Focus Session Paused")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2)
                
                Text(selectedMessage)
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.2), radius: 1)
            }
        }
    }
    
    private var systemNoticeSection: some View {
        VStack {
            HStack(spacing: 20) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .yellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .orange.opacity(0.5), radius: 12)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("System Access Limited")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("To help maintain your focus, access to other apps and notifications is temporarily restricted")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 24)
            .background(
                GlassBackground()
            )
        }
        .frame(maxWidth: 600)
    }
    
    private var breakActionsSection: some View {
        VStack(spacing: 35) {
            Text("WHILE YOU'RE HERE")
                .font(.system(size: 16, weight: .bold))
                .tracking(3)
                .foregroundColor(.white.opacity(0.7))
            
            HStack(spacing: 40) {
                ForEach(breakActions, id: \.text) { action in
                    breakActionView(action: action)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 40)
        }
    }
    
    private func breakActionView(action: BreakAction) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(action.color.opacity(0.15))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .stroke(
                                action.color.opacity(0.3),
                                lineWidth: 1
                            )
                    )
                
                Image(systemName: action.icon)
                    .font(.system(size: 26))
                    .foregroundStyle(action.color)
                    .shadow(color: action.color.opacity(0.5), radius: 5)
            }
            
            Text(action.text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
        }
    }
    
    private var resumeButton: some View {
        VStack(spacing: 16) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    dismissing = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onResume()
                    }
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Resume Focus")
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
            .keyboardShortcut(.defaultAction)
            
            Text("Let me use my device please...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .padding(.top, 8)
                .onTapGesture {
                    showingDeviceAccessAlert = true
                }
        }
        .alert(isPresented: $showingDeviceAccessAlert) {
            Alert(
                title: Text("Use Your Device"),
                message: Text("Break time is for recharging your focus. Are you sure you want to hide the this screen and use your device for something else?"),
                primaryButton: .default(Text("You're Right")) {
                    showingDeviceAccessAlert = false
                },
                secondaryButton: .destructive(Text("It's Important")) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        dismissing = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onHide()
                        }
                    }
                }
            )
        }
    }
}

// MARK: - Supporting Views and Styles

struct ParticleView: View {
    @State private var position = CGPoint(
        x: CGFloat.random(in: 0...1),
        y: CGFloat.random(in: 0...1)
    )
    
    var body: some View {
        GeometryReader { geometry in
            Circle()
                .fill(.white.opacity(0.1))
                .frame(width: CGFloat.random(in: 2...4))
                .position(
                    x: geometry.size.width * position.x,
                    y: geometry.size.height * position.y
                )
                .onAppear {
                    withAnimation(
                        Animation
                            .linear(duration: Double.random(in: 10...20))
                            .repeatForever(autoreverses: false)
                    ) {
                        position = CGPoint(
                            x: CGFloat.random(in: 0...1),
                            y: CGFloat.random(in: 0...1)
                        )
                    }
                }
        }
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#if DEBUG
struct FocusSessionPauseView_Previews: PreviewProvider {
    static var previews: some View {
        FocusSessionPauseView(
            dismissing: .constant(false),
            onResume: {},
            onHide: {}
        )
    }
}
#endif 
