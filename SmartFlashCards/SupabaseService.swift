import Foundation
import Supabase

// MARK: - Database Models

struct DeckRecord: Codable, Identifiable {
    let id: UUID
    var name: String
    let createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct FlashcardRecord: Codable, Identifiable {
    let id: UUID
    let deckId: UUID
    var question: String
    var answer: String
    var topic: String
    var answerType: String
    var choices: [String]
    var correctCount: Int
    var incorrectCount: Int
    var streak: Int
    var lastReviewed: Date?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case deckId = "deck_id"
        case question, answer, topic
        case answerType = "answer_type"
        case choices
        case correctCount = "correct_count"
        case incorrectCount = "incorrect_count"
        case streak
        case lastReviewed = "last_reviewed"
        case createdAt = "created_at"
    }
}

// MARK: - Supabase Service

@MainActor
final class SupabaseService {
    static let shared = SupabaseService()

    private let client = SupabaseConfig.client

    private init() {}

    // MARK: - Deck Operations

    func fetchDecks() async throws -> [DeckRecord] {
        let response: [DeckRecord] = try await client
            .from("decks")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
        return response
    }

    func createDeck(name: String) async throws -> DeckRecord {
        let newDeck = ["name": name]
        let response: [DeckRecord] = try await client
            .from("decks")
            .insert(newDeck)
            .select()
            .execute()
            .value
        guard let deck = response.first else {
            throw SupabaseError.noDataReturned
        }
        return deck
    }

    func updateDeck(id: UUID, name: String) async throws {
        try await client
            .from("decks")
            .update(["name": name, "updated_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: id.uuidString)
            .execute()
    }

    func deleteDeck(id: UUID) async throws {
        try await client
            .from("decks")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Flashcard Operations

    func fetchFlashcards(forDeckId deckId: UUID) async throws -> [FlashcardRecord] {
        let response: [FlashcardRecord] = try await client
            .from("flashcards")
            .select()
            .eq("deck_id", value: deckId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value
        return response
    }

    func createFlashcard(
        deckId: UUID,
        question: String,
        answer: String,
        topic: String,
        answerType: String,
        choices: [String]
    ) async throws -> FlashcardRecord {
        let newCard: [String: AnyEncodable] = [
            "deck_id": AnyEncodable(deckId.uuidString),
            "question": AnyEncodable(question),
            "answer": AnyEncodable(answer),
            "topic": AnyEncodable(topic),
            "answer_type": AnyEncodable(answerType),
            "choices": AnyEncodable(choices),
            "correct_count": AnyEncodable(0),
            "incorrect_count": AnyEncodable(0),
            "streak": AnyEncodable(0)
        ]

        let response: [FlashcardRecord] = try await client
            .from("flashcards")
            .insert(newCard)
            .select()
            .execute()
            .value

        guard let card = response.first else {
            throw SupabaseError.noDataReturned
        }
        return card
    }

    func updateFlashcardStats(
        id: UUID,
        correctCount: Int,
        incorrectCount: Int,
        streak: Int,
        lastReviewed: Date?
    ) async throws {
        var updates: [String: AnyEncodable] = [
            "correct_count": AnyEncodable(correctCount),
            "incorrect_count": AnyEncodable(incorrectCount),
            "streak": AnyEncodable(streak)
        ]

        if let lastReviewed = lastReviewed {
            updates["last_reviewed"] = AnyEncodable(ISO8601DateFormatter().string(from: lastReviewed))
        }

        try await client
            .from("flashcards")
            .update(updates)
            .eq("id", value: id.uuidString)
            .execute()
    }

    func deleteFlashcard(id: UUID) async throws {
        try await client
            .from("flashcards")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}

// MARK: - Helper Types

struct AnyEncodable: Encodable {
    private let encode: (Encoder) throws -> Void

    init<T: Encodable>(_ value: T) {
        encode = { encoder in
            try value.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try encode(encoder)
    }
}

enum SupabaseError: Error, LocalizedError {
    case noDataReturned

    var errorDescription: String? {
        switch self {
        case .noDataReturned:
            return "No data was returned from the database"
        }
    }
}
