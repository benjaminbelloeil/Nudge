import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var historyViewModel: HistoryViewModel
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Binding var navigationPath: NavigationPath
    @State private var appeared = false
    @State private var showTips = false
    @State private var showPaywall = false
    @State private var displayedMonth: Date = Date()
    @State private var selectedDate: Date? = nil

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                newNudgeButton
                statsRow
                recentSection
                calendarSection
                bottomNav
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(AppColors.background.ignoresSafeArea())
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    if subscriptionManager.isProUser {
                        navigationPath.append(NavigationDestination.customerCenter)
                    } else {
                        showPaywall = true
                    }
                } label: {
                    Image(systemName: subscriptionManager.isProUser ? "crown.fill" : "bolt.heart.fill")
                        .font(.body)
                        .foregroundColor(.accentColor)
                }

            }
            ToolbarItem(placement: .topBarLeading) {
                Button { showTips = true } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
        }
        .sheet(isPresented: $showTips) {
            TipsSheet()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.05)) {
                appeared = true
            }
        }
    }

    // MARK: - Header (tight to top)

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greetingText)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .tracking(1.5)

            HStack(spacing: 0) {
                Text("BREAK\n")
                    .foregroundColor(.primary)
                + Text("THROUGH")
                    .foregroundColor(.accentColor)
                + Text("\nFRICTION")
                    .foregroundColor(.primary)
            }
            .font(.system(size: 36, weight: .black).width(.expanded))
            .tracking(6)
            .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
    }

    // MARK: - New Nudge

    private var newNudgeButton: some View {
        Button {
            if subscriptionManager.canCreateNudge() {
                navigationPath.append(NavigationDestination.newNudge)
            } else {
                showPaywall = true
            }
        } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("New Nudge")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Start your next task")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                Image(systemName: "plus")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.accentColor)
            )
        }
        .buttonStyle(.plain)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
        .sheet(isPresented: $showPaywall) {
            NudgePaywallView()
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 10) {
            StatPill(
                value: "\(historyViewModel.entries.count)",
                label: "Total",
                color: Color(red: 0.35, green: 0.80, blue: 0.55)
            )
            StatPill(
                value: "\(Int(historyViewModel.completionRate * 100))%",
                label: "Done",
                color: Color(red: 0.55, green: 0.45, blue: 0.95)
            )
            StatPill(
                value: "\(historyViewModel.currentStreak)d",
                label: "Streak",
                color: Color(red: 0.95, green: 0.65, blue: 0.25)
            )
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
    }

    // MARK: - Pro Section

    // MARK: - Recent (clean, consistent color scheme)

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("RECENT")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .tracking(1.2)
                Spacer()
                if !historyViewModel.entries.isEmpty {
                    NavigationLink(value: NavigationDestination.history) {
                        Text("View all")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.accentColor)
                    }
                }
            }

            if historyViewModel.entries.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "bolt.heart.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.accentColor)
                    VStack(spacing: 4) {
                        Text("No nudges yet")
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("Create your first nudge to get started")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .padding(.horizontal, 20)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                ForEach(historyViewModel.entries.prefix(3)) { entry in
                    Button {
                        navigationPath.append(NavigationDestination.nudgeDetail(entry.id))
                    } label: {
                        RecentCard(entry: entry)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            historyViewModel.deleteEntry(id: entry.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
    }

    // MARK: - Calendar

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CALENDAR")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .tracking(1.2)

            VStack(spacing: 16) {
                // Month navigation
                HStack {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            displayedMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                            selectedDate = nil
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.accentColor)
                            .frame(width: 36, height: 36)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(Circle())
                    }

                    Spacer()

                    Text(monthYearString(for: displayedMonth))
                        .font(.body)
                        .fontWeight(.bold)

                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            displayedMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                            selectedDate = nil
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.accentColor)
                            .frame(width: 36, height: 36)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(Circle())
                    }
                }

                // Weekday headers
                HStack(spacing: 0) {
                    ForEach(Array(["S", "M", "T", "W", "T", "F", "S"].enumerated()), id: \.offset) { _, day in
                        Text(day)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.bottom, 2)

                // Days grid
                let days = calendarDays(for: displayedMonth)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 8) {
                    ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                        if let date = day {
                            let count = nudgeCount(on: date)
                            let isToday = Calendar.current.isDateInToday(date)
                            let isSelected = selectedDate.map { Calendar.current.isDate($0, inSameDayAs: date) } ?? false

                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    if isSelected {
                                        selectedDate = nil
                                    } else {
                                        selectedDate = date
                                    }
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Text("\(Calendar.current.component(.day, from: date))")
                                        .font(.subheadline)
                                        .fontWeight(isToday || isSelected ? .bold : .regular)
                                        .foregroundColor(
                                            isSelected ? .white :
                                            isToday ? .accentColor :
                                            count > 0 ? .primary : .secondary.opacity(0.5)
                                        )
                                        .frame(width: 36, height: 36)
                                        .background(
                                            Circle()
                                                .fill(isSelected ? Color.accentColor : isToday ? Color.accentColor.opacity(0.12) : Color.clear)
                                        )

                                    // Dot indicator
                                    Circle()
                                        .fill(count > 0 ? (isSelected ? Color.white : Color.accentColor) : Color.clear)
                                        .frame(width: 5, height: 5)
                                }
                            }
                            .buttonStyle(.plain)
                        } else {
                            VStack(spacing: 4) {
                                Color.clear.frame(width: 36, height: 36)
                                Color.clear.frame(width: 5, height: 5)
                            }
                        }
                    }
                }

                // Selected date nudges
                if let selectedDate = selectedDate {
                    let dayEntries = historyViewModel.entries.filter {
                        Calendar.current.isDate($0.createdAt, inSameDayAs: selectedDate)
                    }

                    if !dayEntries.isEmpty {
                        VStack(spacing: 8) {
                            HStack {
                                Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(dayEntries.count) nudge\(dayEntries.count == 1 ? "" : "s")")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }

                            ForEach(dayEntries) { entry in
                                NavigationLink(value: NavigationDestination.nudgeDetail(entry.id)) {
                                    HStack(spacing: 10) {
                                        Text(entry.mood.emoji)
                                            .font(.caption)
                                        Text(entry.taskDescription)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .lineLimit(1)
                                        Spacer()
                                        ProgressCapsule(completed: entry.stepsCompleted, total: entry.totalSteps)
                                            .frame(width: 50)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 10)
                                    .background(AppColors.elevatedCard)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    } else {
                        HStack {
                            Spacer()
                            Text("No nudges on this day")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Spacer()
                        }
                        .padding(.top, 4)
                        .transition(.opacity)
                    }
                }
            }
            .padding(20)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
    }

    // MARK: - Calendar Helpers

    private func monthYearString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func calendarDays(for date: Date) -> [Date?] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: date),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)

        for day in range {
            if let d = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(d)
            }
        }

        while days.count % 7 != 0 {
            days.append(nil)
        }

        return days
    }

    private func nudgeCount(on date: Date) -> Int {
        let calendar = Calendar.current
        return historyViewModel.entries.filter {
            calendar.isDate($0.createdAt, inSameDayAs: date)
        }.count
    }

    // MARK: - Bottom Nav

    private var bottomNav: some View {
        HStack(spacing: 12) {
            NavigationLink(value: NavigationDestination.history) {
                NavCard(
                    icon: "clock.arrow.circlepath",
                    title: "History",
                    subtitle: "\(historyViewModel.entries.count) nudges",
                    color: Color(red: 0.20, green: 0.55, blue: 0.95)
                )
            }
            .buttonStyle(.plain)

            NavigationLink(value: NavigationDestination.insights) {
                NavCard(
                    icon: "chart.bar.fill",
                    title: "Insights",
                    subtitle: "View trends",
                    color: Color(red: 0.55, green: 0.45, blue: 0.95)
                )
            }
            .buttonStyle(.plain)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "GOOD MORNING" }
        if hour < 18 { return "GOOD AFTERNOON" }
        return "GOOD EVENING"
    }
}

// MARK: - Sub-Views

private struct StatPill: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(color.opacity(0.4), lineWidth: 1.5)
                )
        )
    }
}

private struct RecentCard: View {
    let entry: NudgeEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row: task name + completion
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.taskDescription.replacingOccurrences(of: "\n", with: " "))
                        .font(.body)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(.primary)

                    HStack(spacing: 8) {
                        FrictionBadge(label: entry.result.frictionLabel)
                        Text(entry.mood.emoji)
                            .font(.caption)
                    }
                }
                Spacer()
                ZStack {
                    Circle()
                        .fill(entry.isCompleted ? Color.green.opacity(0.15) : Color.secondary.opacity(0.08))
                        .frame(width: 36, height: 36)
                    Image(systemName: entry.isCompleted ? "checkmark" : "chevron.right")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(entry.isCompleted ? .green : .secondary.opacity(0.4))
                }
            }

            // Bottom row: steps + date
            HStack {
                ProgressCapsule(completed: entry.stepsCompleted, total: entry.totalSteps)
                Spacer()
                Text("\(entry.stepsCompleted)/\(entry.totalSteps) steps")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("·").foregroundStyle(.tertiary)
                Text(entry.createdAt.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(18)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct NavCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }

            Text(title)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(color)
        )
    }
}

// MARK: - Tips Sheet (Rich Visual How-It-Works)

private struct TipsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Nudge breaks through procrastination with tiny, progressive steps tailored to how you feel.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    HowItWorksSection(
                        stepNumber: "1",
                        title: "Describe Your Task",
                        description: "Tell Nudge what you've been putting off. The more detail, the better your steps.",
                        color: Color.accentColor,
                        mockupContent: AnyView(TaskMockup())
                    )

                    HowItWorksSection(
                        stepNumber: "2",
                        title: "Set Mood & Energy",
                        description: "Pick your current mood and energy level. Nudge adapts: low energy gets gentler steps.",
                        color: Color(red: 0.55, green: 0.45, blue: 0.95),
                        mockupContent: AnyView(MoodEnergyMockup())
                    )

                    HowItWorksSection(
                        stepNumber: "3",
                        title: "Get Your Action Plan",
                        description: "4 progressive steps, each building on the last. From a tiny first move to real progress.",
                        color: Color(red: 0.35, green: 0.80, blue: 0.55),
                        mockupContent: AnyView(StepsMockup())
                    )

                    HowItWorksSection(
                        stepNumber: "4",
                        title: "Track Your Progress",
                        description: "See streaks, completion rate, and mood patterns. Build momentum over time.",
                        color: Color(red: 0.95, green: 0.65, blue: 0.25),
                        mockupContent: AnyView(StatsMockup())
                    )

                    // Pro tip
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Pro tip")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                            Text("Done beats perfect. A rough start is infinitely better than a perfect plan you never begin.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineSpacing(2)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 32)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("How Nudge Works")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct HowItWorksSection: View {
    let stepNumber: String
    let title: String
    let description: String
    let color: Color
    let mockupContent: AnyView

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 30, height: 30)
                    Text(stepNumber)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
            }

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(3)

            mockupContent
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.elevatedCard)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(color.opacity(0.15), lineWidth: 1)
                )
        }
        .padding(18)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 20)
    }
}

// Mini mockup components for Tips
private struct TaskMockup: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WHAT ARE YOU PUTTING OFF?")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.accentColor)
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppColors.cardBackground)
                .frame(height: 40)
                .overlay(
                    Text("Write my research paper intro...")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 10),
                    alignment: .leading
                )
        }
    }
}

private struct MoodEnergyMockup: View {
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { i in
                    Circle()
                        .fill(i <= 3 ? Color.accentColor : Color.secondary.opacity(0.15))
                        .frame(width: 22, height: 22)
                        .overlay(
                            Text("\(i)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(i <= 3 ? .white : .secondary)
                        )
                }
            }
            HStack(spacing: 4) {
                MiniMoodChip(emoji: "😌", name: "Calm", selected: false)
                MiniMoodChip(emoji: "😵‍💫", name: "Overwhelm", selected: true)
            }
        }
    }
}

private struct StepsMockup: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            MiniStepRow(num: "1", title: "Open Your Document", done: true)
            MiniStepRow(num: "2", title: "Write One Sentence", done: true)
            MiniStepRow(num: "3", title: "Expand Your Draft", done: false)
            MiniStepRow(num: "4", title: "Save and Plan Next", done: false)
        }
    }
}

private struct StatsMockup: View {
    var body: some View {
        HStack(spacing: 6) {
            MiniStatBox(value: "12", label: "Total", color: Color(red: 0.35, green: 0.80, blue: 0.55))
            MiniStatBox(value: "75%", label: "Done", color: Color(red: 0.55, green: 0.45, blue: 0.95))
            MiniStatBox(value: "3d", label: "Streak", color: Color(red: 0.95, green: 0.65, blue: 0.25))
        }
    }
}

private struct MiniMoodChip: View {
    let emoji: String
    let name: String
    let selected: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text(emoji).font(.caption2)
            Text(name).font(.system(size: 9, weight: selected ? .semibold : .regular))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(selected ? Color.accentColor.opacity(0.15) : AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(selected ? Color.accentColor.opacity(0.4) : Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }
}

private struct MiniStepRow: View {
    let num: String
    let title: String
    let done: Bool

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(done ? Color.green : Color.accentColor.opacity(0.15))
                    .frame(width: 20, height: 20)
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text(num)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.accentColor)
                }
            }
            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(done ? .secondary : .primary)
                .strikethrough(done)
        }
    }
}

private struct MiniStatBox: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
