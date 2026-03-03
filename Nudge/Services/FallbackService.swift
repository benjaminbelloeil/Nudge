import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum AppleIntelligenceError: Error {
    case notAvailable
    case generationFailed
}

// MARK: - Generable Output (Apple Intelligence structured generation)

#if canImport(FoundationModels)
@available(iOS 26, *)
@Generable
struct NudgeAIOutput {
    @Guide(description: "A 2 to 3 word label describing the type of emotional friction causing procrastination")
    var frictionLabel: String

    @Guide(description: "Step 1 title: 2 to 4 words for the setup step")
    var step1Title: String
    @Guide(description: "Step 1 action: one concrete sentence about removing barriers to starting the task")
    var step1Action: String

    @Guide(description: "Step 2 title: 2 to 4 words for the micro start step")
    var step2Title: String
    @Guide(description: "Step 2 action: one concrete sentence about the smallest first action under 90 seconds")
    var step2Action: String

    @Guide(description: "Step 3 title: 2 to 4 words for the build step")
    var step3Title: String
    @Guide(description: "Step 3 action: one concrete sentence continuing from step 2")
    var step3Action: String

    @Guide(description: "Step 4 title: 2 to 4 words for the push step")
    var step4Title: String
    @Guide(description: "Step 4 action: one concrete sentence going slightly further")
    var step4Action: String

    @Guide(description: "Step 5 title: 2 to 4 words for the close out step")
    var step5Title: String
    @Guide(description: "Step 5 action: one concrete sentence about saving progress and noting what to do next")
    var step5Action: String

    @Guide(description: "A short tip under 10 words for when the user feels stuck")
    var ifStuck: String

    @Guide(description: "A tangible result definition under 15 words")
    var successDefinition: String
}
#endif

// MARK: - Apple Intelligence Service

@MainActor
final class FallbackService {

    private let systemInstruction = """
    You are Nudge, a behavioral productivity assistant. You help people overcome procrastination \
    by giving them 5 tiny, progressive micro-steps that build momentum.

    Procrastination is emotional friction: overwhelm, vagueness, perfectionism, fear, or energy mismatch.

    THE #1 RULE: Every single step MUST be a concrete action on the EXACT task the user described. \
    Re-read the task before each step. If it could apply to a different task, rewrite it.

    Generate exactly 5 progressive steps:
    Step 1 (Set Up): Remove any barrier to starting. What needs to be open or ready?
    Step 2 (Micro-Start): The absolute smallest first action. Under 90 seconds. Must produce something visible.
    Step 3 (Build): Continue from step 2. Do a bit more of the same thing.
    Step 4 (Push): Go slightly further. Add one more real piece of work.
    Step 5 (Close Out): Save the session. Write down what to do next time.

    Critical rules:
    Every step must be about the user's exact task. No side quests.
    NEVER add planning, reflecting, or journaling steps.
    Steps must form a logical chain, each building on the previous.
    NEVER assume specific apps, software, or tools.
    Write like texting a friend: short, clear, direct.
    Use action verbs: open, write, list, type, draw, save, fix, add.
    Step titles must be 2 to 4 words.
    Success definition is a tangible result, not a feeling.
    No therapy language, no cliches, no emojis.
    NEVER use dashes or hyphens. Use commas, periods, or colons.
    Match step size to energy. Match tone to mood.
    Keep total output under 200 words.
    """

    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            return SystemLanguageModel.default.isAvailable
        }
        #endif
        return false
    }

    func generateNudge(task: String, energy: EnergyLevel, mood: Mood) async throws -> NudgeResult {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            print("[AppleIntelligence] Starting generation...")

            let session = LanguageModelSession(instructions: systemInstruction)

            let prompt = """
            Task the user is avoiding: "\(task)"
            Energy level: \(energy.rawValue)/5 (\(energy.displayName))
            Current mood: \(mood.displayName)

            Every step must be a direct action on "\(task)" only.
            """

            do {
                let response = try await session.respond(to: prompt, generating: NudgeAIOutput.self)
                let output = response.content
                print("[AppleIntelligence] Success — frictionLabel: \(output.frictionLabel)")

                return NudgeResult(
                    frictionLabel: output.frictionLabel,
                    steps: [
                        NudgeStep(id: 1, title: output.step1Title, action: output.step1Action),
                        NudgeStep(id: 2, title: output.step2Title, action: output.step2Action),
                        NudgeStep(id: 3, title: output.step3Title, action: output.step3Action),
                        NudgeStep(id: 4, title: output.step4Title, action: output.step4Action),
                        NudgeStep(id: 5, title: output.step5Title, action: output.step5Action)
                    ],
                    ifStuck: output.ifStuck,
                    successDefinition: output.successDefinition
                )
            } catch {
                print("[AppleIntelligence] Generation failed: \(error.localizedDescription)")
                throw AppleIntelligenceError.generationFailed
            }
        }
        #endif

        print("[AppleIntelligence] Not available on this device")
        throw AppleIntelligenceError.notAvailable
    }
}
