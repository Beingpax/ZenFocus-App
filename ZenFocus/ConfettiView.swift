import SwiftUI

struct ConfettiView: View {
    @Binding var counter: Int
    let duration: Double = 6.0  // Increased from 4.0 to 6.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<200) { i in
                    ConfettiPiece(
                        counter: $counter,
                        index: i,
                        size: geometry.size,
                        duration: duration
                    )
                }
            }
        }
    }
}

struct ConfettiPiece: View {
    @Binding var counter: Int
    let index: Int
    let size: CGSize
    let duration: Double
    
    @State private var position: CGPoint
    @State private var rotation: Double
    @State private var scale: CGFloat
    @State private var opacity: Double
    
    private let shape: ConfettiShape
    private let color: Color
    private let speed: CGFloat
    private let angle: CGFloat
    
    init(counter: Binding<Int>, index: Int, size: CGSize, duration: Double) {
        self._counter = counter
        self.index = index
        self.size = size
        self.duration = duration
        
        self.shape = ConfettiShape.allCases.randomElement()!
        self.color = Color.confettiColor()
        
        // Start from bottom left corner
        let startX: CGFloat = CGFloat.random(in: 0...100)
        let startY: CGFloat = size.height - CGFloat.random(in: 0...100)
        self._position = State(initialValue: CGPoint(x: startX, y: startY))
        
        self._rotation = State(initialValue: Double.random(in: 0...360))
        self._scale = State(initialValue: CGFloat.random(in: 0.5...1.0))
        self._opacity = State(initialValue: 1.0)
        
        // Calculate initial velocity
        self.angle = CGFloat.random(in: -Double.pi/3...Double.pi/2)
        self.speed = CGFloat.random(in: size.height/4...size.height/2)  // Reduced speed range
    }
    
    var body: some View {
        shape.view
            .fill(color)
            .frame(width: 20, height: 20)  // Increased from 10x10 to 20x20
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .position(position)
            .opacity(opacity)
            .onAppear {
                animate()
            }
    }
    
    private func animate() {
        let animation = Animation.timingCurve(0.1, 0.8, 0.3, 1, duration: duration)
        
        withAnimation(animation) {
            let maxDistance = speed * CGFloat(duration)
            let endX = position.x + maxDistance * cos(angle)
            let endY = position.y - maxDistance * sin(angle)
            position = CGPoint(x: endX, y: endY)
            rotation += Double.random(in: 360...720)  // Reduced rotation range
            scale *= CGFloat.random(in: 0.5...0.8)  // Increased scale range
            opacity = 0
        }
    }
}

enum ConfettiShape: CaseIterable {
    case circle, triangle, square, squiggle

    var view: some Shape {
        switch self {
        case .circle:
            return AnyShape(Circle())
        case .triangle:
            return AnyShape(Triangle())
        case .square:
            return AnyShape(Rectangle())
        case .squiggle:
            return AnyShape(Squiggle())
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct Squiggle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control1: CGPoint(x: rect.width * 0.3, y: rect.minY),
            control2: CGPoint(x: rect.width * 0.7, y: rect.maxY)
        )
        return path
    }
}

struct AnyShape: Shape {
    private let path: (CGRect) -> Path
    
    init<S: Shape>(_ shape: S) {
        path = { rect in
            shape.path(in: rect)
        }
    }
    
    func path(in rect: CGRect) -> Path {
        path(rect)
    }
}

extension Color {
    static func confettiColor() -> Color {
        let colors: [Color] = [
            .red, .blue, .green, .yellow, .pink, .purple, .orange,
            Color(red: 1, green: 0.5, blue: 0),   // Orange
            Color(red: 0, green: 0.5, blue: 0.5), // Teal
            Color(red: 0.5, green: 0, blue: 0.5), // Purple
            Color(red: 1, green: 0.8, blue: 0),   // Gold
            Color(red: 0, green: 0.8, blue: 0.8)  // Cyan
        ]
        return colors.randomElement()!.opacity(Double.random(in: 0.7...1.0))
    }
}
