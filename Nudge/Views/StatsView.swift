import SwiftUI
import Charts

struct StatsView: View {
    @ObservedObject var viewModel: HistoryViewModel
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var showPaywall = false

    var body: some View {
        Group {
            if viewModel.entries.isEmpty {
                insightsEmptyState
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        summaryRow

                        if subscriptionManager.isProUser {
                            weeklyChart
                            completionDonut
                            moodChart
                            frictionLabels
                        } else {
                            // Blurred preview with lock overlay
                            ZStack {
                                VStack(spacing: 16) {
                                    weeklyChart
                                    completionDonut
                                    moodChart
                                    frictionLabels
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
                                        Text("Unlock Full Insights")
                                            .font(.title3)
                                            .fontWeight(.bold)

                                        Text("Upgrade to Pro to see all your\ntrends, moods, and patterns.")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.center)
                                            .lineSpacing(2)
                                    }

                                    Button {
                                        showPaywall = true
                                    } label: {
                                        Text("Upgrade")
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
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            NudgePaywallView()
        }
    }

    // MARK: - Empty State (centered, visually rich)

    private var insightsEmptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "chart.bar")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.secondary.opacity(0.4))

            VStack(spacing: 8) {
                Text("No insights yet")
                    .font(.title3)
                    .fontWeight(.bold)

                Text("Complete your first nudge\nand trends will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }

    // MARK: - Summary Row

    private var summaryRow: some View {
        HStack(spacing: 10) {
            InsightPill(title: "Total", value: "\(viewModel.entries.count)", icon: "bolt.fill", color: Color(red: 0.35, green: 0.80, blue: 0.55))
            InsightPill(title: "Done", value: "\(Int(viewModel.completionRate * 100))%", icon: "checkmark.circle.fill", color: Color(red: 0.55, green: 0.45, blue: 0.95))
            InsightPill(title: "Streak", value: "\(viewModel.currentStreak)d", icon: "flame.fill", color: Color(red: 0.95, green: 0.65, blue: 0.25))
        }
    }

    // MARK: - Weekly Chart

    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("WEEKLY ACTIVITY")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .tracking(1.2)

            let data = viewModel.weeklyNudgeCounts(weeks: 8)

            Chart(data, id: \.weekStart) { item in
                BarMark(
                    x: .value("Week", item.weekStart, unit: .weekOfYear),
                    y: .value("Nudges", item.count)
                )
                .foregroundStyle(Color.accentColor)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .frame(height: 160)
        }
        .padding(18)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Completion Donut

    private var completionDonut: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("COMPLETION BREAKDOWN")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .tracking(1.2)

            let completed = viewModel.entries.filter(\.isCompleted).count
            let inProgress = viewModel.entries.filter { !$0.isCompleted && $0.stepsCompleted > 0 }.count
            let notStarted = viewModel.entries.filter { !$0.isCompleted && $0.stepsCompleted == 0 }.count

            let slices: [(label: String, value: Int, color: Color)] = [
                ("Completed", completed, Color(red: 0.35, green: 0.80, blue: 0.55)),
                ("In Progress", inProgress, Color(red: 0.55, green: 0.45, blue: 0.95)),
                ("Not Started", notStarted, Color.secondary.opacity(0.3))
            ].filter { $0.value > 0 }

            HStack(spacing: 20) {
                // Custom donut chart
                ZStack {
                    DonutChartView(slices: slices)
                        .frame(width: 120, height: 120)

                    VStack(spacing: 2) {
                        Text("\(viewModel.entries.count)")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("total")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // Legend
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

    private var moodChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("MOOD WHEN PROCRASTINATING")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .tracking(1.2)

            let data = viewModel.moodDistribution()

            ForEach(data.prefix(5), id: \.mood) { item in
                HStack(spacing: 12) {
                    Text(item.mood.emoji)
                        .font(.body)

                    Text(item.mood.displayName)
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
                                        : 0
                                    )
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
        VStack(alignment: .leading, spacing: 14) {
            Text("COMMON FRICTION TYPES")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .tracking(1.2)

            let data = Array(viewModel.frictionLabelFrequency().prefix(5))

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

            if data.isEmpty {
                Text("No data yet")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(18)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
