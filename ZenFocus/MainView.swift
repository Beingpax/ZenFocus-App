import SwiftUI
import CoreData
import Sparkle
import AppKit

struct MainView: View {
    @ObservedObject private var categoryManager: CategoryManager
    @State private var selectedView: ViewType = .tasks
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @State private var userName: String = UserDefaults.standard.string(forKey: "userName") ?? "Pax"
    @State private var customCode: String = UserDefaults.standard.string(forKey: "customCode") ?? "Ready to get shit done?"
    @EnvironmentObject private var appDelegate: AppDelegate
    @StateObject private var windowManager = WindowManager()
    @State private var showingDailyPlan = false
    @State private var lastPlanDate: Date = UserDefaults.standard.object(forKey: "lastPlanDate") as? Date ?? Date.distantPast
    @State private var isDayPlanned: Bool = false
    @AppStorage("firstLaunchDate") private var firstLaunchDate: Double = Date().timeIntervalSince1970
    @AppStorage("launchCount") private var launchCount = 0
    @EnvironmentObject private var analyticsService: AnalyticsService

    enum ViewType: String, CaseIterable {
        case tasks = "Tasks"
        case kanbanBoard = "Day Plan"  
        case todayFocus = "Today's Focus"
        case progress = "Progress"
        case stats = "Stats"
        case history = "History"
        case music = "Music"
        case settings = "Settings"
        
        
        var icon: String {
            switch self {
            case .tasks: return "checklist"
            case .kanbanBoard: return "calendar"
            case .todayFocus: return "bolt.circle"
            case .progress: return "chart.bar.fill"
            case .stats: return "chart.pie.fill"
            case .history: return "clock.arrow.circlepath"
            case .music: return "music.note"
            case .settings: return "gear"
            
            }
        }
    }
    
    init(viewContext: NSManagedObjectContext) {
        self._categoryManager = ObservedObject(wrappedValue: CategoryManager(viewContext: viewContext))
    }
    
    @State private var hoveredView: ViewType?
    @State private var isExpanded = false
    @Namespace private var animation

    var body: some View {
        HStack(spacing: 0) {
            DynamicSidebar(selectedView: $selectedView, hoveredView: $hoveredView, isExpanded: $isExpanded)
            
            // Content
            ZStack {
                ForEach(ViewType.allCases, id: \.self) { viewType in
                    if selectedView == viewType {
                        content(for: viewType)
                            .transition(AnyTransition.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95).combined(with: .offset(x: 20, y: 0))),
                                removal: .opacity.combined(with: .scale(scale: 1.05).combined(with: .offset(x: -20, y: 0)))
                            ))
                            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: selectedView)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 950, minHeight: 600)
        .background(Color(NSColor.windowBackgroundColor))
        .environmentObject(windowManager)
    }
    
    @ViewBuilder
    func content(for viewType: ViewType) -> some View {
        switch viewType {
        case .tasks:
            TasksView(categoryManager: categoryManager,
                      showDailyPlan: $showingDailyPlan,
                      onPlanDay: { selectedView = .kanbanBoard },
                      onStartDay: {
                          withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                              selectedView = .todayFocus
                          }
                      })
                .environmentObject(windowManager)
        case .todayFocus:
            TodayFocusView(categoryManager: categoryManager, selectedView: $selectedView)
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(windowManager)
        case .progress:
            ProgressTrackerView(categoryManager: categoryManager)
        case .stats:
            StatsView(categoryManager: categoryManager)
        case .history:
            CompletedTasksHistoryView(categoryManager: categoryManager)
                .environmentObject(windowManager)
        case .music:
            MusicLibraryView()
                .environment(\.managedObjectContext, viewContext)
        case .settings:
            PreferenceView()
        case .kanbanBoard:
            KanbanBoardView(categoryManager: categoryManager, 
                            selectedView: $selectedView)
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(windowManager)
        }
    }

    private func handleError(_ error: Error, action: String) {
        ZenFocusLogger.shared.error("Error \(action): \(error.localizedDescription)")
        
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "An error occurred"
            alert.informativeText = "There was an error while \(action). Please try again or contact support if the problem persists."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}

struct DynamicSidebar: View {
    @Binding var selectedView: MainView.ViewType
    @Binding var hoveredView: MainView.ViewType?
    @Binding var isExpanded: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var buttonAnimation

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 20)
                .fill(colorScheme == .dark ? Color.black.opacity(0.6) : Color.white.opacity(0.8))
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 0)

            VStack(spacing: 15) {
                ForEach(MainView.ViewType.allCases, id: \.self) { viewType in
                    DynamicSidebarButton(
                        title: viewType.rawValue,
                        systemImage: viewType.icon,
                        isSelected: selectedView == viewType,
                        isHovered: hoveredView == viewType,
                        isExpanded: isExpanded,
                        namespace: buttonAnimation
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedView = viewType
                        }
                    }
                    .onHover { isHovered in
                        hoveredView = isHovered ? viewType : nil
                    }
                }
                Spacer()
                
                // Expand/collapse button
                DynamicSidebarButton(
                    title: isExpanded ? "Collapse" : "Expand",
                    systemImage: isExpanded ? "chevron.left" : "chevron.right",
                    isSelected: false,
                    isHovered: false,
                    isExpanded: isExpanded,
                    namespace: buttonAnimation
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded.toggle()
                    }
                }
            }
            .padding(.vertical, 20)
        }
        .frame(width: isExpanded ? 200 : 70)
        .padding(.leading, 10)
        .padding(.vertical, 10)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
    }
}

struct DynamicSidebarButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let isHovered: Bool
    let isExpanded: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 24, height: 24)
                
                if isExpanded {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                    Spacer()
                }
            }
            .foregroundColor(isSelected ? .white : (isHovered ? .accentColor : .primary))
            .frame(height: 40)
            .frame(maxWidth: .infinity, alignment: isExpanded ? .leading : .center)
            .padding(.leading, isExpanded ? 16 : 0)
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
            .padding(.horizontal, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
