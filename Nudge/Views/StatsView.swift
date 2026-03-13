import SwiftUI
import Charts

struct StatsView: View {
    @ObservedObject var viewModel: HistoryViewModel
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var languageManager: LanguageManager
    private var lang: (String) -> String { { key in languageManager[key] } }
    @State private var showPaywall = false
    @State private var weekPage: Int = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                summaryRow

                if subscriptionManager.isProUser {
                    procrastinationInsightsSection
                    weeklyChart(sampleMode: viewModel.entries.isEmpty)
                    completionDonut(sampleMode: viewModel.entries.isEmpty)
                    moodChart(sampleMode: viewModel.entries.isEmpty)
                    frictionLabels
                } else {
                    // Blurred preview with lock overlay
                    ZStack {
                        VStack(spacing: 16) {
                            weeklyChart(sampleMode: viewModel.entries.isEmpty)
                            completionDonut(sampleMode: viewModel.entries.isEmpty)
                            moodChart(sampleMode: viewModel.entries.isEmpty)
                        }
                        .blur(radius: 10)
                        .allowsHitTesting(false)

                        // Lock overlay
                        VStack(spacing: 16) {
                            Spacer()

                            Image(systemName: "lock.fill")
                                .font(.system(size: 32, weight: .medium))
                                .foregroundColor(.accentColor)
                                .frame(width: 64, height: 64)
                                .background(Color.accentColor.opacity(0.12))
                                .clipShape(Circle())

                            VStack(spacing: 6) {
                                Text(lang("stats.unlock_title"))
                                    .font(.title3)
                                    .fontWeight(.bold)

                                Text(lang("stats.unlock_body"))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(2)
                            }

                            Button {
                                HapticManager.medium()
                                showPaywall = true
                            } label: {
                                Text(lang("stats.upgrade"))
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 28)
                                    .padding(.vertical, 12)
                                    .background(Color.accentColor)
                                    .clipShape(Capsule())
                            }

                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(AppColors.background)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle(lang("stats.title"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            NudgePaywallView()
                .environmentObject(subscriptionManager)
                .environmentObject(languageManager)
        }
    }

    // MARK: - Summary Row

    private var summaryRow: some View {
        HStack(spacing: 10) {
            InsightPill(title: lang("dashboard.total"), value: "\(viewModel.entries.count)", icon: "bolt.fill", color: Color(red: 0.35, green: 0.80, blue: 0.55))
            InsightPill(title: lang("dashboard.done"), value: "\(Int(viewModel.completionRate * 100))%", icon: "checkmark.circle.fill", color: Color(red: 0.55, green: 0.45, blue: 0.95))
            InsightPill(title: lang("dashboard.streak"), value: "\(viewModel.currentStreak)d", icon: "flame.fill", color: Color(red: 0.95, green: 0.65, blue: 0.25))
        }
    }

    // MARK: - Weekly Chart

    private func weeklyChart(sampleMode: Bool = false) -> some View {
        // weekPage = months back from today (0 = current month)
        let cal = Calendar.current
        let today = Date()
        let viewingDate = cal.date(byAdding: .month, value: -weekPage, to: today) ?? today
        let viewingComps = cal.dateComponents([.year, .month], from: viewingDate)

        let canGoForward = weekPage > 0
        let canGoBack    = weekPage < 12

        let monthFmt = DateFormatter()
        monthFmt.dateFormat = "MMMM yyyy"
        let monthLabel = monthFmt.string(from: viewingDate)

        // Build fixed Wk 1–4 slots for the viewed month
        let chartData: [(label: String, count: Int)]
        if sampleMode {
            chartData = [("Wk 1", 1), ("Wk 2", 3), ("Wk 3", 5), ("Wk 4", 2)]
        } else {
            let allWeeks = viewModel.weeklyNudgeCounts(weeks: 20)
            let weeksInMonth = allWeeks.filter {
                let c = cal.dateComponents([.year, .month], from: $0.weekStart)
                return c.month == viewingComps.month && c.year == viewingComps.year
            }
            chartData = (1...4).map { wk in
                let count = weeksInMonth.first {
                    cal.component(.weekOfMonth, from: $0.weekStart) == wk
                }?.count ?? 0
                return ("Wk \(wk)", count)
            }
        }

        return VStack(alignment: .leading, spacing: 10) {
            // Row 1: title + SAMPLE badge — never wraps
            HStack(spacing: 6) {
                Text(lang("stats.weekly"))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .tracking(1.2)
                    .lineLimit(1)
                if sampleMode {
                    Text("SAMPLE")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Capsule())
                }
                Spacer()
            }

            // Row 2: ← Month Year →
            HStack(spacing: 0) {
                Button {
                    withAnimation { weekPage += 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(canGoBack ? .primary : Color.secondary.opacity(0.25))
                        .frame(width: 28, height: 24)
                }
                .disabled(!canGoBack)
                .buttonStyle(.plain)

                Spacer()

                Text(monthLabel)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    withAnimation { weekPage -= 1 }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(canGoForward ? .primary : Color.secondary.opacity(0.25))
                        .frame(width: 28, height: 24)
                }
                .disabled(!canGoForward)
                .buttonStyle(.plain)
            }

            Chart {
                ForEach(chartData, id: \.label) { item in
                    BarMark(
                        x: .value("Week", item.label),
                        y: .value("Nudges", item.count)
                    )
                    .foregroundStyle(Color.accentColor)
                    .cornerRadius(6)
                }
            }
            .chartXScale(domain: ["Wk 1", "Wk 2", "Wk 3", "Wk 4"])
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine()
                        .foregroundStyle(Color.secondary.opacity(0.15))
                    AxisValueLabel()
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine()
                        .foregroundStyle(Color.secondary.opacity(0.15))
                    AxisValueLabel()
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 180)
        }
        .padding(18)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Completion Donut

    private func completionDonut(sampleMode: Bool = false) -> some View {
        let completed:  Int
        let inProgress: Int
        let notStarted: Int
        let total:      Int

        if sampleMode {
            completed = 5; inProgress = 3; notStarted = 2; total = 10
        } else {
            completed  = viewModel.entries.filter(\.isCompleted).count
            inProgress = viewModel.entries.filter { !$0.isCompleted && $0.stepsCompleted > 0 }.count
            notStarted = viewModel.entries.filter { !$0.isCompleted && $0.stepsCompleted == 0 }.count
            total      = viewModel.entries.count
        }

        let slices: [(label: String, value: Int, color: Color)] = [
            (lang("stats.completed"),  completed,  Color(red: 0.35, green: 0.80, blue: 0.55)),
            (lang("stats.in_progress"), inProgress, Color(red: 0.55, green: 0.45, blue: 0.95)),
            (lang("stats.not_started"), notStarted, Color.secondary.opacity(0.3))
        ].filter { $0.value > 0 }

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Text(lang("stats.completion_breakdown"))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .tracking(1.2)
                if sampleMode {
                    Text("SAMPLE")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 20) {
                ZStack {
                    DonutChartView(slices: slices)
                        .frame(width: 120, height: 120)
                    VStack(spacing: 2) {
                        Text("\(total)")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("total")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(slices, id: \.label) { slice in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(slice.color)
                                .frame(width: 8, height: 8)
                            Text(slice.label)
                                .font(.subheadline)
                            Spacer()
                            Text("\(slice.value)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding(18)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Mood Chart

    private func moodChart(sampleMode: Bool = false) -> some View {
        let data = sampleMode ? sampleMoodData : viewModel.moodDistribution()

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Text(lang("stats.mood_section"))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .tracking(1.2)
                if sampleMode {
                    Text("SAMPLE")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            ForEach(data.prefix(5), id: \.mood) { item in
                HStack(spacing: 12) {
                    Text(item.mood.emoji)
                        .font(.body)
                    Text(languageManager["mood.\(item.mood.rawValue)"])
                        .font(.subheadline)
                        .frame(width: 90, alignment: .leading)
                    GeometryReader { geo in
                        let maxCount = data.first?.count ?? 1
                        Capsule()
                            .fill(Color.accentColor.opacity(0.12))
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(Color.accentColor)
                                    .frame(width: maxCount > 0
                                        ? geo.size.width * CGFloat(item.count) / CGFloat(maxCount)
                                        : 0)
                            }
                            .clipShape(Capsule())
                    }
                    .frame(height: 8)
                    Text("\(item.count)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .frame(width: 24, alignment: .trailing)
                }
            }
        }
        .padding(18)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Friction Labels

    private var frictionLabels: some View {
        let realData  = Array(viewModel.frictionLabelFrequency().prefix(5))
        let useSample = realData.isEmpty
        let data      = useSample ? sampleFrictionData : realData

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Text(lang("stats.friction"))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .tracking(1.2)
                if useSample {
                    Text("SAMPLE")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            ForEach(data, id: \.label) { item in
                HStack {
                    FrictionBadge(label: item.label)
                    Spacer()
                    Text("\(item.count)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(18)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Procrastination Insights

    private var procrastinationInsightsSection: some View {
        let summary   = viewModel.procrastinationSummary
        let generating = viewModel.isGeneratingInsight

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(lang("stats.improve"))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .tracking(1.2)

                if generating {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.6)
                        .tint(Color(red: 0.55, green: 0.45, blue: 0.95).opacity(0.7))
                }

                Spacer()
            }

            if let text = summary {
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .animation(.easeInOut(duration: 0.3), value: text)
            } else if generating {
                HStack(spacing: 10) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Color(red: 0.55, green: 0.45, blue: 0.95))
                    Text(lang("stats.generating"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(lang("stats.no_insight"))
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .lineSpacing(4)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color(red: 0.55, green: 0.45, blue: 0.95).opacity(0.15), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Sample Data Helpers

    private var sampleWeeklyData: [(weekStart: Date, count: Int)] {
        let cal = Calendar.current
        let now = Date()
        let counts = [1, 0, 3, 2, 4, 1, 5, 3]
        return (0..<8).map { i in
            let weekStart = cal.date(byAdding: .weekOfYear, value: i - 7, to: now) ?? now
            return (weekStart: weekStart, count: counts[i])
        }
    }

    private var sampleMoodData: [(mood: Mood, count: Int)] {
        [(.calm, 5), (.anxious, 4), (.tired, 3), (.bored, 2), (.neutral, 2)]
    }

    private var sampleFrictionData: [(label: String, count: Int)] {
        switch languageManager.language.rawValue {
        case "es":
            return [("Poca energía", 4), ("Sin claridad", 3), ("Agobiado", 3), ("Distracciones", 2), ("Evitación", 1)]
        case "fr":
            return [("Faible énergie", 4), ("Pas de clarté", 3), ("Débordé", 3), ("Distractions", 2), ("Procrastination", 1)]
        default:
            return [("Low Energy", 4), ("No Clarity", 3), ("Overwhelmed", 3), ("Distractions", 2), ("Avoidance", 1)]
        }
    }
}

// MARK: - Insight Pill

private struct InsightPill: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(color.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Custom Donut Chart (no iOS 17 requirement)

private struct DonutChartView: View {
    let slices: [(label: String, value: Int, color: Color)]

    private var total: Double {
        Double(slices.reduce(0) { $0 + $1.value })
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let lineWidth = size * 0.2
            let radius = (size - lineWidth) / 2
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let gap: Double = 0.02 // gap in radians between slices

            ZStack {
                ForEach(Array(sliceAngles.enumerated()), id: \.offset) { _, item in
                    Path { path in
                        path.addArc(
                            center: center,
                            radius: radius,
                            startAngle: .radians(item.start + gap / 2),
                            endAngle: .radians(item.end - gap / 2),
                            clockwise: false
                        )
                    }
                    .stroke(item.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                }
            }
        }
    }

    private var sliceAngles: [(start: Double, end: Double, color: Color)] {
        guard total > 0 else { return [] }
        var result: [(start: Double, end: Double, color: Color)] = []
        var currentAngle = -Double.pi / 2 // start from top

        for slice in slices {
            let sliceAngle = (Double(slice.value) / total) * 2 * .pi
            result.append((start: currentAngle, end: currentAngle + sliceAngle, color: slice.color))
            currentAngle += sliceAngle
        }
        return result
    }
}
