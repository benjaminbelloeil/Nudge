import SwiftUI
import RevenueCat

struct CustomerCenterView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    @State private var isRestoring = false
    @State private var alertMessage: String? = nil
    @State private var showPaywall = false
    @State private var appeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                heroCard
                if subscriptionManager.isProUser {
                    planDetailsCard
                }
                actionsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Subscription")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.05)) {
                appeared = true
            }
        }
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

    // MARK: - Hero Card

    private var heroCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    subscriptionManager.isProUser
                        ? LinearGradient(
                            colors: [Color(red: 0.55, green: 0.35, blue: 0.95), Color(red: 0.35, green: 0.20, blue: 0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                          )
                        : LinearGradient(
                            colors: [Color.secondary.opacity(0.25), Color.secondary.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                          )
                )

            // Background decoration circles
            Circle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 130, height: 130)
                .offset(x: -90, y: -30)
                .scaleEffect(appeared ? 1 : 0.4)

            Circle()
                .fill(Color.black.opacity(0.08))
                .frame(width: 100, height: 100)
                .offset(x: 100, y: 40)
                .scaleEffect(appeared ? 1 : 0.4)

            VStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 72, height: 72)

                    Image(systemName: subscriptionManager.isProUser ? "crown.fill" : "person.fill")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundColor(.white)
                        .scaleEffect(appeared ? 1 : 0.5)
                        .opacity(appeared ? 1 : 0)
                }

                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Text(subscriptionManager.isProUser ? "Nudge Pro" : "Free Plan")
                            .font(.title2)
                            .fontWeight(.black)
                            .foregroundColor(.white)

                        if subscriptionManager.isProUser {
                            Text("ACTIVE")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }

                    Text(subscriptionManager.isProUser
                         ? "You have full, unlimited access"
                         : "\(SubscriptionManager.freeNudgesPerWeek) nudges per week · Free tier")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.75))
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
            }
            .padding(.vertical, 28)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    // MARK: - Plan Details Card

    @ViewBuilder
    private var planDetailsCard: some View {
        if let info = subscriptionManager.customerInfo,
           let entitlement = info.entitlements[SubscriptionManager.entitlementID],
           entitlement.isActive {

            let productID = entitlement.productIdentifier
            let isYearly = productID.lowercased().contains("year") || productID.lowercased().contains("annual")
            let planName = isYearly ? "Annual Plan" : "Monthly Plan"
            let renewalPeriod = isYearly ? "Annually" : "Monthly"
            let nudgesThisWeek = SubscriptionManager.shared.nudgesCreatedThisWeek()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("PLAN DETAILS")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .tracking(1.2)
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 14)

                Divider().padding(.horizontal, 18)

                VStack(spacing: 0) {
                    PlanDetailRow(label: "Plan", value: planName, badge: isYearly ? "BEST VALUE" : nil)

                    Divider().padding(.horizontal, 18)

                    PlanDetailRow(label: "Status", value: "Active", badge: nil)

                    Divider().padding(.horizontal, 18)

                    PlanDetailRow(label: "Billing cycle", value: renewalPeriod, badge: nil)

                    if let purchaseDate = entitlement.latestPurchaseDate {
                        Divider().padding(.horizontal, 18)
                        PlanDetailRow(label: "Started", value: purchaseDate.formatted(date: .long, time: .omitted), badge: nil)
                    }

                    if let expirationDate = entitlement.expirationDate {
                        Divider().padding(.horizontal, 18)
                        PlanDetailRow(label: "Next renewal", value: expirationDate.formatted(date: .long, time: .omitted), badge: nil)
                    }

                    Divider().padding(.horizontal, 18)

                    PlanDetailRow(label: "Nudges this week", value: "\(nudgesThisWeek)", badge: nil)

                    Divider().padding(.horizontal, 18)

                    PlanDetailRow(label: "Total nudges", value: "\(PersistenceManager.shared.entries.count)", badge: nil)

                    if let managementURL = info.managementURL {
                        Divider().padding(.horizontal, 18)

                        Link(destination: managementURL) {
                            HStack {
                                Text("Manage in App Store")
                                    .font(.subheadline)
                                    .foregroundColor(.accentColor)
                                    .fontWeight(.medium)

                                Spacer()

                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundColor(.accentColor.opacity(0.7))
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                        }
                    }
                }
            }
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 10) {
            if !subscriptionManager.isProUser {
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "crown.fill")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Upgrade to Pro")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Text("Unlimited nudges, full insights")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.75))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(16)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.55, green: 0.35, blue: 0.95), Color(red: 0.35, green: 0.20, blue: 0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Button {
                restorePurchases()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 36, height: 36)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Text("Restore Purchases")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Spacer()

                    if isRestoring {
                        ProgressView()
                            .tint(.secondary)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(16)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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

// MARK: - Plan Detail Row

private struct PlanDetailRow: View {
    let label: String
    let value: String
    let badge: String?

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 6) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if let badge {
                    Text(badge)
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundColor(.green)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.14))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}
