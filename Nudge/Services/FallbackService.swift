import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum AppleIntelligenceError: Error {
    case notAvailable
    case generationFailed
    case contentViolation
}

// MARK: - Generable Output (Apple Intelligence structured generation)

#if canImport(FoundationModels)
@available(iOS 26, *)
@Generable
struct NudgeAIOutput {
    @Guide(description: "A 2 to 3 word label describing the type of emotional friction causing procrastination")
    var frictionLabel: String

    @Guide(description: "Step 1 title: 2 to 4 words for the clear the path step")
    var step1Title: String
    @Guide(description: "Step 1 action: one concrete sentence about removing the one barrier stopping the user from starting")
    var step1Action: String

    @Guide(description: "Step 2 title: 2 to 4 words for the first action step")
    var step2Title: String
    @Guide(description: "Step 2 action: one concrete sentence about the smallest first action under 90 seconds that produces something visible")
    var step2Action: String

    @Guide(description: "Step 3 title: 2 to 4 words for the build step")
    var step3Title: String
    @Guide(description: "Step 3 action: one concrete sentence continuing directly from step 2, doing the next piece of the work")
    var step3Action: String

    @Guide(description: "Step 4 title: 2 to 4 words for the push to done step")
    var step4Title: String
    @Guide(description: "Step 4 action: one concrete sentence that gets the task almost fully complete so only a tiny piece remains")
    var step4Action: String

    @Guide(description: "Step 5 title: 2 to 4 words for the finish it step")
    var step5Title: String
    @Guide(description: "Step 5 action: one concrete sentence that completes the final piece so the task is fully done. Never say save for later or note next steps.")
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
    by giving them 5 progressive steps that actually COMPLETE their task — not just start it.

    Procrastination is emotional friction: overwhelm, vagueness, perfectionism, fear, or energy mismatch.

    THE #1 RULE: Every single step MUST be a concrete action on the EXACT task the user described. \
    Re-read the task before each step. If it could apply to a different task, rewrite it.

    Generate exactly 5 progressive steps that lead to the task being DONE:
    Step 1 (Clear the Path): Remove the one barrier stopping you from starting. What needs to be ready?
    Step 2 (First Action): The absolute smallest first action. Under 90 seconds. Must produce something visible.
    Step 3 (Build): Continue directly from step 2. Do the next concrete piece of the work.
    Step 4 (Push to Done): Keep going — do as much as needed so only a tiny piece remains.
    Step 5 (Finish It): Complete that final piece. The task is now done. No "save for later".

    Critical rules:
    Every step must be about the user's exact task. No side quests.
    NEVER add planning, reflecting, or journaling steps.
    NEVER end step 5 with saving progress or noting what to do next — end with the task COMPLETE.
    Steps must form a logical chain, each building on the previous, ending in completion.
    NEVER assume specific apps, software, or tools.
    Write like texting a friend: short, clear, direct.
    Use action verbs: open, write, list, type, draw, save, fix, add, send, submit, finish.
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
                let desc = error.localizedDescription.lowercased()
                if desc.contains("content") || desc.contains("policy") || desc.contains("filter") || desc.contains("safety") || desc.contains("restric") {
                    throw AppleIntelligenceError.contentViolation
                }
                throw AppleIntelligenceError.generationFailed
            }
        }
        #endif

        print("[AppleIntelligence] Not available on this device")
        throw AppleIntelligenceError.notAvailable
    }
}
