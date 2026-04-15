import Foundation

final class AnthropicClient: AIClient {
    let provider = AIProvider.anthropic
    private let apiKey: String
    private let model: String

    init(apiKey: String, model: String) {
        self.apiKey = apiKey
        self.model = model
    }

    func stream(systemPrompt: String, userMessage: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let url = URL(string: "https://api.anthropic.com/v1/messages")!
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                    request.setValue("application/json", forHTTPHeaderField: "content-type")

                    let body: [String: Any] = [
                        "model": model,
                        "max_tokens": 4096,
                        "stream": true,
                        "system": systemPrompt,
                        "messages": [
                            ["role": "user", "content": userMessage]
                        ],
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let http = response as? HTTPURLResponse else {
                        throw AIClientError.requestFailed("No HTTP response")
                    }
                    guard http.statusCode == 200 else {
                        var errorBody = ""
                        for try await line in bytes.lines { errorBody += line + "\n" }
                        throw AIClientError.requestFailed("HTTP \(http.statusCode): \(errorBody)")
                    }

                    // Anthropic SSE: named events with `data:` JSON payloads.
                    // We only care about `content_block_delta` events whose
                    // `delta.type` is `text_delta`.
                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst("data: ".count))
                        guard let data = payload.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let type = json["type"] as? String
                        else { continue }

                        if type == "content_block_delta",
                           let delta = json["delta"] as? [String: Any],
                           (delta["type"] as? String) == "text_delta",
                           let text = delta["text"] as? String {
                            continuation.yield(text)
                        } else if type == "message_stop" {
                            continuation.finish()
                            return
                        } else if type == "error",
                                  let err = json["error"] as? [String: Any],
                                  let msg = err["message"] as? String {
                            throw AIClientError.requestFailed(msg)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
