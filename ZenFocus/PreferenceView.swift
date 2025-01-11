import SwiftUI
import CoreData
import Sparkle
import AppKit

struct PreferenceView: View {
    @EnvironmentObject var appDelegate: AppDelegate
    @EnvironmentObject var analyticsService: AnalyticsService
    @State private var selectedSection: PreferenceSection = .settings
    @State private var hoveredSection: PreferenceSection?
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var animation
    
    enum PreferenceSection: String, CaseIterable, Identifiable {
        case settings = "General"
        case about = "About"
        
        var id: String { self.rawValue }
        
        var icon: String {
            switch self {
            case .settings: return "gear"
            case .about: return "info.circle"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top navigation bar
            HStack {
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(colorScheme == .dark ? Color.black.opacity(0.6) : Color.white.opacity(0.8))
                        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 0)
                    
                    HStack(spacing: 15) {
                        ForEach(PreferenceSection.allCases) { section in
                            PreferenceTabButton(
                                title: section.rawValue,
                                systemImage: section.icon,
                                isSelected: selectedSection == section,
                                isHovered: hoveredSection == section,
                                namespace: animation
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedSection = section
                                }
                            }
                            .onHover { isHovered in
                                hoveredSection = isHovered ? section : nil
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
                .fixedSize(horizontal: true, vertical: false)
                .frame(height: 60)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            
            // Detail view
            ZStack {
                ForEach(PreferenceSection.allCases) { section in
                    if selectedSection == section {
                        detailView(for: section)
                            .transition(AnyTransition.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                removal: .opacity.combined(with: .scale(scale: 1.05))
                            ))
                            .animation(.easeInOut(duration: 0.2), value: selectedSection)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
        .navigationTitle("Preferences")
        .frame(minWidth: 600, minHeight: 400)
    }
    
    @ViewBuilder
    func detailView(for section: PreferenceSection) -> some View {
        switch section {
        case .settings:
            SettingsView()
        case .about:
            AboutView(updater: appDelegate.updaterController.updater)
        }
    }
}

struct PreferenceTabButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let isHovered: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundColor(isSelected ? .white : (isHovered ? .accentColor : .primary))
            .frame(height: 40)
            .padding(.horizontal, 16)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.accentColor)
                            .matchedGeometryEffect(id: "selectedBackground", in: namespace)
                            .shadow(color: Color.accentColor.opacity(0.5), radius: 5, x: 0, y: 2)
                    } else if isHovered {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                    }
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PreferenceView_Previews: PreviewProvider {
    static var previews: some View {
        PreferenceView()
            .environmentObject(AppDelegate())
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}

