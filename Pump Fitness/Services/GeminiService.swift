import Foundation

/// Simple Gemini / Generative Language API client.
/// Configure your API key in UserDefaults under key "GeminiAPIKey" or pass it from a secure store.
actor GeminiService {
    static let shared = GeminiService()
    private let session: URLSession = .shared
    
    /// Default endpoint — update model path to the exact model you want (e.g., gemini-* or text-bison).
    /// This uses the Google Generative Language REST shape (may need adjustment depending on model/version).
    var endpoint: String = "https://generativelanguage.googleapis.com/v1beta2/models/text-bison-001:generateText"

    /// Send prompt with optional structured context string. Context will be prepended to the prompt payload.
    func send(prompt: String, context: String? = nil, apiKey: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw NSError(domain: "GeminiService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing Gemini API Key. Set UserDefaults key 'GeminiAPIKey' or provide via UI."])
        }
        guard let url = URL(string: endpoint) else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var fullPrompt = ""
        if let ctx = context, !ctx.isEmpty {
            fullPrompt = "CONTEXT:\n\(ctx)\n\nUSER:\n\(prompt)"
        } else {
            fullPrompt = prompt
        }

        let body: [String: Any] = [
            "prompt": ["text": fullPrompt],
            "temperature": 0.2
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await session.data(for: req)

        // Try to parse a few common shapes returned by generative APIs.
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let candidates = json["candidates"] as? [[String: Any]], let first = candidates.first {
                if let output = first["output"] as? String { return output }
                if let content = first["content"] as? [[String: Any]] {
                    let parts = content.compactMap { $0["text"] as? String }
                    if !parts.isEmpty { return parts.joined(separator: "\n") }
                }
            }
            if let output = json["output"] as? String { return output }
            if let text = json["text"] as? String { return text }
        }

        // Fallback to raw string
        if let s = String(data: data, encoding: .utf8) { return s }
        return ""
    }
}
