import SwiftUI
import StoreKit
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var historyViewModel: HistoryViewModel
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.dismiss) private var dismiss

    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("appearanceMode") private var appearanceMode = 0  // 0=system, 1=light, 2=dark
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("largeText") private var largeText = false
    // Accessibility overrides
    @AppStorage("acc_reduceMotion") private var reduceMotion = false
    @AppStorage("acc_increaseContrast") private var increaseContrast = false
    @State private var appeared = false
    @State private var showClearConfirm = false
    @State private var showTips = false
    @State private var showPaywall = false
    @State private var exportURL: URL? = nil
    @State private var showExport = false
    @State private var showNotificationsDeniedAlert = false
    @State private var showLanguageDropdown = false

    private var lang: LanguageManager { languageManager }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {

                heroCard
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)

                accountSection
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.05), value: appeared)

                generalSection
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.08), value: appeared)

                soundsSection
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.11), value: appeared)

                accessibilitySection
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.135), value: appeared)

                supportSection
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.155), value: appeared)

                dataSection
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.18), value: appeared)

                // debugSection
                //     .opacity(appeared ? 1 : 0)
                //     .offset(y: appeared ? 0 : 12)
                //     .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.21), value: appeared)

                versionFooter
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.21), value: appeared)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 48)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.05)) {
                appeared = true
            }
        }
        .alert(lang["settings.data.clear_title"], isPresented: $showClearConfirm) {
            Button(lang["settings.data.clear_confirm"], role: .destructive) {
                historyViewModel.clearAllEntries()
            }
            Button(lang["settings.data.cancel"], role: .cancel) {}
        } message: {
            Text(lang["settings.data.clear_message"])
        }
        .sheet(isPresented: $showTips) {
            TipsSheet()
                .environmentObject(languageManager)
        }
        .sheet(isPresented: $showPaywall) {
            NudgePaywallView()
                .environmentObject(subscriptionManager)
                .environmentObject(languageManager)
        }
        .sheet(isPresented: $showExport) {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
            }
        }
        .alert("Notifications Disabled", isPresented: $showNotificationsDeniedAlert) {
            Button("Open Settings") { NotificationManager.shared.openSystemSettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Nudge doesn't have permission to send notifications. Enable them in Settings to receive reminders.")
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        ZStack(alignment: .leading) {
            // Background gradient
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.68)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Decorative background shapes
            Circle()
                .fill(Color.white.opacity(0.09))
                .frame(width: 160, height: 160)
                .offset(x: -55, y: -40)

            Circle()
                .fill(Color.black.opacity(0.08))
                .frame(width: 110, height: 110)
                .offset(x: 240, y: 35)

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .frame(width: 60, height: 25)
                .rotationEffect(.degrees(-20))
                .offset(x: 200, y: -30)

            HStack(spacing: 18) {
                // Large plan icon badge
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 70, height: 70)
                    Image(systemName: subscriptionManager.isProUser ? "crown.fill" : "bolt.heart.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 6) {
                    // Always "SETTINGS"
                    Text(lang["settings.title"].uppercased())
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(.white)
                        .tracking(1.5)

                    // Plan tier as subtitle
                    Text(subscriptionManager.isProUser
                         ? lang["settings.account.pro_badge"]
                         : "\(lang["settings.account.free_badge"]) · \(lang["settings.account.free_subtitle"])")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.78))
                }

                Spacer()
            }
            .padding(.horizontal, 22)
        }
        .frame(height: 128)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    // MARK: - Account Section

    private var accountSection: some View {
        SectionGroup(title: lang["settings.account.section"]) {
            if subscriptionManager.isProUser {
                SectionRow {
                    HStack(spacing: 14) {
                        RowIcon(name: "crown.fill", color: Color(red: 0.55, green: 0.35, blue: 0.95))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(lang["settings.account.pro_badge"])
                                .font(.subheadline).fontWeight(.semibold)
                            Text(lang["settings.account.pro_subtitle"])
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("ACTIVE")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundColor(.green)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.green.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                RowDivider()

                SectionTapRow(
                    icon: "creditcard.fill",
                    iconColor: Color(red: 0.35, green: 0.60, blue: 0.95),
                    label: lang["settings.account.manage"],
                    action: {
                        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                            UIApplication.shared.open(url)
                        }
                    }
                )
            } else {
                Button { showPaywall = true } label: {
                    SectionRow {
                        HStack(spacing: 14) {
                            RowIcon(name: "bolt.heart.fill", color: .accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(lang["settings.account.upgrade"])
                                    .font(.subheadline).fontWeight(.semibold)
                                    .foregroundColor(.accentColor)
                                Text(lang["settings.account.free_subtitle"])
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption).fontWeight(.semibold)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            RowDivider()

            SectionTapRow(
                icon: "arrow.clockwise",
                iconColor: Color(red: 0.45, green: 0.55, blue: 0.65),
                label: lang["settings.account.restore"],
                action: { Task { try? await subscriptionManager.restorePurchases() } }
            )
        }
    }

    // MARK: - General Section (Appearance + Language)

    private var generalSection: some View {
        SectionGroup(title: lang["settings.preferences.section"]) {
            // Appearance
            SectionRow {
                HStack(spacing: 14) {
                    RowIcon(name: "circle.lefthalf.filled", color: Color(red: 0.55, green: 0.35, blue: 0.95))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lang["settings.preferences.appearance"])
                            .font(.subheadline).fontWeight(.medium)
                        Text(lang["settings.preferences.appearance_sub"])
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 2) {
                        ForEach([
                            (0, "circle.lefthalf.filled"),
                            (1, "sun.max.fill"),
                            (2, "moon.fill")
                        ], id: \.0) { tag, icon in
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) { appearanceMode = tag }
                                if hapticsEnabled { HapticManager.selection() }
                            } label: {
                                Image(systemName: icon)
                                    .font(.system(size: 13, weight: appearanceMode == tag ? .semibold : .regular))
                                    .frame(width: 32, height: 28)
                                    .background(appearanceMode == tag ? Color.accentColor : Color.clear)
                                    .foregroundColor(appearanceMode == tag ? .white : .secondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(3)
                    .background(AppColors.elevatedCard)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
            }

            RowDivider()

            // Language
            Button {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                    showLanguageDropdown.toggle()
                }
                if hapticsEnabled { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
            } label: {
                SectionRow {
                    HStack(spacing: 14) {
                        RowIcon(name: "globe", color: Color(red: 0.40, green: 0.45, blue: 0.90))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(lang["settings.language.section"])
                                .font(.subheadline).fontWeight(.medium)
                                .foregroundColor(.primary)
                            Text(languageManager.language.displayName)
                                .font(.caption).foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        HStack(spacing: 6) {
                            Text(languageManager.language.displayName)
                                .font(.subheadline).fontWeight(.medium)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .id("lang-" + languageManager.language.rawValue)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .rotationEffect(.degrees(showLanguageDropdown ? 180 : 0))
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            if showLanguageDropdown {
                VStack(spacing: 0) {
                    Divider().padding(.leading, 66)
                    ForEach(Array(AppLanguage.allCases.enumerated()), id: \.element.id) { index, appLang in
                        let isSelected = languageManager.language == appLang
                        let indigo = Color(red: 0.40, green: 0.45, blue: 0.90)
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                languageManager.language = appLang
                                showLanguageDropdown = false
                            }
                            if hapticsEnabled { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
                        } label: {
                            SectionRow {
                                HStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                                            .fill(isSelected ? indigo : indigo.opacity(0.10))
                                            .frame(width: 36, height: 36)
                                        Text(appLang.rawValue.uppercased())
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(isSelected ? .white : indigo)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(appLang.displayName)
                                            .font(.subheadline)
                                            .fontWeight(isSelected ? .semibold : .medium)
                                            .foregroundColor(.primary)
                                        Text(appLang.rawValue.uppercased())
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        .font(.body)
                                        .foregroundColor(isSelected ? indigo : Color.secondary.opacity(0.25))
                                }
                            }
                            .background(isSelected ? indigo.opacity(0.07) : Color.clear)
                        }
                        .buttonStyle(.plain)
                        if index < AppLanguage.allCases.count - 1 {
                            Divider().padding(.leading, 66)
                        }
                    }
                }
                .transition(.opacity)
                .clipped()
            }
        }
    }

    // MARK: - Sounds & Haptics Section

    private var soundsSection: some View {
        SectionGroup(title: lang["settings.sounds.section"]) {
            // Notifications
            SectionRow {
                HStack(spacing: 14) {
                    RowIcon(name: "bell.badge.fill", color: Color(red: 0.95, green: 0.35, blue: 0.50))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lang["settings.preferences.notifications"])
                            .font(.subheadline).fontWeight(.medium)
                        Text(lang["settings.preferences.notifications_sub"])
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $notificationsEnabled)
                        .labelsHidden()
                        .tint(.accentColor)
                        .onChange(of: notificationsEnabled) { _, enabled in
                            Task {
                                let success = await NotificationManager.shared.handleToggle(enabled: enabled)
                                if !success {
                                    notificationsEnabled = false
                                    showNotificationsDeniedAlert = true
                                }
                            }
                        }
                }
            }

            RowDivider()

            // Haptic Feedback
            SectionRow {
                HStack(spacing: 14) {
                    RowIcon(name: "waveform", color: Color(red: 0.55, green: 0.35, blue: 0.95))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lang["settings.preferences.haptics"])
                            .font(.subheadline).fontWeight(.medium)
                        Text(lang["settings.preferences.haptics_sub"])
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $hapticsEnabled)
                        .labelsHidden()
                        .tint(.accentColor)
                }
            }
        }
    }

    // MARK: - Accessibility Section

    private var accessibilitySection: some View {
        SectionGroup(title: lang["settings.accessibility.section"]) {
            accessibilityToggleRow(
                icon: "figure.walk.motion",
                color: Color(red: 0.35, green: 0.55, blue: 0.95),
                title: lang["settings.accessibility.reduce_motion"],
                subtitle: lang["settings.accessibility.reduce_motion_sub"],
                isOn: $reduceMotion
            )
            RowDivider()
            accessibilityToggleRow(
                icon: "textformat.size.larger",
                color: Color(red: 0.65, green: 0.40, blue: 0.90),
                title: lang["settings.accessibility.large_text"],
                subtitle: lang["settings.accessibility.large_text_sub"],
                isOn: $largeText
            )
            RowDivider()
            accessibilityToggleRow(
                icon: "circle.lefthalf.striped.horizontal.inverse",
                color: Color(red: 0.45, green: 0.35, blue: 0.85),
                title: lang["settings.accessibility.increase_contrast"],
                subtitle: lang["settings.accessibility.increase_contrast_sub"],
                isOn: $increaseContrast
            )
        }
    }

    /// Toggle row that only fires haptics when hapticsEnabled is true.
    @ViewBuilder
    private func accessibilityToggleRow(icon: String, color: Color, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
            if hapticsEnabled { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        } label: {
            SectionRow {
                HStack(spacing: 14) {
                    RowIcon(name: icon, color: color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundColor(.primary)
                        Text(subtitle)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: .constant(isOn.wrappedValue))
                        .labelsHidden()
                        .tint(.accentColor)
                        .allowsHitTesting(false)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Support Section

    private var supportSection: some View {
        SectionGroup(title: lang["settings.about.section"]) {
            SectionTapRow(
                icon: "sparkles",
                iconColor: .accentColor,
                label: lang["settings.about.how_it_works"],
                action: { showTips = true }
            )

            RowDivider()

            SectionLinkRow(
                icon: "star.fill",
                iconColor: Color(red: 0.95, green: 0.65, blue: 0.25),
                label: lang["settings.about.rate"],
                url: "https://apps.apple.com/app/id6760037466?action=write-review"
            )

            RowDivider()

            SectionLinkRow(
                icon: "hand.raised.fill",
                iconColor: Color(red: 0.35, green: 0.65, blue: 0.50),
                label: lang["settings.about.privacy"],
                url: "https://benjaminbelloeil.github.io/Nudge/privacy.html"
            )

            RowDivider()

            SectionLinkRow(
                icon: "doc.text.fill",
                iconColor: Color(red: 0.50, green: 0.55, blue: 0.72),
                label: lang["settings.about.terms"],
                url: "https://benjaminbelloeil.github.io/Nudge/terms.html"
            )
        }
    }

    // MARK: - Data Section

    // MARK: - Debug Section
    private var debugSection: some View {
        SectionGroup(title: "DEBUG 🛠️") {
            // Force Pro toggle — bypass RevenueCat entirely for UI testing
            SectionRow {
                HStack(spacing: 14) {
                    RowIcon(name: "crown.fill", color: .yellow)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Force Pro (bypass RC)")
                            .font(.subheadline).fontWeight(.semibold)
                        Text("Unlocks all Pro features locally")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { subscriptionManager.debugForceProUser },
                        set: { subscriptionManager.debugForceProUser = $0 }
                    ))
                    .labelsHidden()
                }
            }

            RowDivider()

            SectionTapRow(
                icon: "bell.badge.fill",
                iconColor: Color(red: 0.95, green: 0.45, blue: 0.25),
                label: "Send Test Notification (5s)",
                action: {
                    Task {
                        let content = UNMutableNotificationContent()
                        content.title = "Time to make progress"
                        content.body = "What\'s one thing you can do right now?"
                        content.sound = .default
                        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
                        let request = UNNotificationRequest(identifier: "nudge.test", content: content, trigger: trigger)
                        try? await UNUserNotificationCenter.current().add(request)
                    }
                }
            )

            RowDivider()

            SectionTapRow(
                icon: "list.bullet",
                iconColor: Color(red: 0.40, green: 0.65, blue: 0.95),
                label: "Print Pending Notifications",
                action: {
                    Task {
                        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
                        if pending.isEmpty {
                            print("[Notifications] No pending notifications scheduled")
                        } else {
                            pending.forEach { print("[Notifications]", $0.identifier, $0.trigger ?? "no trigger") }
                        }
                    }
                }
            )
        }
    }

    private var dataSection: some View {
        SectionGroup(title: lang["settings.data.section"]) {
            SectionTapRow(
                icon: "square.and.arrow.up",
                iconColor: Color(red: 0.20, green: 0.55, blue: 0.95),
                label: lang["settings.data.export"],
                action: {
                    if let data = historyViewModel.exportJSON() {
                        let url = FileManager.default.temporaryDirectory
                            .appendingPathComponent("nudge_export.json")
                        try? data.write(to: url)
                        exportURL = url
                        showExport = true
                    }
                }
            )

            RowDivider()

            Button { showClearConfirm = true } label: {
                SectionRow {
                    HStack(spacing: 14) {
                        RowIcon(name: "trash.fill", color: .red)
                        Text(lang["settings.data.clear"])
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Version Footer

    private var versionFooter: some View {
        VStack(spacing: 6) {
            Image(systemName: "bolt.heart.fill")
                .font(.system(size: 18))
                .foregroundColor(.accentColor.opacity(0.4))

            Text("NUDGE")
                .font(.system(size: 10, weight: .black).width(.expanded))
                .tracking(5)
                .foregroundStyle(.quaternary)

            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                Text("\(lang["settings.about.version"]) \(version)")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// MARK: - Section Building Blocks

/// One titled group — header above a single rounded card containing all rows
private struct SectionGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .tracking(1.2)
                .padding(.leading, 6)

            VStack(spacing: 0) {
                content
            }
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

/// Row container — horizontal padding + symmetric vertical padding
private struct SectionRow<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
    }
}

/// Inset divider aligned to row content (after the 36pt icon + 14pt gap = 66pt lead)
private struct RowDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 66)
    }
}

/// Standard tappable row with chevron
private struct SectionTapRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SectionRow {
                HStack(spacing: 14) {
                    RowIcon(name: icon, color: iconColor)
                    Text(label)
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// External link row with up-right arrow
private struct SectionLinkRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let url: String

    var body: some View {
        if let destination = URL(string: url) {
            Link(destination: destination) {
                SectionRow {
                    HStack(spacing: 14) {
                        RowIcon(name: icon, color: iconColor)
                        Text(label)
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }
}

/// Square icon badge (SF Symbol + tinted background)
private struct RowIcon: View {
    let name: String
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(color.opacity(0.13))
                .frame(width: 36, height: 36)
            Image(systemName: name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(color)
        }
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
