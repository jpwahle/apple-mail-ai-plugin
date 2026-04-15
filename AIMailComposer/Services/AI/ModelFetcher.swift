import Foundation

enum ModelFetcher {
    static func fetchAnthropicModels(apiKey: String) async throws -> [AIModel] {
        let url = URL(string: "https://api.anthropic.com/v1/models?limit=100")!
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AIClientError.requestFailed("Failed to fetch Anthropic models: \(body)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let modelsArray = json["data"] as? [[String: Any]]
        else {
            throw AIClientError.invalidResponse("Could not parse Anthropic models response")
        }

        return modelsArray.compactMap { obj -> AIModel? in
            guard let id = obj["id"] as? String,
                  let displayName = obj["display_name"] as? String
            else { return nil }
            // created_at is ISO 8601; try parsing for sort.
            let createdAt = (obj["created_at"] as? String).flatMap(parseISO8601)
            return AIModel(id: id, displayName: displayName, provider: .anthropic, createdAt: createdAt)
        }
    }

    static func fetchOpenAIModels(apiKey: String) async throws -> [AIModel] {
        let url = URL(string: "https://api.openai.com/v1/models")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AIClientError.requestFailed("Failed to fetch OpenAI models: \(body)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let modelsArray = json["data"] as? [[String: Any]]
        else {
            throw AIClientError.invalidResponse("Could not parse OpenAI models response")
        }

        let chatPrefixes = ["gpt-", "o1-", "o3-", "o4-", "chatgpt-"]

        return modelsArray.compactMap { obj -> AIModel? in
            guard let id = obj["id"] as? String else { return nil }
            let isChatModel = chatPrefixes.contains { id.hasPrefix($0) }
            guard isChatModel else { return nil }
            let skipSuffixes = ["-instruct", "-audio", "-realtime", "-search", "-transcribe", "-tts"]
            if skipSuffixes.contains(where: { id.contains($0) }) { return nil }
            let created = obj["created"] as? TimeInterval
            return AIModel(id: id, displayName: id, provider: .openai, createdAt: created)
        }
    }

    static func fetchGeminiModels(apiKey: String) async throws -> [AIModel] {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(apiKey)")!
        let request = URLRequest(url: url)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AIClientError.requestFailed("Failed to fetch Gemini models: \(body)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let modelsArray = json["models"] as? [[String: Any]]
        else {
            throw AIClientError.invalidResponse("Could not parse Gemini models response")
        }

        return modelsArray.compactMap { obj -> AIModel? in
            guard let name = obj["name"] as? String,
                  let displayName = obj["displayName"] as? String,
                  let supportedMethods = obj["supportedGenerationMethods"] as? [String],
                  supportedMethods.contains("generateContent")
            else { return nil }
            let id = name.hasPrefix("models/") ? String(name.dropFirst("models/".count)) : name
            // Gemini's v1beta /models does not expose a creation timestamp;
            // fall back to the version string as a coarse ordering hint.
            let createdAt = geminiRecencyHint(from: id)
            return AIModel(id: id, displayName: displayName, provider: .gemini, createdAt: createdAt)
        }
    }

    static func fetchOpenRouterModels(apiKey: String) async throws -> [AIModel] {
        let url = URL(string: "https://openrouter.ai/api/v1/models")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AIClientError.requestFailed("Failed to fetch OpenRouter models: \(body)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let modelsArray = json["data"] as? [[String: Any]]
        else {
            throw AIClientError.invalidResponse("Could not parse OpenRouter models response")
        }

        return modelsArray.compactMap { obj -> AIModel? in
            guard let id = obj["id"] as? String else { return nil }
            let displayName = (obj["name"] as? String) ?? id
            let created = obj["created"] as? TimeInterval
            // Skip non-chat modalities when the field is present.
            if let archi = obj["architecture"] as? [String: Any],
               let outputs = archi["output_modalities"] as? [String],
               !outputs.contains("text") {
                return nil
            }
            return AIModel(id: id, displayName: displayName, provider: .openrouter, createdAt: created)
        }
    }

    // MARK: - Helpers

    private static func parseISO8601(_ raw: String) -> TimeInterval? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: raw) { return d.timeIntervalSince1970 }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: raw) { return d.timeIntervalSince1970 }
        return nil
    }

    /// Parse the "2.5" / "1.5" / "1.0" version out of a Gemini model id and
    /// return an approximate release timestamp so newer families sort first.
    private static func geminiRecencyHint(from id: String) -> TimeInterval? {
        let lower = id.lowercased()
        // Ordered newest-first; the index becomes the recency rank.
        let families: [(String, TimeInterval)] = [
            ("2.5", 1_717_200_000), // ~Jun 2024
            ("2-5", 1_717_200_000),
            ("2.0", 1_702_944_000), // ~Dec 2024
            ("2-0", 1_702_944_000),
            ("1.5", 1_684_281_600), // ~May 2023
            ("1-5", 1_684_281_600),
            ("1.0", 1_670_457_600), // ~Dec 2022
            ("1-0", 1_670_457_600),
        ]
        for (key, ts) in families {
            if lower.contains(key) { return ts }
        }
        return nil
    }
}
