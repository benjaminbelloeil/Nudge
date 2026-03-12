import SwiftUI
import RevenueCat

struct NudgePaywallView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.dismiss) private var dismiss

    private var lang: LanguageManager { languageManager }

    @State private var selectedPackage: Package?
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var errorMessage: String?
    @State private var restoreMessage: String?
    @State private var appeared = false
    @Environment(\.appReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // MARK: - Onboarding-Style Hero Card
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.accentColor)

                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.1), Color.clear, Color.black.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 120, height: 120)
                        .offset(x: -70, y: -30)
                        .scaleEffect(appeared ? 1 : 0.5)

                    Circle()
                        .fill(Color.black.opacity(0.06))
                        .frame(width: 90, height: 90)
                        .offset(x: 80, y: 30)
                        .scaleEffect(appeared ? 1 : 0.5)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 50, height: 20)
                        .rotationEffect(.degrees(-15))
                        .offset(x: -85, y: 30)
                        .scaleEffect(appeared ? 1 : 0)

                    Image(systemName: "sparkle")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.35))
                        .offset(x: -75, y: -35)
                        .scaleEffect(appeared ? 1 : 0.3)
                        .opacity(appeared ? 1 : 0)

                    Image(systemName: "infinity")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.35))
                        .offset(x: 80, y: -20)
                        .scaleEffect(appeared ? 1 : 0.3)
                        .opacity(appeared ? 1 : 0)

                    Image(systemName: "heart.fill")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.35))
                        .offset(x: -40, y: 40)
                        .scaleEffect(appeared ? 1 : 0.3)
                        .opacity(appeared ? 1 : 0)

                    Image(systemName: "bolt.heart.fill")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(color: Color.black.opacity(0.15), radius: 8, y: 4)
                        .scaleEffect(appeared ? 1 : 0.4)
                        .opacity(appeared ? 1 : 0)
                }
                .frame(height: 130)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.horizontal, 20)
                .accessibilityHidden(true)

                // MARK: - Title
                VStack(spacing: 4) {
                    HStack(spacing: 0) {
                        Text(lang["paywall.title_1"])
                            .foregroundColor(.primary)
                        + Text(lang["paywall.title_2"])
                            .foregroundColor(.accentColor)
                    }
                    .font(.system(size: 30, weight: .black).width(.expanded))
                    .tracking(6)

                    Text(lang["paywall.subtitle"])
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)

                // MARK: - Feature Cards
                VStack(spacing: 6) {
                    featureCard(icon: "infinity", title: lang["paywall.feature_unlimited_title"], subtitle: lang["paywall.feature_unlimited_sub"])
                    featureCard(icon: "bolt.fill", title: lang["paywall.feature_ai_title"], subtitle: lang["paywall.feature_ai_sub"])
                    featureCard(icon: "heart.fill", title: lang["paywall.feature_support_title"], subtitle: lang["paywall.feature_support_sub"])
                }
                .padding(.horizontal, 20)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)                .padding(.bottom, 4)
                // MARK: - Package Cards
                if let offering = subscriptionManager.offerings?.current {
                    VStack(spacing: 8) {
                        ForEach(offering.availablePackages, id: \.identifier) { pkg in
                            packageCard(pkg)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                } else {
                    ProgressView()
                        .tint(.secondary)
                        .frame(height: 80)
                }

                // MARK: - Error
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 24)
                }

                Divider()
                    .padding(.horizontal, 20)

                // MARK: - CTA + Restore
                VStack(spacing: 12) {
                    Button(action: { purchase() }) {
                        Group {
                            if isPurchasing {
                                ProgressView()
                                    .tint(Color(UIColor.systemBackground))
                            } else {
                                Text(lang["paywall.cta"])
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(selectedPackage != nil ? Color.primary : Color.secondary.opacity(0.3))
                        )
                        .foregroundColor(Color(UIColor.systemBackground))
                    }
                    .disabled(selectedPackage == nil || isPurchasing || isRestoring)
                    .accessibilityLabel(isPurchasing ? "Processing purchase" : lang["paywall.cta"])
                    .accessibilityHint(selectedPackage == nil ? "Select a plan first" : "Purchases the selected subscription")

                    Button {
                        restore()
                    } label: {
                        Group {
                            if isRestoring {
                                HStack(spacing: 6) {
                                    ProgressView().tint(.secondary).scaleEffect(0.8)
                                    Text(lang["paywall.restoring"]).font(.caption).foregroundColor(.secondary)
                                }
                            } else {
                                Text(lang["paywall.restore"]).font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                    .disabled(isPurchasing || isRestoring)
                    .accessibilityLabel(lang["paywall.restore"])
                    .accessibilityHint("Restores previously purchased subscriptions")

                    // Required subscription disclosure (App Store guidelines)
                    Text(lang["paywall.disclosure"])
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .fixedSize(horizontal: false, vertical: true)

                    // Legal links — Privacy Policy, Terms of Use, Apple EULA
                    HStack(spacing: 0) {
                        Link(lang["settings.about.privacy"],
                             destination: URL(string: "https://benjaminbelloeil.github.io/Nudge/privacy.html")!)
                        Text(" · ").foregroundStyle(.tertiary)
                        Link(lang["settings.about.terms"],
                             destination: URL(string: "https://benjaminbelloeil.github.io/Nudge/terms.html")!)
                        Text(" · ").foregroundStyle(.tertiary)
                        Link(lang["paywall.license"],
                             destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .tint(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .padding(.top, 24)
        }
        .background(AppColors.background.ignoresSafeArea())
        .alert(lang["paywall.restore"], isPresented: .init(
            get: { restoreMessage != nil },
            set: { if !$0 { restoreMessage = nil } }
        )) {
            Button(lang["alert.ok"]) { restoreMessage = nil }
        } message: {
            Text(restoreMessage ?? "")
        }
        .onAppear {
            withAnimation(reduceMotion ? .none : .spring(response: 0.8, dampingFraction: 0.75).delay(0.05)) {
                appeared = true
            }
        }
        .task {
            await subscriptionManager.fetchOfferings()
            if let offering = subscriptionManager.offerings?.current {
                selectedPackage = offering.availablePackages.first(where: {
                    $0.identifier.lowercased().contains("year") || $0.identifier == "$rc_annual"
                }) ?? offering.availablePackages.first
            }
        }
    }

    // MARK: - Feature Card (gray card, purple icon)

    private func featureCard(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundColor(.accentColor)
                .frame(width: 38, height: 38)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title). \(subtitle)")
    }

    // MARK: - Package Card

    private func packageCard(_ pkg: Package) -> some View {
        let isSelected = selectedPackage?.identifier == pkg.identifier
        let isYearly = pkg.identifier.lowercased().contains("year") || pkg.identifier == "$rc_annual"

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedPackage = pkg
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(pkg.storeProduct.localizedTitle)
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        if isYearly {
                            Text(lang["paywall.best_value"])
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundColor(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    Text(isYearly
                        ? "\(pkg.localizedPriceString)\(lang["paywall.per_year"])"
                        : "\(pkg.localizedPriceString)\(lang["paywall.per_month"])"
                    )
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(pkg.localizedPriceString)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(pkg.storeProduct.localizedTitle), \(isYearly ? pkg.localizedPriceString + " per year" : pkg.localizedPriceString + " per month")\(isYearly ? ", best value" : "")")
        .accessibilityHint(isSelected ? "Currently selected" : "Double tap to select this plan")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Actions

    private func purchase() {
        guard let pkg = selectedPackage else { return }
        isPurchasing = true
        errorMessage = nil
        Task {
            do {
                let completed = try await subscriptionManager.purchase(package: pkg)
                if completed { dismiss() }
            } catch {
                errorMessage = error.localizedDescription
            }
            isPurchasing = false
        }
    }

    private func restore() {
        isRestoring = true
        errorMessage = nil
        Task {
            do {
                try await subscriptionManager.restorePurchases()
                isRestoring = false
                if subscriptionManager.isProUser {
                    restoreMessage = lang["paywall.restore_success"]
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { dismiss() }
                } else {
                    restoreMessage = lang["paywall.restore_fail"]
                }
            } catch {
                isRestoring = false
                restoreMessage = error.localizedDescription
            }
        }
    }
}
