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

    func generate(from stats: StatsSnapshot, language: AppLanguage = .english) async -> String? {
        guard stats.hasEnoughData else { return nil }

        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            if SystemLanguageModel.default.isAvailable {
                return await generateWithAppleIntelligence(stats: stats, language: language)
            }
        }
        #endif

        return buildFallback(stats: stats, language: language)
    }

    // MARK: - Apple Intelligence path

    #if canImport(FoundationModels)
    @available(iOS 26, *)
    private func generateWithAppleIntelligence(stats: StatsSnapshot, language: AppLanguage = .english) async -> String? {
        let languageName: String
        switch language {
        case .english: languageName = "English"
        case .spanish: languageName = "Spanish"
        case .french:  languageName = "French"
        }
        let instructions = """
        You MUST write your entire response in \(languageName). Do not use any other language.
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
        - "Low Motivation blocks you in 40% of sessions. Before opening a task, write one sentence about why it matters today. It breaks the freeze."
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
                return buildFallback(stats: stats, language: language)
            }
            print("[InsightService] Apple Intelligence accepted: \(text.prefix(80))")
            return text
        } catch {
            print("[InsightService] Apple Intelligence failed: \(error.localizedDescription)")
            return buildFallback(stats: stats, language: language)
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

    private func buildFallback(stats: StatsSnapshot, language: AppLanguage = .english) -> String {
        switch language {
        case .english: return buildFallbackEnglish(stats: stats)
        case .spanish: return buildFallbackSpanish(stats: stats)
        case .french:  return buildFallbackFrench(stats: stats)
        }
    }

    private func buildFallbackEnglish(stats: StatsSnapshot) -> String {
        var parts: [String] = []
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
        if let friction = stats.topFrictionLabel, let frictionPct = stats.topFrictionPct,
           let energy = stats.bestEnergy, let energyPct = stats.bestEnergyCompletionPct {
            parts.append("\"\(friction)\" accounts for \(frictionPct)% of your friction labels and you complete \(energyPct)% of tasks at \(energy) energy, so reserve that window for your toughest sessions.")
        } else if let friction = stats.topFrictionLabel, let frictionPct = stats.topFrictionPct {
            parts.append("\"\(friction)\" is your top blocker at \(frictionPct)% of nudges. Name it before starting and the resistance will feel smaller.")
        } else if let energy = stats.bestEnergy, let energyPct = stats.bestEnergyCompletionPct {
            parts.append("You complete \(energyPct)% of tasks at \(energy) energy. Reserve that window for the tasks you have been avoiding the longest.")
        }
        return parts.joined(separator: " ")
    }

    private func buildFallbackSpanish(stats: StatsSnapshot) -> String {
        var parts: [String] = []
        if let step = stats.dropOffStep, let pct = stats.dropOffPct, pct >= 10 {
            parts.append("El \(pct)% de tus nudges se detienen en el Paso \(step). Empieza el Paso \(step + 1) antes de cerrar la app y ese patrón se romperá.")
        } else if let mood = stats.topMood, let moodPct = stats.topMoodCompletionPct, let moodTotal = stats.topMoodTotalCount {
            let moodCompleted = Int((Double(moodPct) / 100.0 * Double(moodTotal)).rounded())
            parts.append("Solo terminas \(moodCompleted) de \(moodTotal) nudges (\(moodPct)%) cuando te sientes \(mood). Completa el Paso 1 en el momento en que aparezca ese estado de ánimo, antes de que la evitación tome el control.")
        } else {
            let rate = stats.completionRatePct
            if rate < 50 {
                parts.append("Tu tasa de completado es del \(rate)%. Haz el Paso 1 justo después de crear un nudge mientras tu intención todavía está fresca.")
            } else {
                parts.append("Completas el \(rate)% de tus nudges. Hacer nudge a la misma hora cada día hará que esa tasa suba aún más.")
            }
        }
        if let friction = stats.topFrictionLabel, let frictionPct = stats.topFrictionPct,
           let energy = stats.bestEnergy, let energyPct = stats.bestEnergyCompletionPct {
            parts.append("\"\(friction)\" representa el \(frictionPct)% de tus etiquetas de fricción y completas el \(energyPct)% de las tareas con energía \(energy), así que reserva ese momento para tus sesiones más exigentes.")
        } else if let friction = stats.topFrictionLabel, let frictionPct = stats.topFrictionPct {
            parts.append("\"\(friction)\" es tu principal bloqueo en el \(frictionPct)% de los nudges. Nómbralo antes de empezar y la resistencia se sentirá menor.")
        } else if let energy = stats.bestEnergy, let energyPct = stats.bestEnergyCompletionPct {
            parts.append("Completas el \(energyPct)% de las tareas con energía \(energy). Reserva esa franja para las tareas que llevas más tiempo evitando.")
        }
        return parts.joined(separator: " ")
    }

    private func buildFallbackFrench(stats: StatsSnapshot) -> String {
        var parts: [String] = []
        if let step = stats.dropOffStep, let pct = stats.dropOffPct, pct >= 10 {
            parts.append("\(pct)% de tes nudges s'arrêtent à l'Étape \(step). Commence l'Étape \(step + 1) avant de fermer l'app et ce schéma se brisera.")
        } else if let mood = stats.topMood, let moodPct = stats.topMoodCompletionPct, let moodTotal = stats.topMoodTotalCount {
            let moodCompleted = Int((Double(moodPct) / 100.0 * Double(moodTotal)).rounded())
            parts.append("Tu ne termines que \(moodCompleted) de tes \(moodTotal) nudges (\(moodPct)%) quand tu te sens \(mood). Complète l'Étape 1 dès que cet état apparaît, avant que l'évitement prenne le dessus.")
        } else {
            let rate = stats.completionRatePct
            if rate < 50 {
                parts.append("Ton taux de complétion est de \(rate)%. Fais l'Étape 1 juste après avoir créé un nudge pendant que ton intention est encore fraîche.")
            } else {
                parts.append("Tu complètes \(rate)% de tes nudges. Faire un nudge à la même heure chaque jour fera encore monter ce taux.")
            }
        }
        if let friction = stats.topFrictionLabel, let frictionPct = stats.topFrictionPct,
           let energy = stats.bestEnergy, let energyPct = stats.bestEnergyCompletionPct {
            parts.append("\"\(friction)\" représente \(frictionPct)% de tes étiquettes de friction et tu complètes \(energyPct)% des tâches avec de l'énergie \(energy), donc réserve ce créneau pour tes sessions les plus exigeantes.")
        } else if let friction = stats.topFrictionLabel, let frictionPct = stats.topFrictionPct {
            parts.append("\"\(friction)\" est ton principal blocage dans \(frictionPct)% des nudges. Nomme-le avant de commencer et la résistance semblera moins grande.")
        } else if let energy = stats.bestEnergy, let energyPct = stats.bestEnergyCompletionPct {
            parts.append("Tu complètes \(energyPct)% des tâches avec de l'énergie \(energy). Réserve ce créneau pour les tâches que tu évites depuis le plus longtemps.")
        }
        return parts.joined(separator: " ")
    }
}
