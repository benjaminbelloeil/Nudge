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
    @AppStorage("nudgeStepCount") private var nudgeStepCount = 5
    @State private var appeared = false
    @State private var showClearConfirm = false
    @State private var showTips = false
    @State private var showPaywall = false
    @State private var exportURL: URL? = nil
    @State private var showExport = false
    @State private var showNotificationsDeniedAlert = false

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

                languageSection
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.08), value: appeared)

                preferencesSection
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.11), value: appeared)

                aboutSection
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.14), value: appeared)

                dataSection
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.17), value: appeared)

                debugSection
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.20), value: appeared)

                versionFooter
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: appeared)
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
                        RowIcon(name: "crown.fill", color: .yellow)
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

    // MARK: - Language Section

    private var languageSection: some View {
        SectionGroup(title: lang["settings.language.section"]) {
            ForEach(Array(AppLanguage.allCases.enumerated()), id: \.element.id) { index, appLang in
                let isSelected = languageManager.language == appLang

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        languageManager.language = appLang
                    }
                    if hapticsEnabled { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                } label: {
                    SectionRow {
                        HStack(spacing: 14) {
                            Text(appLang.flag)
                                .font(.title3)
                                .frame(width: 36, height: 36)
                                .background(AppColors.elevatedCard)
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                            Text(appLang.displayName)
                                .font(.subheadline).fontWeight(isSelected ? .semibold : .regular)
                                .foregroundColor(.primary)

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.body)
                                    .foregroundColor(.accentColor)
                                    .transition(.scale.combined(with: .opacity))
                            } else {
                                Circle()
                                    .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1.5)
                                    .frame(width: 20, height: 20)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)

                if index < AppLanguage.allCases.count - 1 {
                    RowDivider()
                }
            }
        }
    }

    // MARK: - Preferences Section

    private var preferencesSection: some View {
        SectionGroup(title: lang["settings.preferences.section"]) {
            // Appearance
            SectionRow {
                HStack(spacing: 14) {
                    RowIcon(name: "circle.lefthalf.filled", color: Color(red: 0.35, green: 0.35, blue: 0.40))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lang["settings.preferences.appearance"])
                            .font(.subheadline).fontWeight(.medium)
                        Text(lang["settings.preferences.appearance_sub"])
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    // Segmented appearance picker (icons only)
                    HStack(spacing: 2) {
                        ForEach([
                            (0, "circle.lefthalf.filled"),
                            (1, "sun.max.fill"),
                            (2, "moon.fill")
                        ], id: \.0) { tag, icon in
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) { appearanceMode = tag }
                                HapticManager.selection()
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

            // Haptics
            SectionRow {
                HStack(spacing: 14) {
                    RowIcon(name: "waveform", color: Color(red: 0.55, green: 0.45, blue: 0.95))
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

            RowDivider()

            // Notifications
            SectionRow {
                HStack(spacing: 14) {
                    RowIcon(name: "bell.badge.fill", color: Color(red: 0.95, green: 0.45, blue: 0.35))
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

            // Step count
            SectionRow {
                HStack(spacing: 14) {
                    RowIcon(name: "slider.horizontal.3", color: Color(red: 0.25, green: 0.60, blue: 0.95))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lang["settings.preferences.step_count"])
                            .font(.subheadline).fontWeight(.medium)
                        Text(lang["settings.preferences.step_count_sub"])
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 2) {
                        ForEach([2, 3, 5], id: \.self) { count in
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) { nudgeStepCount = count }
                                HapticManager.selection()
                            } label: {
                                Text("\(count)")
                                    .font(.system(size: 13, weight: nudgeStepCount == count ? .bold : .regular))
                                    .frame(width: 32, height: 28)
                                    .background(nudgeStepCount == count ? Color.accentColor : Color.clear)
                                    .foregroundColor(nudgeStepCount == count ? .white : .secondary)
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
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
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
                url: "https://apps.apple.com/app/idYOUR_APP_ID"
            )

            RowDivider()

            SectionLinkRow(
                icon: "hand.raised.fill",
                iconColor: Color(red: 0.35, green: 0.80, blue: 0.55),
                label: lang["settings.about.privacy"],
                url: "https://yourwebsite.com/privacy"
            )

            RowDivider()

            SectionLinkRow(
                icon: "doc.text.fill",
                iconColor: Color(red: 0.20, green: 0.55, blue: 0.95),
                label: lang["settings.about.terms"],
                url: "https://yourwebsite.com/terms"
            )
        }
    }

    // MARK: - Data Section

    // MARK: - Debug Section

    private var debugSection: some View {
        SectionGroup(title: "DEBUG") {
            SectionTapRow(
                icon: "bell.badge.fill",
                iconColor: Color(red: 0.95, green: 0.45, blue: 0.25),
                label: "Send Test Notification (5s)",
                action: {
                    Task {
                        let content = UNMutableNotificationContent()
                        content.title = "Time to make progress"
                        content.body = "What's one thing you can do right now?"
                        content.sound = .default
                        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
                        let request = UNNotificationRequest(identifier: "nudge.test", content: content, trigger: trigger)
                        try? await UNUserNotificationCenter.current().add(request)
                    }
                    // Background the app within 5 seconds to see the banner
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

            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
               let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                Text("\(lang["settings.about.version"]) \(version) (\(build))")
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
