import SwiftUI
import RevenueCat

struct CustomerCenterView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.dismiss) private var dismiss

    private var lang: LanguageManager { languageManager }

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
        .navigationTitle(lang["customer.title"])
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.05)) {
                appeared = true
            }
        }
        .alert(lang["alert.info"], isPresented: .init(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button(lang["alert.ok"]) { alertMessage = nil }
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
                        Text(subscriptionManager.isProUser ? lang["settings.account.pro_badge"] : lang["settings.account.free_badge"])
                            .font(.title2)
                            .fontWeight(.black)
                            .foregroundColor(.white)

                        if subscriptionManager.isProUser {
                            Text(lang["badge.active"])
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }

                    Text(subscriptionManager.isProUser
                         ? lang["customer.full_access"]
                         : "\(SubscriptionManager.freeNudgesPerWeek) \(lang["customer.free_tier"])")
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
            let planName = isYearly ? lang["customer.annual_plan"] : lang["customer.monthly_plan"]
            let renewalPeriod = isYearly ? lang["customer.annually"] : lang["customer.monthly"]
            let nudgesThisWeek = SubscriptionManager.shared.nudgesCreatedThisWeek()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text(lang["customer.plan_details"])
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
                    PlanDetailRow(label: lang["customer.plan"], value: planName, badge: isYearly ? lang["paywall.best_value"] : nil)

                    Divider().padding(.horizontal, 18)

                    PlanDetailRow(label: lang["customer.status"], value: lang["customer.active"], badge: nil)

                    Divider().padding(.horizontal, 18)

                    PlanDetailRow(label: lang["customer.billing_cycle"], value: renewalPeriod, badge: nil)

                    if let purchaseDate = entitlement.latestPurchaseDate {
                        Divider().padding(.horizontal, 18)
                        PlanDetailRow(label: lang["customer.started"], value: purchaseDate.formatted(date: .long, time: .omitted), badge: nil)
                    }

                    if let expirationDate = entitlement.expirationDate {
                        Divider().padding(.horizontal, 18)
                        PlanDetailRow(label: lang["customer.next_renewal"], value: expirationDate.formatted(date: .long, time: .omitted), badge: nil)
                    }

                    Divider().padding(.horizontal, 18)

                    PlanDetailRow(label: lang["customer.nudges_week"], value: "\(nudgesThisWeek)", badge: nil)

                    Divider().padding(.horizontal, 18)

                    PlanDetailRow(label: lang["customer.total_nudges"], value: "\(PersistenceManager.shared.entries.count)", badge: nil)

                    if let managementURL = info.managementURL {
                        Divider().padding(.horizontal, 18)

                        Link(destination: managementURL) {
                            HStack {
                                Text(lang["customer.manage_appstore"])
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
                            Text(lang["customer.upgrade"])
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Text(lang["customer.upgrade_sub"])
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

                    Text(lang["paywall.restore"])
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
                    alertMessage = lang["paywall.restore_success"]
                } else {
                    alertMessage = lang["paywall.restore_fail"]
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
