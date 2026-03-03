import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Insight Service

/// Generates a personalised procrastination insight using Apple Intelligence
/// when available, with a data-driven fallback for other devices.
@MainActor
final class InsightService {

    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            return SystemLanguageModel.default.isAvailable
        }
        #endif
        return false
    }

    // MARK: - Stats snapshot passed to the prompt

    struct StatsSnapshot {
        let totalNudges: Int
        let completionRatePct: Int          // 0–100

        let topMood: String?                // e.g. "overwhelmed"
        let topMoodCompletionPct: Int?      // completion % for that mood
        let topMoodTotalCount: Int?         // total entries for that mood

        let bestEnergy: String?             // e.g. "high"
        let bestEnergyCompletionPct: Int?   // completion % for that energy

        let topFrictionLabel: String?       // e.g. "Low Motivation"
        let topFrictionPct: Int?            // % of nudges with that label

        let dropOffStep: Int?               // most common step users stall at
        let dropOffPct: Int?                // % of all nudges that stall there

        var hasEnoughData: Bool { totalNudges >= 3 }
    }

    // MARK: - Generate

    func generate(from stats: StatsSnapshot) async -> String? {
        guard stats.hasEnoughData else { return nil }

        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            if SystemLanguageModel.default.isAvailable {
                return await generateWithAppleIntelligence(stats: stats)
            }
        }
        #endif

        return buildFallback(stats: stats)
    }

    // MARK: - Apple Intelligence path

    #if canImport(FoundationModels)
    @available(iOS 26, *)
    private func generateWithAppleIntelligence(stats: StatsSnapshot) async -> String? {
        let instructions = """
        You are a tough, data-driven behavioural coach in a procrastination app called Nudge.
        The user can already see their own stats on screen — do NOT restate them or explain what they mean.
        Your only job: identify the single most actionable change this person can make RIGHT NOW based on their weakest data point, and say it in 1–2 sentences.

        STRICT RULES — violating any of these means your output is wrong:
        • Never say "complete your steps", "finish your steps", "complete Step X", or anything about step completion — the user already knows steps exist.
        • Never say "based on your data", "based on your usage", "your data shows", or any phrase that references the data itself.
        • Never use the word "improve" or "improvement".
        • No bullet points, no dashes, no hyphens, no emojis.
        • Write in second person (you / your).
        • Under 40 words total.
        • Must reference at least one specific number from the stats.

        BAD examples (never output anything like these):
        - "Based on your usage data, you can improve your completion rate by finishing steps 1, 2, 3, and 4."
        - "To improve, focus on completing your nudge steps."
        - "Your data shows you should complete more steps to increase your completion rate."

        GOOD examples (this is the style and specificity required):
        - "You abandon 3 of every 10 tired-mood nudges before starting. Set a 2-minute timer the moment you open a nudge in that state and you will finish it."
        - "Low Motivation blocks you in 40% of sessions. Before opening a task, write one sentence about why it matters today — it breaks the freeze."
        """

        let prompt = buildPrompt(stats: stats)

        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt)
            let text = response.content
                .trimmingCharacters(in: .whitespacesAndNewlines)
            // Reject if the model still produced a generic non-answer
            let banned = ["complete your steps", "finish your steps", "based on your", "your data shows", "improve your completion"]
            let lowered = text.lowercased()
            guard !text.isEmpty, !banned.contains(where: { lowered.contains($0) }) else {
                print("[InsightService] Apple Intelligence rejected (generic output): \(text.prefix(80))")
                return buildFallback(stats: stats)
            }
            print("[InsightService] Apple Intelligence accepted: \(text.prefix(80))")
            return text
        } catch {
            print("[InsightService] Apple Intelligence failed: \(error.localizedDescription)")
            return buildFallback(stats: stats)
        }
    }
    #endif

    // MARK: - Prompt builder

    private func buildPrompt(stats: StatsSnapshot) -> String {
        var lines: [String] = [
            "User stats from the Nudge app:",
            "Total nudges created: \(stats.totalNudges)",
            "Overall completion rate: \(stats.completionRatePct)%"
        ]

        if let mood = stats.topMood, let moodPct = stats.topMoodCompletionPct {
            lines.append("Most procrastination-prone mood: \(mood) (completes only \(moodPct)% of nudges in that mood)")
        }
        if let energy = stats.bestEnergy, let energyPct = stats.bestEnergyCompletionPct {
            lines.append("Best energy level for finishing: \(energy) (\(energyPct)% completion rate)")
        }
        if let friction = stats.topFrictionLabel, let frictionPct = stats.topFrictionPct {
            lines.append("Most common friction type: \"\(friction)\" (appears in \(frictionPct)% of nudges)")
        }
        if let step = stats.dropOffStep, let pct = stats.dropOffPct {
            lines.append("Most common drop-off point: Step \(step) (\(pct)% of all nudges stall there)")
        }

        lines.append("")
        lines.append("Write 1 to 2 sentences of personalised advice based exactly on these numbers.")
        return lines.joined(separator: "\n")
    }

    // MARK: - Fallback (no Apple Intelligence)

    private func buildFallback(stats: StatsSnapshot) -> String {
        var parts: [String] = []

        // Sentence 1: strongest signal
        if let step = stats.dropOffStep, let pct = stats.dropOffPct, pct >= 10 {
            parts.append("\(pct)% of your nudges stall at Step \(step). Start Step \(step + 1) before closing the app and that pattern will break.")
        } else if let mood = stats.topMood, let moodPct = stats.topMoodCompletionPct, let moodTotal = stats.topMoodTotalCount {
            let moodCompleted = Int((Double(moodPct) / 100.0 * Double(moodTotal)).rounded())
            parts.append("You finish only \(moodCompleted) of \(moodTotal) nudges (\(moodPct)%) when you feel \(mood). Complete Step 1 the moment that mood appears, before avoidance takes over.")
        } else {
            let rate = stats.completionRatePct
            if rate < 50 {
                parts.append("Your completion rate is \(rate)%. Do Step 1 right after creating a nudge while your intention is still fresh.")
            } else {
                parts.append("You complete \(rate)% of your nudges. Nudging at the same time each day will push that rate even higher.")
            }
        }

        // Sentence 2: friction × energy
        if let friction = stats.topFrictionLabel,
           let frictionPct = stats.topFrictionPct,
           let energy = stats.bestEnergy,
           let energyPct = stats.bestEnergyCompletionPct {
            parts.append("\"\(friction)\" accounts for \(frictionPct)% of your friction labels and you complete \(energyPct)% of tasks at \(energy) energy, so reserve that window for your toughest sessions.")
        } else if let friction = stats.topFrictionLabel, let frictionPct = stats.topFrictionPct {
            parts.append("\"\(friction)\" is your top blocker at \(frictionPct)% of nudges. Name it before starting and the resistance will feel smaller.")
        } else if let energy = stats.bestEnergy, let energyPct = stats.bestEnergyCompletionPct {
            parts.append("You complete \(energyPct)% of tasks at \(energy) energy. Reserve that window for the tasks you have been avoiding the longest.")
        }

        return parts.joined(separator: " ")
    }
}
