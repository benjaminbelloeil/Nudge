import SwiftUI

struct ContentView: View {
    @StateObject private var nudgeViewModel = NudgeViewModel()
    @StateObject private var historyViewModel = HistoryViewModel()
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var navigationPath = NavigationPath()
    @State private var showPaywall = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            DashboardView(navigationPath: $navigationPath)
                .environmentObject(historyViewModel)
                .navigationDestination(for: NavigationDestination.self) { destination in
                    switch destination {
                    case .newNudge:
                        NudgeFlowContainer(
                            viewModel: nudgeViewModel,
                            onDismiss: { navigationPath = NavigationPath() }
                        )
                    case .history:
                        HistoryView(viewModel: historyViewModel, navigationPath: $navigationPath)
                    case .insights:
                        StatsView(viewModel: historyViewModel)
                    case .nudgeDetail(let id):
                        NudgeDetailView(viewModel: historyViewModel, entryId: id)
                    case .paywall:
                        NudgePaywallView()
                    case .customerCenter:
                        CustomerCenterView()
                    }
                }
        }
        .sheet(isPresented: $showPaywall) {
            NudgePaywallView()
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
        .navigationBarBackButtonHidden(viewModel.currentResult != nil || viewModel.isGenerating || viewModel.isManualMode)
        .background(AppColors.background)
    }
}

// MARK: - Skeleton Loading (Rich Animated)

private struct SkeletonResultView: View {
    @State private var pulse = false
    @State private var wave = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Fake header (badge + title)
                    VStack(alignment: .leading, spacing: 10) {
                        SkeletonBlock(height: 22, width: 110)
                        SkeletonBlock(height: 26, width: 200)
                        SkeletonBlock(height: 14, width: 160)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 16)

                    // Fake progress bar
                    VStack(spacing: 6) {
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                                .overlay(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(Color.accentColor.opacity(wave ? 0.3 : 0.1))
                                        .frame(width: geo.size.width * (wave ? 0.6 : 0.2))
                                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: wave)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }
                        .frame(height: 6)
                        HStack {
                            SkeletonBlock(height: 10, width: 80)
                            Spacer()
                            SkeletonBlock(height: 10, width: 28)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                    // Fake steps card
                    VStack(spacing: 0) {
                        // Steps header
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color.accentColor.opacity(0.08))
                                .frame(width: 32, height: 32)
                                .modifier(ShimmerModifier())
                            SkeletonBlock(height: 16, width: 50)
                            Spacer()
                            SkeletonBlock(height: 16, width: 36)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)

                        // Timeline steps
                        ForEach(0..<4, id: \.self) { index in
                            HStack(alignment: .top, spacing: 14) {
                                VStack(spacing: 0) {
                                    Circle()
                                        .fill(Color.white.opacity(0.04))
                                        .frame(width: 34, height: 34)
                                        .modifier(ShimmerModifier())

                                    if index < 3 {
                                        Rectangle()
                                            .fill(Color.white.opacity(0.04))
                                            .frame(width: 2, height: 36)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    SkeletonBlock(height: 16, width: CGFloat(90 + index * 30))
                                    SkeletonBlock(height: 13)
                                    if index == 1 || index == 2 {
                                        SkeletonBlock(height: 13, width: CGFloat(180 - index * 20))
                                    }
                                }
                                .padding(.bottom, 16)
                            }
                            .opacity(pulse ? 1 : 0.6)
                            .animation(
                                .easeInOut(duration: 1.4)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.2),
                                value: pulse
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                    }
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                    // Fake goal card
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color.green.opacity(0.06))
                            .frame(width: 32, height: 32)
                            .modifier(ShimmerModifier())
                        SkeletonBlock(height: 16, width: 80)
                        Spacer()
                        SkeletonBlock(height: 12, width: 16)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal, 20)
                }
            }

            // Fake bottom buttons
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.accentColor.opacity(pulse ? 0.25 : 0.12))
                    .frame(height: 52)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
                SkeletonBlock(height: 14, width: 90)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .background(AppColors.background)
        }
        .background(AppColors.background.ignoresSafeArea())
        .onAppear {
            pulse = true
            wave = true
        }
    }
}
