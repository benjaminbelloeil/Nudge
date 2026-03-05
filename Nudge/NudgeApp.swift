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
    @StateObject private var languageManager = LanguageManager.shared
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("notificationsEnabled") private var notificationsEnabled = false

    init() {
        SubscriptionManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(subscriptionManager)
                .environmentObject(languageManager)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await SubscriptionManager.shared.refreshCustomerInfo()
                    // Sync toggle with real OS permission (handles user disabling in iOS Settings)
                    let status = await NotificationManager.shared.authorizationStatus()
                    let osGranted = (status == .authorized || status == .provisional)
                    if notificationsEnabled && !osGranted {
                        notificationsEnabled = false
                    }
                    // Re-schedule if still enabled
                    if notificationsEnabled {
                        await NotificationManager.shared.scheduleAll()
                    }
                }
            }
        }
    }
}

struct AppRootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("appearanceMode") private var appearanceMode = 0
    @AppStorage("largeText") private var largeText = false

    // In-app accessibility overrides
    @AppStorage("acc_reduceMotion") private var appReduceMotion = false
    @AppStorage("acc_increaseContrast") private var appIncreaseContrast = false

    // Read system reduce-motion so we can OR it (never disable what the OS already enables)
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var languageManager: LanguageManager

    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }

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
        .environment(\.sizeCategory, largeText ? .extraExtraLarge : .large)
        .environment(\.appReduceMotion, appReduceMotion || systemReduceMotion)
        .environment(\.appIncreaseContrast, appIncreaseContrast)
        .environment(\.legibilityWeight, appIncreaseContrast ? .bold : nil)
        .contrast(appIncreaseContrast ? 1.3 : 1.0)
        .animation(.easeInOut(duration: 0.4), value: hasCompletedOnboarding)
        .preferredColorScheme(colorScheme)
    }
}
