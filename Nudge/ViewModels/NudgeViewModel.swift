import SwiftUI
import Combine

@MainActor
final class NudgeViewModel: ObservableObject {

    @Published var currentStep: InputStep = .task
    @Published var taskText: String = ""
    @Published var selectedEnergy: EnergyLevel = .medium
    @Published var selectedMood: Mood? = nil
    @Published var isGoingForward: Bool = true

    @Published var isGenerating: Bool = false
    @Published var currentResult: NudgeResult? = nil
    @Published var errorMessage: String? = nil
    @Published var currentSource: NudgeSource = .fallback

    @Published var completedStepIds: Set<Int> = []
    @Published var aiAvailable: Bool = false
    @Published var contentWarning: String? = nil
    @Published var isManualMode: Bool = false
    @Published var manualMissions: [String] = Array(repeating: "", count: 5)

    private let persistence: PersistenceManager
    private let fallbackService: FallbackService
    private let subscriptionManager: SubscriptionManager

    init(persistence: PersistenceManager = .shared, subscriptionManager: SubscriptionManager = .shared) {
        self.persistence = persistence
        self.fallbackService = FallbackService()
        self.subscriptionManager = subscriptionManager
        checkAIAvailability()
    }

    private func checkAIAvailability() {
        aiAvailable = AIService.isAvailable
    }

    var canAdvance: Bool {
        switch currentStep {
        case .task:
            return !taskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .energy: return true
        case .mood: return selectedMood != nil
        }
    }

    func advance() {
        guard canAdvance else { return }
        isGoingForward = true
        withAnimation(.easeInOut(duration: 0.3)) {
            switch currentStep {
            case .task: currentStep = .energy
            case .energy: currentStep = .mood
            case .mood: break
            }
        }
    }

    func goBack() {
        isGoingForward = false
        withAnimation(.easeInOut(duration: 0.3)) {
            switch currentStep {
            case .task: break
            case .energy: currentStep = .task
            case .mood: currentStep = .energy
            }
        }
    }

    func reset() {
        withAnimation {
            currentStep = .task
            taskText = ""
            selectedEnergy = .medium
            selectedMood = nil
            currentResult = nil
            errorMessage = nil
            completedStepIds = []
            isGoingForward = true
            isManualMode = false
            manualMissions = Array(repeating: "", count: 5)
        }
    }

    func toggleStep(_ stepId: Int) {
        guard let result = currentResult else { return }
        let steps = result.steps

        if completedStepIds.contains(stepId) {
            // Unchecking: also uncheck all subsequent steps
            completedStepIds.remove(stepId)
            for step in steps where step.id > stepId {
                completedStepIds.remove(step.id)
            }
        } else {
            // Checking: only allow if all previous steps are completed
            let allPreviousDone = steps.filter { $0.id < stepId }.allSatisfy { completedStepIds.contains($0.id) }
            guard allPreviousDone else { return }
            completedStepIds.insert(stepId)
        }
    }

    var completedStepCount: Int { completedStepIds.count }
    var totalStepCount: Int { currentResult?.steps.count ?? 0 }

    func generateNudge() async {
        guard let mood = selectedMood else { return }
        isGenerating = true
        errorMessage = nil
        contentWarning = nil

        // TIER 1: Gemini API (Pro only)
        if subscriptionManager.isProUser {
            do {
                let service = AIService()
                currentResult = try await service.generateNudge(
                    task: taskText, energy: selectedEnergy, mood: mood
                )
                currentSource = .ai
                isGenerating = false
                print("[NudgeVM] Tier 1 success: Gemini")
                return
            } catch AIServiceError.contentViolation {
                contentWarning = "Sorry, your input can't be used. Please remove any inappropriate words and try again."
                isGenerating = false
                currentResult = NudgeResult(
                    frictionLabel: "Error",
                    steps: [NudgeStep(id: 1, title: "Error", action: "No steps available.")],
                    ifStuck: "",
                    successDefinition: ""
                )
                currentSource = .ai
                return
            } catch {
                print("[NudgeVM] Tier 1 failed (Gemini): \(error)")
            }
        } else {
            print("[NudgeVM] Tier 1 skipped: Gemini requires Pro")
        }

        // TIER 2: Apple Intelligence (on-device)
        if FallbackService.isAvailable {
            do {
                currentResult = try await fallbackService.generateNudge(
                    task: taskText, energy: selectedEnergy, mood: mood
                )
                currentSource = .appleIntelligence
                isGenerating = false
                print("[NudgeVM] Tier 2 success: Apple Intelligence")
                return
            } catch {
                print("[NudgeVM] Tier 2 failed (Apple Intelligence): \(error)")
            }
        } else {
            print("[NudgeVM] Tier 2 skipped: Apple Intelligence not available")
        }

        // TIER 3: Manual mode — user creates their own 5 missions
        print("[NudgeVM] Tier 3: Manual mode")
        isGenerating = false
        isManualMode = true
    }

    var canSubmitManualMissions: Bool {
        manualMissions.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    func submitManualMissions() {
        let steps = manualMissions.enumerated().map { index, mission in
            NudgeStep(id: index + 1, title: "Mission \(index + 1)", action: mission.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        let taskName = taskText.trimmingCharacters(in: .whitespacesAndNewlines)
        currentResult = NudgeResult(
            frictionLabel: "Self Planned",
            steps: steps,
            ifStuck: "Pick the easiest mission and just start.",
            successDefinition: "Finish all 5 missions and make real progress on '\(taskName)'."
        )
        currentSource = .manual
        isManualMode = false
    }

    func saveForLater() {
        guard let result = currentResult, let mood = selectedMood else { return }
        let allDone = completedStepIds.count == result.steps.count && !result.steps.isEmpty
        persistence.addEntry(NudgeEntry(
            id: UUID(), taskDescription: taskText, energy: selectedEnergy,
            mood: mood, result: result, createdAt: Date(),
            isCompleted: allDone, completedAt: allDone ? Date() : nil,
            source: currentSource, completedStepIds: completedStepIds
        ))
    }

    func markComplete() {
        guard let result = currentResult, let mood = selectedMood else { return }
        let allDone = completedStepIds.count == result.steps.count && !result.steps.isEmpty
        persistence.addEntry(NudgeEntry(
            id: UUID(), taskDescription: taskText, energy: selectedEnergy,
            mood: mood, result: result, createdAt: Date(),
            isCompleted: allDone, completedAt: allDone ? Date() : nil,
            source: currentSource, completedStepIds: completedStepIds
        ))
        reset()
    }
}
