import Foundation
import Combine
import SwiftUI

@MainActor
final class HistoryViewModel: ObservableObject {

    @Published var searchText: String = ""
    @Published var filterMood: Mood? = nil
    @Published private(set) var procrastinationSummary: String? = nil
    @Published private(set) var isGeneratingInsight: Bool = false

    private let persistence: PersistenceManager
    private var cancellables = Set<AnyCancellable>()
    private let insightService = InsightService()
    private var insightTask: Task<Void, Never>? = nil

    init(persistence: PersistenceManager = .shared) {
        self.persistence = persistence
        persistence.$entries
            .receive(on: RunLoop.main)
            .sink { [weak self] newEntries in
                guard let self else { return }
                self.objectWillChange.send()
                // Show fallback immediately, then try Apple Intelligence
                self.procrastinationSummary = Self.buildProcrastinationSummary(entries: newEntries)
                self.insightTask?.cancel()
                self.insightTask = Task { await self.refreshInsight(entries: newEntries) }
            }
            .store(in: &cancellables)
        // Populate on first load — fallback first, AI async
        procrastinationSummary = Self.buildProcrastinationSummary(entries: persistence.entries)
        insightTask = Task { await self.refreshInsight(entries: persistence.entries) }
    }

    var entries: [NudgeEntry] {
        persistence.entries
    }

    // MARK: - Filtered Results

    var filteredEntries: [NudgeEntry] {
        var result = entries

        if let mood = filterMood {
            result = result.filter { $0.mood == mood }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.taskDescription.lowercased().contains(query) ||
                $0.result.frictionLabel.lowercased().contains(query)
            }
        }

        return result
    }

    // MARK: - Actions

    func deleteEntry(id: UUID) {
        persistence.deleteEntry(id: id)
    }

    func clearAllEntries() {
        persistence.clearAll()
    }

    func exportJSON() -> Data? {
        try? JSONEncoder().encode(entries)
    }

    func toggleCompletion(id: UUID) {
        persistence.toggleCompletion(id: id)
    }

    func toggleStepCompletion(entryId: UUID, stepId: Int) {
        guard var entry = entries.first(where: { $0.id == entryId }) else { return }
        let steps = entry.result.steps

        if entry.completedStepIds.contains(stepId) {
            // Unchecking: also uncheck all subsequent steps
            entry.completedStepIds.remove(stepId)
            for step in steps where step.id > stepId {
                entry.completedStepIds.remove(step.id)
            }
        } else {
            // Checking: only allow if all previous steps are completed
            let allPreviousDone = steps.filter { $0.id < stepId }.allSatisfy { entry.completedStepIds.contains($0.id) }
            guard allPreviousDone else { return }
            entry.completedStepIds.insert(stepId)
        }

        // Auto-update completion status based on steps
        let allDone = entry.completedStepIds.count == steps.count && !steps.isEmpty
        entry.isCompleted = allDone
        entry.completedAt = allDone ? Date() : nil
        persistence.updateEntry(entry)
    }

    // MARK: - Stats: Weekly Nudge Counts

    func weeklyNudgeCounts(weeks: Int = 8) -> [(weekStart: Date, count: Int)] {
        let calendar = Calendar.current
        let today = Date()
        var result: [(weekStart: Date, count: Int)] = []

        for weekOffset in (0..<weeks).reversed() {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: today),
                  let interval = calendar.dateInterval(of: .weekOfYear, for: weekStart) else {
                continue
            }
            let count = entries.filter {
                $0.createdAt >= interval.start && $0.createdAt < interval.end
            }.count
            result.append((weekStart: interval.start, count: count))
        }

        return result
    }

    // MARK: - Stats: Mood Distribution

    func moodDistribution() -> [(mood: Mood, count: Int)] {
        var counts: [Mood: Int] = [:]
        for entry in entries {
            counts[entry.mood, default: 0] += 1
        }
        return counts
            .map { (mood: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    // MARK: - Stats: Energy Distribution

    func energyDistribution() -> [(energy: EnergyLevel, count: Int)] {
        var counts: [EnergyLevel: Int] = [:]
        for entry in entries {
            counts[entry.energy, default: 0] += 1
        }
        return EnergyLevel.allCases.map { level in
            (energy: level, count: counts[level, default: 0])
        }
    }

    // MARK: - Stats: Completion Rate

    var completionRate: Double {
        guard !entries.isEmpty else { return 0 }
        let completed = entries.filter(\.isCompleted).count
        return Double(completed) / Double(entries.count)
    }

    // MARK: - Stats: Friction Label Frequency

    func frictionLabelFrequency() -> [(label: String, count: Int)] {
        var counts: [String: Int] = [:]
        for entry in entries {
            counts[entry.result.frictionLabel, default: 0] += 1
        }
        return counts
            .map { (label: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    // MARK: - Stats: Current Streak

    var currentStreak: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Grace period: if no entry today yet, still count from yesterday
        // Only reset if the last entry is 2+ days ago
        let hasEntryToday = entries.contains { calendar.isDate($0.createdAt, inSameDayAs: today) }
        guard let startDate = hasEntryToday
                ? Optional(today)
                : calendar.date(byAdding: .day, value: -1, to: today)
        else { return 0 }

        // Make sure there's actually an entry on the start date
        let hasEntryOnStart = entries.contains { calendar.isDate($0.createdAt, inSameDayAs: startDate) }
        guard hasEntryOnStart else { return 0 }

        var streak = 0
        var checkDate = startDate

        while true {
            let hasEntry = entries.contains { entry in
                calendar.isDate(entry.createdAt, inSameDayAs: checkDate)
            }
            if hasEntry {
                streak += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = previousDay
            } else {
                break
            }
        }

        return streak
    }

    // MARK: - Procrastination Insight Helpers

    /// Energy level with the highest completion rate (≥2 entries required)
    var bestEnergyForCompletion: EnergyLevel? {
        var best: EnergyLevel? = nil
        var bestRate: Double = -1
        for level in EnergyLevel.allCases {
            let subset = entries.filter { $0.energy == level }
            guard subset.count >= 2 else { continue }
            let rate = Double(subset.filter(\.isCompleted).count) / Double(subset.count)
            if rate > bestRate { bestRate = rate; best = level }
        }
        return best
    }

    /// Mood with the lowest completion rate (≥2 entries required) — most procrastination-prone
    var toughestMood: Mood? {
        var worst: Mood? = nil
        var worstRate: Double = 2.0
        for mood in Mood.allCases {
            let subset = entries.filter { $0.mood == mood }
            guard subset.count >= 2 else { continue }
            let rate = Double(subset.filter(\.isCompleted).count) / Double(subset.count)
            if rate < worstRate { worstRate = rate; worst = mood }
        }
        return worst
    }

    /// Step number where most users drop off (last step completed before abandoning)
    var stepDropOffNumber: Int? {
        let incomplete = entries.filter { !$0.isCompleted && !$0.completedStepIds.isEmpty }
        guard !incomplete.isEmpty else { return nil }
        var stepCounts: [Int: Int] = [:]
        for entry in incomplete {
            if let maxStep = entry.completedStepIds.max() {
                stepCounts[maxStep, default: 0] += 1
            }
        }
        return stepCounts.max(by: { $0.value < $1.value })?.key
    }

    /// Average number of steps completed per nudge (including incomplete)
    var averageStepsCompleted: Double {
        guard !entries.isEmpty else { return 0 }
        let total = entries.reduce(0) { $0 + $1.stepsCompleted }
        return Double(total) / Double(entries.count)
    }

    /// Day of week (e.g. "Monday") when most nudges are created
    var mostActiveWeekdayName: String? {
        guard !entries.isEmpty else { return nil }
        let calendar = Calendar.current
        var dayCounts: [Int: Int] = [:]
        for entry in entries {
            let weekday = calendar.component(.weekday, from: entry.createdAt)
            dayCounts[weekday, default: 0] += 1
        }
        guard let topDay = dayCounts.max(by: { $0.value < $1.value })?.key else { return nil }
        // weekday: 1=Sun, 2=Mon … 7=Sat
        let names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let idx = topDay - 1
        return names.indices.contains(idx) ? names[idx] : nil
    }

    // MARK: - Apple Intelligence Insight Generation

    private func refreshInsight(entries: [NudgeEntry]) async {
        guard entries.count >= 3, InsightService.isAvailable else { return }
        isGeneratingInsight = true
        let snapshot = buildSnapshot(entries: entries)
        if let aiText = await insightService.generate(from: snapshot) {
            guard !Task.isCancelled else { isGeneratingInsight = false; return }
            procrastinationSummary = aiText
        }
        isGeneratingInsight = false
    }

    private func buildSnapshot(entries: [NudgeEntry]) -> InsightService.StatsSnapshot {
        let total = entries.count
        let completionRatePct = Int(Double(entries.filter(\.isCompleted).count) / Double(total) * 100)

        // Toughest mood (lowest completion rate, ≥2 entries)
        var worstMood: Mood? = nil
        var worstMoodRate: Double = 2.0
        var worstMoodPct: Int? = nil
        var worstMoodTotalCount: Int? = nil
        for mood in Mood.allCases {
            let subset = entries.filter { $0.mood == mood }
            guard subset.count >= 2 else { continue }
            let rate = Double(subset.filter(\.isCompleted).count) / Double(subset.count)
            if rate < worstMoodRate {
                worstMoodRate = rate
                worstMood = mood
                worstMoodPct = Int((rate * 100).rounded())
                worstMoodTotalCount = subset.count
            }
        }

        // Best energy level (highest completion rate, ≥2 entries)
        var bestEnergy: EnergyLevel? = nil
        var bestEnergyRate: Double = -1
        var bestEnergyPct: Int? = nil
        for level in EnergyLevel.allCases {
            let subset = entries.filter { $0.energy == level }
            guard subset.count >= 2 else { continue }
            let rate = Double(subset.filter(\.isCompleted).count) / Double(subset.count)
            if rate > bestEnergyRate { bestEnergyRate = rate; bestEnergy = level; bestEnergyPct = Int((rate * 100).rounded()) }
        }

        // Top friction label
        var frictionCounts: [String: Int] = [:]
        for e in entries { frictionCounts[e.result.frictionLabel, default: 0] += 1 }
        let topFriction = frictionCounts.max(by: { $0.value < $1.value })

        // Drop-off step (only if ≥10% of all nudges stall there)
        let incompleteStarted = entries.filter { !$0.isCompleted && !$0.completedStepIds.isEmpty }
        var dropOffStep: Int? = nil
        var dropOffPct: Int? = nil
        if !incompleteStarted.isEmpty {
            var stepCounts: [Int: Int] = [:]
            for e in incompleteStarted {
                if let s = e.completedStepIds.max() { stepCounts[s, default: 0] += 1 }
            }
            if let top = stepCounts.max(by: { $0.value < $1.value }) {
                let pct = Int(Double(top.value) / Double(total) * 100)
                if pct >= 10 { dropOffStep = top.key; dropOffPct = pct }
            }
        }

        return InsightService.StatsSnapshot(
            totalNudges: total,
            completionRatePct: completionRatePct,
            topMood: worstMood?.displayName.lowercased(),
            topMoodCompletionPct: worstMoodPct,
            topMoodTotalCount: worstMoodTotalCount,
            bestEnergy: bestEnergy?.displayName.lowercased(),
            bestEnergyCompletionPct: bestEnergyPct,
            topFrictionLabel: topFriction?.key,
            topFrictionPct: topFriction.map { Int((Double($0.value) / Double(total) * 100).rounded()) },
            dropOffStep: dropOffStep,
            dropOffPct: dropOffPct
        )
    }

    // MARK: - Procrastination Summary (static so it can be called from Combine sink)

    static func buildProcrastinationSummary(entries: [NudgeEntry]) -> String? {
        guard entries.count >= 3 else { return nil }
        let total = entries.count
        var parts: [String] = []

        // ── helpers ────────────────────────────────────────────────────────
        func completionRate(for subset: [NudgeEntry]) -> Double {
            subset.isEmpty ? 0 : Double(subset.filter(\.isCompleted).count) / Double(subset.count)
        }

        // ── Sentence 1: strongest single signal ────────────────────────────

        // Drop-off: most common last step among incomplete-but-started nudges
        let incompleteStarted = entries.filter { !$0.isCompleted && !$0.completedStepIds.isEmpty }
        if !incompleteStarted.isEmpty {
            var stepCounts: [Int: Int] = [:]
            for e in incompleteStarted {
                if let s = e.completedStepIds.max() { stepCounts[s, default: 0] += 1 }
            }
            if let dropOff = stepCounts.max(by: { $0.value < $1.value })?.key {
                // Express as share of ALL entries so the number is meaningful
                let dropOffCount = stepCounts[dropOff]!
                let pct = Int(Double(dropOffCount) / Double(total) * 100)
                if pct >= 10 { // only show if statistically visible
                    parts.append("\(pct)% of your nudges stall at Step \(dropOff) without finishing. Start Step \(dropOff + 1) before closing the app and that number will drop.")
                }
            }
        }

        // Mood with lowest completion rate (need ≥2 entries for that mood)
        if parts.isEmpty {
            var worstMood: Mood? = nil
            var worstRate: Double = 2.0
            for mood in Mood.allCases {
                let subset = entries.filter { $0.mood == mood }
                guard subset.count >= 2 else { continue }
                let rate = completionRate(for: subset)
                if rate < worstRate { worstRate = rate; worstMood = mood }
            }
            if let mood = worstMood {
                let subset = entries.filter { $0.mood == mood }
                let completed = subset.filter(\.isCompleted).count
                let total2 = subset.count
                let rate = completionRate(for: subset)
                let pct = Int((rate * 100).rounded())
                parts.append("You finish only \(completed) of \(total2) nudges (\(pct)%) when you feel \(mood.displayName.lowercased()). Complete Step 1 the moment that mood appears, before the urge to avoid sets in.")
            }
        }

        // Fallback: overall completion rate
        if parts.isEmpty {
            let rate = completionRate(for: entries)
            let pct = Int((rate * 100).rounded())
            if rate < 0.5 {
                parts.append("Your overall completion rate is \(pct)%. Do Step 1 right after creating a nudge, while your intention is still fresh, and watch that number climb.")
            } else {
                parts.append("You complete \(pct)% of your nudges. Nudging at a consistent time each day will lock in that habit and push the rate even higher.")
            }
        }

        // ── Sentence 2: friction × energy ──────────────────────────────────
        var frictionCounts: [String: Int] = [:]
        for e in entries { frictionCounts[e.result.frictionLabel, default: 0] += 1 }
        let topFriction = frictionCounts.max(by: { $0.value < $1.value })

        var bestEnergy: EnergyLevel? = nil
        var bestEnergyRate: Double = -1
        for level in EnergyLevel.allCases {
            let subset = entries.filter { $0.energy == level }
            guard subset.count >= 2 else { continue }
            let rate = completionRate(for: subset)
            if rate > bestEnergyRate { bestEnergyRate = rate; bestEnergy = level }
        }

        if let friction = topFriction, friction.value >= 2, let energy = bestEnergy {
            let frictionPct = Int((Double(friction.value) / Double(total) * 100).rounded())
            let energyRate = Int((bestEnergyRate * 100).rounded())
            parts.append("\"\(friction.key)\" accounts for \(frictionPct)% of your friction labels and you complete \(energyRate)% of tasks at \(energy.displayName.lowercased()) energy, so schedule those sessions for your hardest tasks.")
        } else if let friction = topFriction, friction.value >= 2 {
            let frictionPct = Int((Double(friction.value) / Double(total) * 100).rounded())
            parts.append("\"\(friction.key)\" is your top blocker at \(frictionPct)% of nudges. Name it before opening a task and the resistance will feel smaller.")
        } else if let energy = bestEnergy {
            let energyRate = Int((bestEnergyRate * 100).rounded())
            parts.append("You complete \(energyRate)% of tasks at \(energy.displayName.lowercased()) energy. Reserve that window for the tasks you have been avoiding the longest.")
        }

        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    // MARK: - Grouping for History View

    struct DateGroup: Identifiable {
        let id: String
        let title: String
        let entries: [NudgeEntry]
    }

    var groupedEntries: [DateGroup] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        var todayEntries: [NudgeEntry] = []
        var yesterdayEntries: [NudgeEntry] = []
        var earlierEntries: [NudgeEntry] = []

        for entry in filteredEntries {
            if calendar.isDate(entry.createdAt, inSameDayAs: today) {
                todayEntries.append(entry)
            } else if calendar.isDate(entry.createdAt, inSameDayAs: yesterday) {
                yesterdayEntries.append(entry)
            } else {
                earlierEntries.append(entry)
            }
        }

        var groups: [DateGroup] = []
        if !todayEntries.isEmpty {
            groups.append(DateGroup(id: "today", title: "Today", entries: todayEntries))
        }
        if !yesterdayEntries.isEmpty {
            groups.append(DateGroup(id: "yesterday", title: "Yesterday", entries: yesterdayEntries))
        }
        if !earlierEntries.isEmpty {
            groups.append(DateGroup(id: "earlier", title: "Earlier", entries: earlierEntries))
        }
        return groups
    }
}
