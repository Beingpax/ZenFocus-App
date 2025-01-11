import SwiftUI

struct BackgroundView: View {
    var body: some View {
        ZStack {
            Color.white.opacity(0.1)
            
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}