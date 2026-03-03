import SwiftUI
import RevenueCat

struct CustomerCenterView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    @State private var isRestoring = false
    @State private var alertMessage: String? = nil
    @State private var showPaywall = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                statusCard
                subscriptionDetails
                actionsSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Subscription")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Info", isPresented: .init(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK") { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
        .sheet(isPresented: $showPaywall) {
            NudgePaywallView()
        }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: subscriptionManager.isProUser
                                ? [.orange, .yellow]
                                : [Color.secondary.opacity(0.3), Color.secondary.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)

                Image(systemName: subscriptionManager.isProUser ? "crown.fill" : "person.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }

            VStack(spacing: 4) {
                Text(subscriptionManager.isProUser ? "Nudge Pro" : "Free Plan")
                    .font(.title3)
                    .fontWeight(.bold)

                Text(subscriptionManager.isProUser ? "You have full access" : "\(SubscriptionManager.freeNudgesPerWeek) nudges per week")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Subscription Details

    @ViewBuilder
    private var subscriptionDetails: some View {
        if let info = subscriptionManager.customerInfo,
           let entitlement = info.entitlements[SubscriptionManager.entitlementID],
           entitlement.isActive {

            VStack(alignment: .leading, spacing: 14) {
                Text("DETAILS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .tracking(1.2)

                DetailRow(label: "Plan", value: entitlement.productIdentifier.capitalized)
                
                if let expirationDate = entitlement.expirationDate {
                    DetailRow(label: "Renews", value: expirationDate.formatted(date: .abbreviated, time: .omitted))
                }

                if let managementURL = info.managementURL {
                    Link(destination: managementURL) {
                        HStack {
                            Text("Manage in Settings")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                        .foregroundColor(.accentColor)
                        .padding(.top, 4)
                    }
                }
            }
            .padding(18)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 12) {
            if !subscriptionManager.isProUser {
                Button {
                    showPaywall = true
                } label: {
                    HStack {
                        Image(systemName: "bolt.heart.fill")
                            .foregroundColor(.white)
                        Text("Upgrade to Pro")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.accentColor)
                    )
                }
                .buttonStyle(.plain)
            }

            Button {
                restorePurchases()
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(.primary)
                    Text("Restore Purchases")
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Spacer()
                    if isRestoring {
                        ProgressView()
                            .tint(.secondary)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(16)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isRestoring)
        }
    }

    // MARK: - Helpers

    private func restorePurchases() {
        isRestoring = true
        Task {
            do {
                try await subscriptionManager.restorePurchases()
                isRestoring = false
                if subscriptionManager.isProUser {
                    alertMessage = "Your Pro subscription has been restored!"
                } else {
                    alertMessage = "No active subscription found."
                }
            } catch {
                isRestoring = false
                alertMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Detail Row

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}
