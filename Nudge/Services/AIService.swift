import Foundation

enum AIServiceError: Error {
    case contentViolation
    case networkError(String)
    case parseError
    case noResponse
    case rateLimited
}

@MainActor
final class AIService {

    // MARK: - Config
    private static let model = "gemini-2.5-flash-lite"

    private static var apiKey: String {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url),
              let key = dict["GEMINI_API_KEY"] as? String, !key.isEmpty else {
            fatalError("Missing GEMINI_API_KEY in Secrets.plist")
        }
        return key
    }

    private static let systemInstruction = """
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

    // MARK: - Generate with retry

    func generateNudge(task: String, energy: EnergyLevel, mood: Mood) async throws -> NudgeResult {
        let prompt = """
        Task the user is avoiding: "\(task)"
        Energy level: \(energy.rawValue)/5 (\(energy.displayName))
        Current mood: \(mood.displayName)

        Every step must be a direct action on "\(task)" only.

        Reply with ONLY this JSON, no markdown, no extra text:
        {
          "frictionLabel": "max 3 words",
          "step1Title": "2-4 words", "step1Action": "one sentence specific to the task",
          "step2Title": "2-4 words", "step2Action": "one sentence specific to the task",
          "step3Title": "2-4 words", "step3Action": "one sentence specific to the task",
          "step4Title": "2-4 words", "step4Action": "one sentence specific to the task",
          "step5Title": "2-4 words", "step5Action": "one sentence specific to the task",
          "ifStuck": "under 10 words",
          "successDefinition": "under 15 words, a tangible result"
        }
        """

        let requestBody: [String: Any] = [
            "system_instruction": ["parts": [["text": Self.systemInstruction]]],
            "contents": [["role": "user", "parts": [["text": prompt]]]],
            "generationConfig": [
                "response_mime_type": "application/json",
                "temperature": 0.7,
                "maxOutputTokens": 1024,
                "thinkingConfig": ["thinkingBudget": 0]
            ]
        ]

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(Self.model):generateContent") else {
            throw AIServiceError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.apiKey, forHTTPHeaderField: "x-goog-api-key")
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
                print("[AIService] Network error attempt \(attempt + 1): \(error.localizedDescription)")
                lastError = AIServiceError.networkError(error.localizedDescription)
                continue
            }

            print("[AIService] HTTP \(httpResponse.statusCode) attempt \(attempt + 1)")

            if httpResponse.statusCode == 429 {
                print("[AIService] Rate limited — skipping retries, using fallback")
                throw AIServiceError.rateLimited
            }

            guard httpResponse.statusCode == 200 else {
                let body = String(data: data, encoding: .utf8) ?? "(no body)"
                print("[AIService] Error body: \(body)")
                throw AIServiceError.networkError("HTTP \(httpResponse.statusCode)")
            }

            if let raw = String(data: data, encoding: .utf8) {
                print("[AIService] Raw response: \(raw.prefix(600))")
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("[AIService] Failed to parse outer JSON")
                throw AIServiceError.parseError
            }

            if let feedback = json["promptFeedback"] as? [String: Any],
               let reason = feedback["blockReason"] {
                print("[AIService] Prompt blocked: \(reason)")
                throw AIServiceError.contentViolation
            }

            guard let candidates = json["candidates"] as? [[String: Any]],
                  let first = candidates.first else {
                print("[AIService] No candidates in response")
                throw AIServiceError.noResponse
            }

            if let finishReason = first["finishReason"] as? String, finishReason == "SAFETY" {
                print("[AIService] Safety block on candidate")
                throw AIServiceError.contentViolation
            }

            guard let content = first["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let text = parts.first?["text"] as? String else {
                print("[AIService] Could not extract text from candidate")
                throw AIServiceError.parseError
            }

            let cleaned = text
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            print("[AIService] Cleaned JSON: \(cleaned.prefix(400))")

            guard let jsonData = cleaned.data(using: .utf8),
                  let result = try? JSONSerialization.jsonObject(with: jsonData) as? [String: String] else {
                print("[AIService] Inner JSON parse failed")
                throw AIServiceError.parseError
            }

            let label = result["frictionLabel"] ?? "nil"
            print("[AIService] Success — frictionLabel: \(label)")

            return NudgeResult(
                frictionLabel: result["frictionLabel"] ?? "Friction",
                steps: [
                    NudgeStep(id: 1, title: result["step1Title"] ?? "Step 1", action: result["step1Action"] ?? ""),
                    NudgeStep(id: 2, title: result["step2Title"] ?? "Step 2", action: result["step2Action"] ?? ""),
                    NudgeStep(id: 3, title: result["step3Title"] ?? "Step 3", action: result["step3Action"] ?? ""),
                    NudgeStep(id: 4, title: result["step4Title"] ?? "Step 4", action: result["step4Action"] ?? ""),
                    NudgeStep(id: 5, title: result["step5Title"] ?? "Step 5", action: result["step5Action"] ?? "")
                ],
                ifStuck: result["ifStuck"] ?? "Just open it.",
                successDefinition: result["successDefinition"] ?? "You made progress."
            )
        }

        print("[AIService] All retries exhausted")
        throw lastError
    }

    static var isAvailable: Bool { true }
}
