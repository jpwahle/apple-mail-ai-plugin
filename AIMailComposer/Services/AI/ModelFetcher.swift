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
            return AIModel(id: id, displayName: displayName, provider: .anthropic)
        }
        .sorted { $0.displayName < $1.displayName }
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

        // Filter to chat-capable models (gpt-*, o1-*, o3-*, chatgpt-*)
        let chatPrefixes = ["gpt-", "o1-", "o3-", "o4-", "chatgpt-"]

        return modelsArray.compactMap { obj -> AIModel? in
            guard let id = obj["id"] as? String else { return nil }
            let isChatModel = chatPrefixes.contains { id.hasPrefix($0) }
            guard isChatModel else { return nil }
            // Skip internal/instruct/audio/realtime variants
            let skipSuffixes = ["-instruct", "-audio", "-realtime", "-search"]
            if skipSuffixes.contains(where: { id.contains($0) }) { return nil }
            return AIModel(id: id, displayName: id, provider: .openai)
        }
        .sorted { $0.id < $1.id }
    }
}
