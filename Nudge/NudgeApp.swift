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
                // Re-sync app language with iPhone system language (no-op if user overrode it)
                LanguageManager.shared.syncWithSystemLocale()
                Task {
                    await SubscriptionManager.shared.refreshCustomerInfo()
                    // Sync toggle with real OS permission (handles user disabling in iOS Settings)
                    let status = await NotificationManager.shared.authorizationStatus()
                    let osGranted = (status == .authorized || status == .provisional)
                    if notificationsEnabled && !osGranted {
                        notificationsEnabled = false
                    }
                    // Re-schedule if still enabled (picks up new language if it changed)
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

    @State private var showSplash = true

    private var reduceMotion: Bool { appReduceMotion || systemReduceMotion }

    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }

    var body: some View {
        ZStack {
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
            .environment(\.appReduceMotion, reduceMotion)
            .environment(\.appIncreaseContrast, appIncreaseContrast)
            .environment(\.legibilityWeight, appIncreaseContrast ? .bold : nil)
            .contrast(appIncreaseContrast ? 1.3 : 1.0)
            .animation(reduceMotion ? .none : .easeInOut(duration: 0.4), value: hasCompletedOnboarding)
            .preferredColorScheme(colorScheme)
            .transaction { transaction in
                if reduceMotion {
                    transaction.animation = .none
                }
            }

            // MARK: - Splash Screen
            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear {
            if reduceMotion {
                showSplash = false
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showSplash = false
                    }
                }
            }
        }
    }
}

// MARK: - Splash Screen

private struct SplashView: View {
    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var pulse = false

    var body: some View {
        ZStack {
            // Background gradient matching app accent
            Color.accentColor
                .ignoresSafeArea()

            // Subtle gradient overlay
            LinearGradient(
                colors: [Color.white.opacity(0.15), Color.clear, Color.black.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Decorative floating shapes
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 200, height: 200)
                .offset(x: -100, y: -200)
                .scaleEffect(pulse ? 1.1 : 0.9)

            Circle()
                .fill(Color.black.opacity(0.06))
                .frame(width: 150, height: 150)
                .offset(x: 120, y: 180)
                .scaleEffect(pulse ? 0.9 : 1.1)

            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.1))
                .frame(width: 70, height: 28)
                .rotationEffect(.degrees(-15))
                .offset(x: -110, y: 80)
                .scaleEffect(pulse ? 1.05 : 0.95)

            // Center content
            VStack(spacing: 20) {
                // App icon
                Image(systemName: "bolt.heart.fill")
                    .font(.system(size: 72, weight: .medium))
                    .foregroundColor(.white.opacity(0.95))
                    .shadow(color: Color.black.opacity(0.2), radius: 12, y: 6)
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity)

                // App name
                Text("NUDGE")
                    .font(.system(size: 34, weight: .black).width(.expanded))
                    .tracking(10)
                    .foregroundColor(.white)
                    .opacity(textOpacity)

                Text("Break through friction")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.7))
                    .opacity(textOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) {
                iconScale = 1.0
                iconOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                textOpacity = 1.0
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
