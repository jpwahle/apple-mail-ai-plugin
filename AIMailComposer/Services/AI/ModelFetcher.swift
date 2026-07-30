import Foundation

/// A model identified as popular from the OpenRouter public API.
struct TrendingModel: Sendable {
    let openRouterId: String   // e.g. "anthropic/claude-sonnet-4"
    let provider: AIProvider?  // Mapped provider, nil for non-major providers
    let slug: String           // Model name without provider prefix
}

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

    static func fetchLocalAIModels(baseURL: String) async throws -> [AIModel] {
        let base = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        guard let url = URL(string: "\(base)/v1/models") else {
            throw AIClientError.requestFailed("Invalid Local AI base URL: \(baseURL)")
        }
        let request = URLRequest(url: url)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AIClientError.requestFailed("Failed to fetch local models: \(body)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let modelsArray = json["data"] as? [[String: Any]]
        else {
            throw AIClientError.invalidResponse("Could not parse local models response")
        }

        return modelsArray.compactMap { obj -> AIModel? in
            guard let id = obj["id"] as? String else { return nil }
            let displayName = (obj["name"] as? String) ?? id
            let created = (obj["created"] as? Double) ?? (obj["created"] as? Int).map(Double.init)
            return AIModel(id: id, displayName: displayName, provider: .local, createdAt: created)
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

    static func fetchTrustedTokensModels(apiKey: String) async throws -> [AIModel] {
        let url = URL(string: "https://api.trustedtokens.eu/v1/models")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AIClientError.requestFailed("Failed to fetch TrustedTokens models: \(body)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let modelsArray = json["data"] as? [[String: Any]]
        else {
            throw AIClientError.invalidResponse("Could not parse TrustedTokens models response")
        }

        return modelsArray.compactMap { obj -> AIModel? in
            guard let id = obj["id"] as? String else { return nil }
            // OpenRouter-style entries expose a human-readable `name`; the
            // OpenAI-style ones only have `id`. Fall back gracefully.
            let displayName = (obj["name"] as? String) ?? id
            let created = obj["created"] as? TimeInterval
            // Skip non-text modalities when the field is present.
            if let archi = obj["architecture"] as? [String: Any],
               let outputs = archi["output_modalities"] as? [String],
               !outputs.contains("text") {
                return nil
            }
            return AIModel(id: id, displayName: displayName, provider: .trustedtokens, createdAt: created)
        }
    }

    /// Fetch models ranked by popularity signals from OpenRouter's public API
    /// (no auth needed). Returns an ordered list so the most popular/capable
    /// models come first. This is a dynamic signal — when new flagship models
    /// launch they appear automatically without any hardcoded lists.
    static func fetchTrendingModels() async -> [TrendingModel] {
        guard let url = URL(string: "https://openrouter.ai/api/v1/models") else { return [] }

        do {
            let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url))
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let models = json["data"] as? [[String: Any]]
            else { return [] }

            struct Scored {
                let model: TrendingModel
                let score: Double
            }

            var scored: [Scored] = []

            for obj in models {
                guard let id = obj["id"] as? String else { continue }

                // Skip free-tier and non-text models
                if id.hasSuffix(":free") { continue }
                if let arch = obj["architecture"] as? [String: Any],
                   let outputs = arch["output_modalities"] as? [String],
                   !outputs.contains("text") { continue }

                let parts = id.split(separator: "/", maxSplits: 1)
                let providerKey = parts.count > 1 ? String(parts[0]) : nil
                let slug = parts.count > 1 ? String(parts[1]) : id

                let provider: AIProvider?
                switch providerKey {
                case "anthropic": provider = .anthropic
                case "openai":    provider = .openai
                case "google":    provider = .gemini
                default:          provider = nil
                }

                var score: Double = 0

                // Pricing signal — flagship models command higher per-token prices
                if let pricing = obj["pricing"] as? [String: Any],
                   let raw = pricing["prompt"] as? String,
                   let price = Double(raw) {
                    score += min(price * 10_000_000, 50)
                }

                // Context length — larger context = more capable
                if let ctx = obj["context_length"] as? Int {
                    score += Double(min(ctx, 200_000)) / 10_000
                }

                // Recency — newer models are more relevant
                if let created = obj["created"] as? TimeInterval, created > 0 {
                    let ageDays = (Date().timeIntervalSince1970 - created) / 86_400
                    if ageDays < 60       { score += 25 }
                    else if ageDays < 180 { score += 15 }
                    else if ageDays < 365 { score += 8 }
                }

                // Skip non-chat variants entirely
                let lower = slug.lowercased()
                if lower.contains("embed") || lower.contains("tts") ||
                   lower.contains("image-") || lower.contains("moderation") { continue }
                if lower.contains("preview") || lower.contains("experimental") { score -= 8 }

                let tm = TrendingModel(openRouterId: id, provider: provider, slug: slug)
                scored.append(Scored(model: tm, score: score))
            }

            return scored
                .sorted { $0.score > $1.score }
                .prefix(30)
                .map(\.model)
        } catch {
            return []
        }
    }

    /// Check whether a direct-API model ID matches a trending slug from
    /// OpenRouter. Compares canonical base forms so date stamps, `-latest`,
    /// `-preview`, and version suffixes don't prevent a match.
    static func modelIDMatchesSlug(_ modelId: String, slug: String) -> Bool {
        let a = canonicalBase(modelId)
        let b = canonicalBase(slug)
        if a == b { return true }
        let (shorter, longer) = a.count <= b.count ? (a, b) : (b, a)
        guard longer.hasPrefix(shorter) else { return false }
        if shorter.count == longer.count { return true }
        let idx = longer.index(longer.startIndex, offsetBy: shorter.count)
        return longer[idx] == "-"
    }

    // MARK: - Helpers

    private static func canonicalBase(_ id: String) -> String {
        var s = id.lowercased()
        for suffix in ["-latest", "-preview", "-experimental", "-exp"] {
            if s.hasSuffix(suffix) { s = String(s.dropLast(suffix.count)); break }
        }
        if let r = s.range(of: #"-\d{4}-?\d{2}-?\d{2}$"#, options: .regularExpression) {
            s = String(s[..<r.lowerBound])
        }
        if let r = s.range(of: #"-\d{3}$"#, options: .regularExpression) {
            s = String(s[..<r.lowerBound])
        }
        return s
    }

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
