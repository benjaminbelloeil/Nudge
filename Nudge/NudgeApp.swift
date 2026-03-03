//
//  NudgeApp.swift
//  Nudge
//
//  Created by Benjamin Belloeil on 3/3/26.
//
import SwiftUI

@main
struct NudgeApp: App {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        SubscriptionManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(subscriptionManager)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await SubscriptionManager.shared.refreshCustomerInfo() }
            }
        }
    }
}

struct AppRootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @EnvironmentObject var subscriptionManager: SubscriptionManager

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                ContentView()
            } else {
                OnboardingView(onComplete: {
                    hasCompletedOnboarding = true
                })
            }
        }
        .animation(.easeInOut(duration: 0.4), value: hasCompletedOnboarding)
    }
}
