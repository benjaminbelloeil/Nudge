import SwiftUI

// MARK: - Energy Level

enum EnergyLevel: Int, Codable, CaseIterable, Sendable, Identifiable {
    case veryLow = 1, low = 2, medium = 3, high = 4, veryHigh = 5

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .veryLow: "Very Low"
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        case .veryHigh: "Very High"
        }
    }

    var shortName: String { "\(rawValue)" }

    var color: Color {
        switch self {
        case .veryLow: .red.opacity(0.7)
        case .low: .orange
        case .medium: .yellow
        case .high: .green
        case .veryHigh: .mint
        }
    }
}

// MARK: - Mood

enum Mood: String, Codable, CaseIterable, Sendable, Identifiable {
    case calm, anxious, overwhelmed, bored, frustrated
    case scattered, avoidant, tired, restless, neutral

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }

    var emoji: String {
        switch self {
        case .calm: "😌"; case .anxious: "😰"; case .overwhelmed: "😵‍💫"
        case .bored: "😑"; case .frustrated: "😤"; case .scattered: "🌀"
        case .avoidant: "🫣"; case .tired: "😴"; case .restless: "⚡"
        case .neutral: "😐"
        }
    }

    var color: Color {
        switch self {
        case .calm: .blue; case .anxious: .orange; case .overwhelmed: .red
        case .bored: .gray; case .frustrated: .pink; case .scattered: .purple
        case .avoidant: .indigo; case .tired: .brown; case .restless: .yellow
        case .neutral: .secondary
        }
    }
}

// MARK: - Nudge Source

enum NudgeSource: String, Codable, Sendable {
    case ai, appleIntelligence, fallback, manual
}

// MARK: - Navigation

enum NavigationDestination: Hashable {
    case newNudge, history, insights, nudgeDetail(UUID), paywall, customerCenter
}

// MARK: - Input Step

enum InputStep: Int, CaseIterable, Sendable, Comparable {
    case task = 0, energy = 1, mood = 2
    static func < (lhs: InputStep, rhs: InputStep) -> Bool { lhs.rawValue < rhs.rawValue }
}

// MARK: - Nudge Step

struct NudgeStep: Codable, Sendable, Equatable, Identifiable {
    let id: Int
    let title: String
    let action: String
}

// MARK: - Nudge Result

struct NudgeResult: Codable, Sendable, Equatable {
    let frictionLabel: String
    let steps: [NudgeStep]
    let ifStuck: String
    let successDefinition: String
}

// MARK: - Nudge Entry

struct NudgeEntry: Codable, Identifiable, Sendable {
    let id: UUID
    let taskDescription: String
    let energy: EnergyLevel
    let mood: Mood
    let result: NudgeResult
    let createdAt: Date
    var isCompleted: Bool
    var completedAt: Date?
    let source: NudgeSource
    var completedStepIds: Set<Int>

    init(id: UUID, taskDescription: String, energy: EnergyLevel, mood: Mood,
         result: NudgeResult, createdAt: Date, isCompleted: Bool,
         completedAt: Date?, source: NudgeSource, completedStepIds: Set<Int> = []) {
        self.id = id
        self.taskDescription = taskDescription
        self.energy = energy
        self.mood = mood
        self.result = result
        self.createdAt = createdAt
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.source = source
        self.completedStepIds = completedStepIds
    }

    // Custom decoder to handle missing completedStepIds in old data
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        taskDescription = try container.decode(String.self, forKey: .taskDescription)
        energy = try container.decode(EnergyLevel.self, forKey: .energy)
        mood = try container.decode(Mood.self, forKey: .mood)
        result = try container.decode(NudgeResult.self, forKey: .result)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        source = try container.decode(NudgeSource.self, forKey: .source)
        completedStepIds = try container.decodeIfPresent(Set<Int>.self, forKey: .completedStepIds) ?? []
    }
}

// MARK: - Preview Helpers

extension NudgeResult {
    static let preview = NudgeResult(
        frictionLabel: "Vague Overwhelm",
        steps: [
            NudgeStep(id: 1, title: "Open It",      action: "Open your notes app and navigate to the document for this task."),
            NudgeStep(id: 2, title: "Write One Line", action: "Type a single sentence describing what this task needs."),
            NudgeStep(id: 3, title: "Break It Down", action: "List 3 concrete sub-tasks beneath that sentence."),
            NudgeStep(id: 4, title: "Start the First", action: "Pick the smallest sub-task and work on it for 3 minutes."),
            NudgeStep(id: 5, title: "Save and Note", action: "Save your progress and write one line about what to do next.")
        ],
        ifStuck: "Just type the title of the task in a blank note.",
        successDefinition: "You have 3 sub-tasks written and started one."
    )
}

extension NudgeEntry {
    static let preview = NudgeEntry(
        id: UUID(), taskDescription: "Write the introduction for my research paper",
        energy: .low, mood: .overwhelmed, result: .preview,
        createdAt: Date(), isCompleted: false, completedAt: nil, source: .ai,
        completedStepIds: []
    )

    var stepsCompleted: Int {
        completedStepIds.count
    }

    var totalSteps: Int {
        result.steps.count
    }

    var progressFraction: Double {
        guard totalSteps > 0 else { return 0 }
        return Double(stepsCompleted) / Double(totalSteps)
    }
}
