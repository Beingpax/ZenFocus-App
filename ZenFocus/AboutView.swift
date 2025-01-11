import SwiftUI
import Sparkle
import Foundation

struct AboutView: View {
    let updater: SPUUpdater
    @AppStorage("launchCount") private var launchCount = 0
    @AppStorage("firstLaunchDate") private var firstLaunchDate: Double = Date().timeIntervalSince1970
    @EnvironmentObject private var analyticsService: AnalyticsService

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                appHeader
                appDescription
                versionInfo
                actionButtons
                discordSection
                Spacer()
            }
            .padding()
        }
        .padding()
        .frame(maxWidth: 700, maxHeight: .infinity)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    var appHeader: some View {
        HStack(spacing: 20) {
            Image("AppIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .cornerRadius(16)
                .shadow(color: .gray.opacity(0.3), radius: 5, x: 0, y: 2)
            
            VStack(alignment: .leading, spacing: 5) {
                Text("ZenFocus")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Your Productivity Companion")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
    
    var appDescription: some View {
        Text("ZenFocus is your ultimate productivity companion, designed to help you achieve deep focus and accomplish your tasks with ease.")
            .font(.body)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
            .frame(maxWidth: 400)
    }
    
    var versionInfo: some View {
        HStack {
            Text("Version \(Bundle.main.appVersionLong)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button("Changelog") {
                openChangelog()
            }
            .buttonStyle(LinkButtonStyle())
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    var actionButtons: some View {
        HStack(spacing: 20) {
            Button(action: { updater.checkForUpdates() }) {
                Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    var discordSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                Text("Join Our Community")
                    .font(.headline)
                Spacer()
            }
            
            Text("Connect with other ZenFocus users, share ideas, and help shape the future of the app.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Button(action: {
                if let url = URL(string: "https://discord.gg/dRfRPREVhW") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                HStack {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("Join Discord")
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue)
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private func openChangelog() {
        if let url = URL(string: "https://zenfocus.featurebase.app/changelog") {
            NSWorkspace.shared.open(url)
        }
    }
    
}

struct LinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.blue)
            .underline(configuration.isPressed)
    }
}

extension Bundle {
    var appVersionLong: String {
        return "\(appVersionShort) (\(buildNumber))"
    }
    
    var appVersionShort: String {
        return infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    var buildNumber: String {
        return infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView(updater: SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil).updater)
    }
}
