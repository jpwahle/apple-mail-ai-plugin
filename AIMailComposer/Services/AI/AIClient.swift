import Foundation

protocol AIClient {
    var provider: AIProvider { get }

    /// Streams the assistant's reply as incremental text deltas. Each yielded
    /// chunk is new text to append to whatever has already been received.
    func stream(systemPrompt: String, userMessage: String) -> AsyncThrowingStream<String, Error>
}

extension AIClient {
    /// Fallback for callers that want the full reply as one string.
    func complete(systemPrompt: String, userMessage: String) async throws -> String {
        var result = ""
        for try await chunk in stream(systemPrompt: systemPrompt, userMessage: userMessage) {
            result += chunk
        }
        return result
    }
}

enum AIClientError: LocalizedError {
    case missingAPIKey(AIProvider)
    case requestFailed(String)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "No API key configured for \(provider.displayName). Add one in Settings."
        case .requestFailed(let msg):
            return "API request failed: \(msg)"
        case .invalidResponse(let msg):
            return "Invalid API response: \(msg)"
        }
    }
}

/// Shared parser for OpenAI-compatible SSE chunks ("data: {...}" lines, with
/// `[DONE]` sentinel). Emits deltas extracted from `choices[0].delta.content`.
enum OpenAICompatibleStream {
    static func parse(line: String) -> OpenAIStreamEvent? {
        guard line.hasPrefix("data: ") else { return nil }
        let payload = String(line.dropFirst("data: ".count))
        if payload == "[DONE]" { return .done }
        guard let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        if let choices = json["choices"] as? [[String: Any]],
           let delta = choices.first?["delta"] as? [String: Any],
           let content = delta["content"] as? String,
           !content.isEmpty {
            return .delta(content)
        }
        return nil
    }
}

enum OpenAIStreamEvent {
    case delta(String)
    case done
}
