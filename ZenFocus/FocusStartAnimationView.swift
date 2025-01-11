import SwiftUI
import AppKit

struct FocusStartAnimationView: View {
    @State private var opacity: Double = 0
    @State private var currentPrompt: String = ""
    @State private var promptOpacity: Double = 0
    let task: ZenFocusTask
    let completion: () -> Void
    
    let prompts = [
        ("Take a deep breath", 3.0),
        ("Close your eyes and visualize your goal", 8.0),
        ("Let's crush it!", 3.0)
    ]
    
    // Add stars
    @State private var stars: [Star] = (0..<50).map { _ in Star() }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Improved background
                RadialGradient(gradient: Gradient(colors: [Color(#colorLiteral(red: 0.1019607843, green: 0.07058823529, blue: 0.1490196078, alpha: 1)), Color(#colorLiteral(red: 0.05098039216, green: 0.03137254902, blue: 0.08235294118, alpha: 1))]),
                               center: .center,
                               startRadius: 100,
                               endRadius: 400)
                    .edgesIgnoringSafeArea(.all)
                
                // Floating stars
                ForEach(stars) { star in
                    Circle()
                        .fill(Color.white.opacity(star.opacity))
                        .frame(width: star.size, height: star.size)
                        .position(star.position)
                        .animation(Animation.linear(duration: star.animationDuration).repeatForever(autoreverses: false), value: star.position)
                }
                
                VStack(spacing: 30) {
                    Text("Time to Focus")
                        .font(.system(size: 60, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(task.title ?? "")
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Text(currentPrompt)
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .opacity(promptOpacity)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .edgesIgnoringSafeArea(.all)
        .opacity(opacity)
        .onAppear {
            animatePrompts()
            animateStars()
        }
    }
    
    private func animatePrompts() {
        withAnimation(.easeIn(duration: 1.0)) {
            opacity = 1
            currentPrompt = prompts[0].0
            promptOpacity = 1
        }
        
        var delay: Double = prompts[0].1 + 1.0
        for (index, prompt) in prompts.enumerated().dropFirst() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    self.promptOpacity = 0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.currentPrompt = prompt.0
                    withAnimation(.easeInOut(duration: 0.5)) {
                        self.promptOpacity = 1
                    }
                }
            }
            delay += prompt.1 + 0.5
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeOut(duration: 1.0)) {
                opacity = 0
                promptOpacity = 0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                completion()
            }
        }
    }
    
    private func animateStars() {
        guard let screen = NSScreen.main else { return }
        let screenSize = screen.frame.size
        
        for i in stars.indices {
            withAnimation(Animation.linear(duration: stars[i].animationDuration).repeatForever(autoreverses: false)) {
                stars[i].position = CGPoint(
                    x: CGFloat.random(in: 0...screenSize.width),
                    y: CGFloat.random(in: 0...screenSize.height)
                )
            }
        }
    }
}

struct Star: Identifiable {
    let id = UUID()
    var position: CGPoint
    let size: CGFloat
    let opacity: Double
    let animationDuration: Double
    
    init() {
        guard let screen = NSScreen.main else {
            position = .zero
            size = 1
            opacity = 0.1
            animationDuration = 10
            return
        }
        
        let screenSize = screen.frame.size
        position = CGPoint(
            x: CGFloat.random(in: 0...screenSize.width),
            y: CGFloat.random(in: 0...screenSize.height)
        )
        size = CGFloat.random(in: 1...3)
        opacity = Double.random(in: 0.1...0.7)
        animationDuration = Double.random(in: 10...30)
    }
}