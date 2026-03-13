import Foundation

enum AIServiceError: Error {
    case contentViolation
    case networkError(String)
    case parseError
    case noResponse
    case rateLimited
    case allModelsExhausted
}

@MainActor
final class AIService {

    // MARK: - Model Fallback Chain (ordered by preference)

    private static let models = [
        "gemini-2.5-flash-lite",
        "gemini-3.0-flash",
        "gemini-2.5-flash"
    ]

    // Worker proxy URL — key lives in Cloudflare, not in the app bundle
    private static var workerURL: String {
        return (Bundle.main.infoDictionary?["GEMINI_WORKER_URL"] as? String) ?? ""
    }

    // Shared secret — authorises the app to use the Worker (not the Gemini key itself)
    private static var appToken: String {
        return (Bundle.main.infoDictionary?["GEMINI_APP_TOKEN"] as? String) ?? ""
    }

    // MARK: - Dynamic System Prompt

    private static func systemInstruction(for count: Int, languageCode: String = "en") -> String {
        let languageDirective: String
        switch languageCode {
        case "es": languageDirective = "\n\nCRITICAL LANGUAGE RULE: Write ALL output entirely in Spanish. Every word of step titles, step actions, frictionLabel, ifStuck, and successDefinition MUST be in Spanish. No English words."
        case "fr": languageDirective = "\n\nCRITICAL LANGUAGE RULE: Write ALL output entirely in French. Every word of step titles, step actions, frictionLabel, ifStuck, and successDefinition MUST be in French. No English words."
        default: languageDirective = ""
        }
        let stepBlock: String
        switch count {
        case 4:
            stepBlock = """
            4 steps that complete the task — not pause it:
            1 (Clear the Path): Remove the one thing blocking you from starting right now.
            2 (First Action): The smallest action that directly moves this task forward. Under 90 seconds. Must produce something visible.
            3 (Build to Done): Continue — do the next logical piece until the task is substantially complete.
            4 (Finish It): Do whatever is left so this task is actually done. No saving for later.
            """
        case 5:
            stepBlock = """
            5 steps that complete the task — not pause it:
            1 (Clear the Path): Remove the one thing blocking you from starting right now.
            2 (First Action): The smallest action that directly moves this task forward. Under 90 seconds. Must produce something visible.
            3 (Build): Continue from step 2 — do the next concrete piece of the work.
            4 (Push to Done): Keep going — do as much as needed so only a small piece remains.
            5 (Finish It): Complete that final piece. This task is now done.
            """
        case 6:
            stepBlock = """
            6 steps that complete the task — not pause it:
            1 (Clear the Path): Remove the one thing blocking you from starting right now.
            2 (First Action): The smallest action that directly moves this task forward. Under 90 seconds. Must produce something visible.
            3 (Build): Continue from step 2 — do the next concrete piece of the work.
            4 (Push): Keep going — add one more real piece of work.
            5 (Almost Done): Do the remaining pieces so the task is essentially finished.
            6 (Finish It): Complete the final piece. This task is now done.
            """
        default:
            stepBlock = """
            5 steps that complete the task — not pause it:
            1 (Clear the Path): Remove the one thing blocking you from starting right now.
            2 (First Action): The smallest action that directly moves this task forward. Under 90 seconds. Must produce something visible.
            3 (Build): Continue from step 2 — do the next concrete piece of the work.
            4 (Push to Done): Keep going — do as much as needed so only a small piece remains.
            5 (Finish It): Complete that final piece. This task is now done.
            """
        }
        return """
        You are Nudge, a productivity assistant that breaks procrastination into \(count) progressive steps that COMPLETE the task.\(languageDirective)

        CONTENT MODERATION (check FIRST):
        If the task contains profanity, slurs, sexual content, violence, self-harm, threats, illegal activity, or hate speech, return ONLY: {"frictionLabel":"CONTENT_BLOCKED"}

        Every step MUST be a concrete action on the user's EXACT task. Re-read the task before each step.
        The steps must lead to finishing the task — not just starting it. Step 5 ends with the task DONE.
        NEVER write "save progress" or "note what to do next" as a final step — the goal is completion.

        \(stepBlock)

        Rules: task-specific only, no side quests. No planning/reflecting/journaling. Steps chain logically toward completion. No assumed tools. Texting tone: short, direct. Action verbs. Titles 2-4 words. Tangible success definition. No therapy talk, cliches, emojis, dashes, or hyphens. Match step size to energy level. Match tone to mood. Under 200 words total.
        """
    }

    // MARK: - Generate with Model Fallback

    func generateNudge(task: String, energy: EnergyLevel, mood: Mood) async throws -> NudgeResult {
        let languageCode = LanguageManager.shared.language.rawValue
        let jsonStepKeys = (1...5)
            .map { "\"step\($0)Title\":\"2-4 words\",\"step\($0)Action\":\"one sentence\"" }
            .joined(separator: ",")

        let prompt = """
        Task: "\(task)"
        Energy: \(energy.rawValue)/5 (\(energy.displayName))
        Mood: \(mood.displayName)

        All steps must directly act on "\(task)".

        Reply with ONLY this JSON:
        {"frictionLabel":"max 3 words",\(jsonStepKeys),"ifStuck":"under 10 words","successDefinition":"under 15 words, tangible result"}
        """

        let sysInstruction = Self.systemInstruction(for: 5, languageCode: languageCode)
        var lastError: Error = AIServiceError.networkError("Unknown")

        for model in Self.models {
            do {
                let result = try await callModel(model, prompt: prompt, systemInstruction: sysInstruction, stepCount: 5)
                return result
            } catch AIServiceError.rateLimited {
                print("[AIService] \(model) rate limited — trying next model")
                lastError = AIServiceError.rateLimited
                continue
            } catch AIServiceError.contentViolation {
                throw AIServiceError.contentViolation
            } catch {
                print("[AIService] \(model) failed: \(error) — trying next model")
                lastError = error
                continue
            }
        }

        print("[AIService] All models exhausted")
        throw lastError
    }

    // MARK: - Single Model Call (with retries)

    private func callModel(_ model: String, prompt: String, systemInstruction: String, stepCount: Int) async throws -> NudgeResult {
        guard let url = URL(string: "\(Self.workerURL)/v1beta/models/\(model):generateContent") else {
            throw AIServiceError.networkError("Invalid URL")
        }

        let requestBody: [String: Any] = [
            "system_instruction": ["parts": [["text": systemInstruction]]],
            "contents": [["role": "user", "parts": [["text": prompt]]]],
            "generationConfig": [
                "response_mime_type": "application/json",
                "temperature": 0.7,
                "maxOutputTokens": 1024,
                "thinkingConfig": ["thinkingBudget": 0]
            ],
            "safetySettings": [
                ["category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",   "threshold": "BLOCK_LOW_AND_ABOVE"],
                ["category": "HARM_CATEGORY_HATE_SPEECH",         "threshold": "BLOCK_LOW_AND_ABOVE"],
                ["category": "HARM_CATEGORY_HARASSMENT",          "threshold": "BLOCK_LOW_AND_ABOVE"],
                ["category": "HARM_CATEGORY_DANGEROUS_CONTENT",   "threshold": "BLOCK_LOW_AND_ABOVE"]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.appToken, forHTTPHeaderField: "X-App-Token")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 25

        var lastError: Error = AIServiceError.networkError("Unknown")

        for attempt in 0..<3 {
            if attempt > 0 {
                try await Task.sleep(nanoseconds: UInt64(attempt) * 2_000_000_000)
            }

            let data: Data
            let httpResponse: HTTPURLResponse
            do {
                let (d, r) = try await URLSession.shared.data(for: request)
                guard let h = r as? HTTPURLResponse else { throw AIServiceError.networkError("No HTTP response") }
                data = d
                httpResponse = h
            } catch let e as AIServiceError {
                throw e
            } catch {
                print("[AIService] [\(model)] Network error attempt \(attempt + 1): \(error.localizedDescription)")
                lastError = AIServiceError.networkError(error.localizedDescription)
                continue
            }

            print("[AIService] [\(model)] HTTP \(httpResponse.statusCode) attempt \(attempt + 1)")

            // Rate limited — bubble up immediately, outer loop picks next model
            if httpResponse.statusCode == 429 {
                throw AIServiceError.rateLimited
            }

            guard httpResponse.statusCode == 200 else {
                let body = String(data: data, encoding: .utf8) ?? "(no body)"
                print("[AIService] [\(model)] Error body: \(body)")
                lastError = AIServiceError.networkError("HTTP \(httpResponse.statusCode)")
                continue
            }

            if let raw = String(data: data, encoding: .utf8) {
                print("[AIService] [\(model)] Raw: \(raw.prefix(500))")
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw AIServiceError.parseError
            }

            if let feedback = json["promptFeedback"] as? [String: Any],
               let reason = feedback["blockReason"] {
                print("[AIService] [\(model)] Prompt blocked: \(reason)")
                throw AIServiceError.contentViolation
            }

            guard let candidates = json["candidates"] as? [[String: Any]],
                  let first = candidates.first else {
                throw AIServiceError.noResponse
            }

            if let finishReason = first["finishReason"] as? String, finishReason == "SAFETY" {
                throw AIServiceError.contentViolation
            }

            guard let content = first["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let text = parts.first?["text"] as? String else {
                throw AIServiceError.parseError
            }

            let cleaned = text
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard let jsonData = cleaned.data(using: .utf8),
                  let result = try? JSONSerialization.jsonObject(with: jsonData) as? [String: String] else {
                throw AIServiceError.parseError
            }

            let label = result["frictionLabel"] ?? "nil"
            print("[AIService] [\(model)] Success — frictionLabel: \(label)")
            if let usage = json["usageMetadata"] as? [String: Any] {
                let inputTokens  = usage["promptTokenCount"]     as? Int ?? 0
                let outputTokens = usage["candidatesTokenCount"] as? Int ?? 0
                print("[AIService] [\(model)] Tokens — input: \(inputTokens), output: \(outputTokens), total: \(inputTokens + outputTokens)")
            }

            if label == "CONTENT_BLOCKED" {
                throw AIServiceError.contentViolation
            }

            let steps = (1...stepCount).map { i in
                NudgeStep(id: i,
                          title: result["step\(i)Title"].flatMap { $0.isEmpty ? nil : $0 } ?? "Step \(i)",
                          action: result["step\(i)Action"] ?? "")
            }
            return NudgeResult(
                frictionLabel: result["frictionLabel"] ?? "Friction",
                steps: steps,
                ifStuck: result["ifStuck"] ?? "Just open it.",
                successDefinition: result["successDefinition"] ?? "You made progress."
            )
        }

        print("[AIService] [\(model)] All retries exhausted")
        throw lastError
    }

    static var isAvailable: Bool { true }
}
