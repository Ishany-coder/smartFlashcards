import Foundation

// MARK: - OpenAI Configuration

enum OpenAIConfig {
    static let apiKey = "REPLACE WITH YOUR OWN"
    static let baseURL = "https://api.openai.com/v1/chat/completions"
    static let model = "gpt-4o-mini" // Fast and cost-effective
}

// MARK: - Request/Response Models

struct OpenAIRequest: Encodable {
    let model: String
    let messages: [Message]
    let temperature: Double
    let max_tokens: Int

    struct Message: Encodable {
        let role: String
        let content: String
    }
}

struct OpenAIResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String
    }
}

struct GeneratedCard: Decodable {
    let question: String
    let answer: String
    let topic: String
}

struct GeneratedCardsResponse: Decodable {
    let cards: [GeneratedCard]
}

// MARK: - OpenAI Service

@MainActor
final class OpenAIService {
    static let shared = OpenAIService()

    private init() {}

    // MARK: - Generate Flashcards

    func generateFlashcards(
        topic: String,
        count: Int = 5,
        difficulty: String = "medium",
        deckName: String? = nil,
        existingQuestions: [String] = []
    ) async throws -> [GeneratedCard] {
        var prompt = """
        Generate \(count) flashcard questions about: \(topic)

        Difficulty level: \(difficulty)
        """

        if let deckName = deckName {
            prompt += "\n\nThis is for a deck called: \"\(deckName)\". Make sure the questions are relevant to this deck's theme."
        }

        if !existingQuestions.isEmpty {
            let existingList = existingQuestions.prefix(20).joined(separator: "\n- ")
            prompt += """

            IMPORTANT: The deck already has these questions, so DO NOT create duplicates or very similar questions:
            - \(existingList)

            Generate NEW and DIFFERENT questions that complement the existing ones.
            """
        }

        prompt += """

        Create educational flashcards that test understanding, not just memorization.
        Include a mix of conceptual and factual questions.

        Respond ONLY with valid JSON in this exact format (no markdown, no code blocks):
        {"cards":[{"question":"...","answer":"...","topic":"..."}]}

        Keep answers concise (1-2 sentences max).
        The topic field should be a short category label (1-2 words).
        """

        let response = try await sendRequest(prompt: prompt, temperature: 0.7, maxTokens: 1500)

        // Parse JSON response
        guard let jsonData = response.data(using: .utf8) else {
            throw OpenAIError.invalidResponse
        }

        let decoder = JSONDecoder()
        let cardsResponse = try decoder.decode(GeneratedCardsResponse.self, from: jsonData)
        return cardsResponse.cards
    }

    // MARK: - Explain Card

    func explainCard(question: String, answer: String) async throws -> String {
        let prompt = """
        A student is studying flashcards and needs help understanding this one:

        Question: \(question)
        Answer: \(answer)

        Please provide a clear, helpful explanation that:
        1. Explains WHY this is the correct answer
        2. Provides additional context or memory tips
        3. Gives a simple example if applicable

        Keep it concise but educational (2-3 short paragraphs max).
        """

        return try await sendRequest(prompt: prompt, temperature: 0.5, maxTokens: 500)
    }

    // MARK: - Ask Question (Study Helper)

    func askQuestion(question: String, context: String? = nil) async throws -> String {
        var prompt = "You are a helpful study assistant. "

        if let context = context {
            prompt += "The student is studying flashcards about: \(context). "
        }

        prompt += """

        Answer this question clearly and concisely:
        \(question)

        Provide a helpful, educational response. If it's a factual question, give the answer directly.
        If it's conceptual, explain it simply. Keep responses focused and under 3 paragraphs.
        """

        return try await sendRequest(prompt: prompt, temperature: 0.5, maxTokens: 600)
    }

    // MARK: - Private Helpers

    private func sendRequest(prompt: String, temperature: Double, maxTokens: Int) async throws -> String {
        guard let url = URL(string: OpenAIConfig.baseURL) else {
            throw OpenAIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(OpenAIConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody = OpenAIRequest(
            model: OpenAIConfig.model,
            messages: [
                OpenAIRequest.Message(role: "user", content: prompt)
            ],
            temperature: temperature,
            max_tokens: maxTokens
        )

        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("OpenAI Error: \(errorString)")
            }
            throw OpenAIError.apiError(statusCode: httpResponse.statusCode)
        }

        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)

        guard let content = openAIResponse.choices.first?.message.content else {
            throw OpenAIError.noContent
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Errors

enum OpenAIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int)
    case noContent
    case parsingError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from OpenAI"
        case .apiError(let statusCode):
            return "API error (status: \(statusCode))"
        case .noContent:
            return "No content in response"
        case .parsingError:
            return "Failed to parse AI response"
        }
    }
}
