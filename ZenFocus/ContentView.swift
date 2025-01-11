//
//  ContentView.swift
//  ZenFocus
//
//  Created by Prakash Joshi on 04/09/2024.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var windowManager = WindowManager()

    var body: some View {
        Group {
            if !appState.hasCompletedOnboarding {
                OnboardingView()
                    .edgesIgnoringSafeArea(.all)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                MainView(viewContext: viewContext)
            }
        }
        .environmentObject(windowManager)
        .environment(\.managedObjectContext, viewContext)
    }
}