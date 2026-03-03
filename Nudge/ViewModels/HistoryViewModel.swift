import Foundation
import Combine

@MainActor
final class HistoryViewModel: ObservableObject {

    @Published var searchText: String = ""
    @Published var filterMood: Mood? = nil

    private let persistence: PersistenceManager
    private var cancellables = Set<AnyCancellable>()

    init(persistence: PersistenceManager = .shared) {
        self.persistence = persistence
        persistence.$entries
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
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
        var streak = 0
        var checkDate = today

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
