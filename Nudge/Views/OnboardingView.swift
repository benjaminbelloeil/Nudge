import SwiftUI

struct OnboardingView: View {
    var onComplete: () -> Void
    @State private var currentPage = 0

    private let totalPages = 3

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Top Bar
                HStack(alignment: .center, spacing: 12) {
                    Button {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            currentPage -= 1
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    .opacity(currentPage > 0 ? 1 : 0)
                    .disabled(currentPage == 0)
                    .animation(.easeInOut(duration: 0.25), value: currentPage)

                    // Progress bars
                    HStack(spacing: 4) {
                        ForEach(0..<totalPages, id: \.self) { index in
                            GeometryReader { geo in
                                Capsule()
                                    .fill(Color.primary.opacity(0.15))
                                    .overlay(alignment: .leading) {
                                        Capsule()
                                            .fill(Color.primary)
                                            .frame(width: index <= currentPage ? geo.size.width : 0)
                                    }
                                    .clipShape(Capsule())
                            }
                            .frame(height: 3)
                        }
                    }
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: currentPage)

                    Button {
                        onComplete()
                    } label: {
                        Text("Skip")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)

                // MARK: - Swipeable Pages
                TabView(selection: $currentPage) {
                    OnboardingPage(
                        accentColor: Color.accentColor,
                        secondaryColor: Color(red: 0.55, green: 0.35, blue: 0.95),
                        iconMain: "bolt.heart.fill",
                        iconDecorations: ["sparkle", "brain.head.profile", "lightbulb.fill"],
                        title: "It's Not Laziness",
                        subtitle: "It's friction. And we'll break through it.",
                        description: "Procrastination is your brain protecting you from overwhelm. Nudge gives you the smallest possible first step."
                    )
                    .tag(0)

                    OnboardingPage(
                        accentColor: Color(red: 0.20, green: 0.55, blue: 0.95),
                        secondaryColor: Color(red: 0.35, green: 0.80, blue: 0.55),
                        iconMain: "timer",
                        iconDecorations: ["flame.fill", "arrow.up.right", "checkmark.circle"],
                        title: "Two Minutes Is Enough",
                        subtitle: "Then momentum does the rest.",
                        description: "A tiny start removes the hardest part: beginning. Progressive steps build real momentum without pressure."
                    )
                    .tag(1)

                    OnboardingPage(
                        accentColor: Color(red: 0.95, green: 0.65, blue: 0.25),
                        secondaryColor: Color(red: 0.90, green: 0.40, blue: 0.30),
                        iconMain: "chart.line.uptrend.xyaxis",
                        iconDecorations: ["flame", "star.fill", "trophy.fill"],
                        title: "Track Your Progress",
                        subtitle: "See patterns. Build streaks.",
                        description: "Track moods, energy, and friction over time. Watch your streaks build and learn what works for you."
                    )
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // MARK: - Bottom Button (at very bottom with safe area)
                Button(action: {
                    if currentPage < totalPages - 1 {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            currentPage += 1
                        }
                    } else {
                        // Request notification permission in context before entering the app
                        Task {
                            let granted = await NotificationManager.shared.requestPermission()
                            if granted {
                                UserDefaults.standard.set(true, forKey: "notificationsEnabled")
                                await NotificationManager.shared.scheduleAll()
                            }
                        }
                        onComplete()
                    }
                }) {
                    Text(buttonLabel)
                        .font(.headline)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.primary)
                        .foregroundColor(Color(UIColor.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .animation(.none, value: currentPage)
            }
        }
    }

    private var buttonLabel: String {
        switch currentPage {
        case 0: return "Let's Begin"
        case 1: return "Continue"
        default: return "Get Started"
        }
    }
}

// MARK: - Onboarding Page

private struct OnboardingPage: View {
    let accentColor: Color
    let secondaryColor: Color
    let iconMain: String
    let iconDecorations: [String]
    let title: String
    let subtitle: String
    let description: String

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Illustration Area (solid colored card like New Nudge button)
            ZStack {
                // Main solid-colored card
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(accentColor)
                    .padding(.horizontal, 20)

                // Subtle gradient overlay for depth
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.1), Color.clear, Color.black.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(.horizontal, 20)

                // Decorative circles (darker/lighter tints of the accent)
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 160, height: 160)
                    .offset(x: -80, y: -50)
                    .scaleEffect(appeared ? 1 : 0.5)

                Circle()
                    .fill(Color.black.opacity(0.06))
                    .frame(width: 120, height: 120)
                    .offset(x: 90, y: 50)
                    .scaleEffect(appeared ? 1 : 0.5)

                // Small accent pill shapes
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 60, height: 24)
                    .rotationEffect(.degrees(-15))
                    .offset(x: -100, y: 40)
                    .scaleEffect(appeared ? 1 : 0)

                RoundedRectangle(cornerRadius: 8)
                    .fill(secondaryColor.opacity(0.3))
                    .frame(width: 44, height: 20)
                    .rotationEffect(.degrees(10))
                    .offset(x: 105, y: -55)
                    .scaleEffect(appeared ? 1 : 0)

                // Decoration icons floating around
                ForEach(Array(iconDecorations.enumerated()), id: \.offset) { index, icon in
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.35))
                        .offset(
                            x: decorationOffset(index: index).x,
                            y: decorationOffset(index: index).y
                        )
                        .scaleEffect(appeared ? 1 : 0.3)
                        .opacity(appeared ? 1 : 0)
                }

                // Main icon (white on colored bg, like the + on New Nudge)
                Image(systemName: iconMain)
                    .font(.system(size: 64, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: Color.black.opacity(0.15), radius: 8, y: 4)
                    .scaleEffect(appeared ? 1 : 0.4)
                    .opacity(appeared ? 1 : 0)
            }
            .frame(height: 230)
            .padding(.top, 4)

            Spacer().frame(height: 32)

            // MARK: - Text Content
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(size: 30, weight: .bold))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 14)

                Text(subtitle)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(accentColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)

            Spacer()
        }
        .onAppear {
            appeared = false
            withAnimation(.spring(response: 0.8, dampingFraction: 0.75).delay(0.05)) {
                appeared = true
            }
        }
        .onDisappear {
            appeared = false
        }
    }

    private func decorationOffset(index: Int) -> CGPoint {
        let offsets: [CGPoint] = [
            CGPoint(x: -90, y: -50),
            CGPoint(x: 100, y: -25),
            CGPoint(x: -50, y: 60)
        ]
        return index < offsets.count ? offsets[index] : .zero
    }
}
