import SwiftUI

struct ContentView: View {
    @StateObject private var nudgeViewModel = NudgeViewModel()
    @StateObject private var historyViewModel = HistoryViewModel()
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var languageManager: LanguageManager
    @State private var navigationPath = NavigationPath()
    @State private var showPaywall = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            DashboardView(navigationPath: $navigationPath)
                .environmentObject(historyViewModel)
                .environmentObject(languageManager)
                .navigationDestination(for: NavigationDestination.self) { destination in
                    switch destination {
                    case .newNudge:
                        NudgeFlowContainer(
                            viewModel: nudgeViewModel,
                            onDismiss: { navigationPath = NavigationPath() }
                        )
                        .environmentObject(languageManager)
                        .environmentObject(subscriptionManager)
                    case .history:
                        HistoryView(viewModel: historyViewModel, navigationPath: $navigationPath)
                            .environmentObject(languageManager)
                    case .insights:
                        StatsView(viewModel: historyViewModel)
                            .environmentObject(languageManager)
                            .environmentObject(subscriptionManager)
                    case .nudgeDetail(let id):
                        NudgeDetailView(viewModel: historyViewModel, entryId: id)
                            .environmentObject(languageManager)
                    case .paywall:
                        NudgePaywallView()
                            .environmentObject(subscriptionManager)
                            .environmentObject(languageManager)
                    case .customerCenter:
                        CustomerCenterView()
                            .environmentObject(languageManager)
                            .environmentObject(subscriptionManager)
                    case .settings:
                        SettingsView()
                            .environmentObject(historyViewModel)
                            .environmentObject(languageManager)
                    }
                }
        }
        .sheet(isPresented: $showPaywall) {
            NudgePaywallView()
                .environmentObject(subscriptionManager)
                .environmentObject(languageManager)
        }
    }
}

// MARK: - Nudge Flow Container

private struct NudgeFlowContainer: View {
    @ObservedObject var viewModel: NudgeViewModel
    let onDismiss: () -> Void

    var body: some View {
        Group {
            if viewModel.isManualMode {
                ManualMissionsView(viewModel: viewModel)
            } else if viewModel.isGenerating {
                SkeletonResultView()
            } else if viewModel.currentResult != nil {
                NudgeResultView(
                    result: viewModel.currentResult!,
                    source: viewModel.currentSource,
                    viewModel: viewModel,
                    onDismiss: {
                        viewModel.reset()
                        onDismiss()
                    }
                )
            } else {
                InputFlowView(viewModel: viewModel)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.currentResult != nil || viewModel.isGenerating || viewModel.isManualMode || viewModel.currentStep != .task)
        .background(AppColors.background)
    }
}

// MARK: - Skeleton Loading (Rich Animated)

private struct SkeletonResultView: View {
    @State private var appeared = false
    @State private var wave = false
    @State private var dotCount = 0
    @Environment(\.appReduceMotion) private var reduceMotion

    private let stepWidths: [(title: CGFloat, action: CGFloat, extra: CGFloat?)] = [
        (120, .infinity, nil),
        (100, .infinity, 180),
        (140, .infinity, nil),
        (110, .infinity, 160),
        (130, .infinity, nil),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    headerSkeleton
                    progressSkeleton
                    stepsCardSkeleton
                    goalCardSkeleton
                    Spacer().frame(height: 24)
                }
            }

            bottomButtonSkeleton
        }
        .background(AppColors.background.ignoresSafeArea())
        .onAppear {
            if !reduceMotion {
                appeared = true
                wave = true
                startDotTimer()
            } else {
                appeared = true
            }
        }
    }

    // MARK: - Generating Status

    private func startDotTimer() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                dotCount = (dotCount + 1) % 4
            }
        }
    }

    private var generatingText: String {
        let base = LanguageManager.shared["skeleton.generating"]
        return base + String(repeating: ".", count: dotCount)
    }

    // MARK: - Header

    private var headerSkeleton: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Friction badge capsule (matches FrictionBadge shape)
            SkeletonPill(width: 90, height: 26)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)

            // "Action Plan" title
            SkeletonBlock(height: 24, width: 155)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)

            // Task description
            SkeletonBlock(height: 14, width: 220)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .animation(reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.8).delay(0.05), value: appeared)
    }

    // MARK: - Progress

    private var progressSkeleton: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.accentColor.opacity(0.10))

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.4), Color.accentColor.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * (wave ? 0.55 : 0.15))
                        .animation(reduceMotion ? .none : .easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: wave)
                }
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
            .frame(height: 5)

            HStack {
                Text(generatingText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                SkeletonBlock(height: 10, width: 28)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .opacity(appeared ? 1 : 0)
        .animation(reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: appeared)
    }

    // MARK: - Steps Card

    private var stepsCardSkeleton: some View {
        VStack(spacing: 0) {
            // Card header (matches stepsSection header exactly)
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: "list.number")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor.opacity(0.4))
                }

                SkeletonBlock(height: 16, width: 52)

                Spacer()

                // Capsule badge skeleton
                SkeletonPill(width: 42, height: 22)

                Image(systemName: "chevron.down")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)

            // Timeline steps (5 steps like actual result)
            ForEach(0..<5, id: \.self) { index in
                HStack(alignment: .top, spacing: 14) {
                    // Timeline column
                    VStack(spacing: 0) {
                        ZStack {
                            Circle()
                                .fill(Color.secondary.opacity(0.08))
                                .frame(width: 34, height: 34)

                            Circle()
                                .strokeBorder(Color.secondary.opacity(0.08), lineWidth: 1.5)
                                .frame(width: 34, height: 34)

                            SkeletonBlock(height: 12, width: 12)
                        }

                        if index < 4 {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.08))
                                .frame(width: 2)
                                .frame(maxHeight: .infinity)
                        }
                    }

                    // Content column
                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonBlock(height: 16, width: stepWidths[index].title)
                        SkeletonBlock(height: 13)
                        if let extra = stepWidths[index].extra {
                            SkeletonBlock(height: 13, width: extra)
                        }
                    }
                    .padding(.bottom, 20)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(
                    reduceMotion ? .none :
                        .spring(response: 0.6, dampingFraction: 0.8)
                        .delay(0.15 + Double(index) * 0.06),
                    value: appeared
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    // MARK: - Goal Card

    private var goalCardSkeleton: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: "flag.fill")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.green.opacity(0.4))
            }

            SkeletonBlock(height: 16, width: 44)

            Spacer()

            Image(systemName: "chevron.down")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 20)
        .opacity(appeared ? 1 : 0)
        .animation(reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: appeared)
    }

    // MARK: - Bottom Button

    private var bottomButtonSkeleton: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.accentColor.opacity(wave ? 0.22 : 0.10))
                .frame(height: 52)
                .overlay(
                    SkeletonBlock(height: 16, width: 100)
                )
                .animation(reduceMotion ? .none : .easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: wave)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .background(AppColors.background)
    }
}

// MARK: - Skeleton Pill (capsule-shaped placeholder)

private struct SkeletonPill: View {
    var width: CGFloat
    var height: CGFloat = 26

    var body: some View {
        Capsule(style: .continuous)
            .fill(Color.secondary.opacity(0.08))
            .frame(width: width, height: height)
            .modifier(ShimmerModifier())
    }
}
