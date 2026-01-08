import SwiftUI
import Combine

enum AnswerType: String, Codable, CaseIterable {
    case reveal = "Reveal"
    case multipleChoice = "Multiple Choice"
    case textInput = "Text Input"
}

struct Deck: Identifiable, Hashable {
    let id: UUID
    var name: String
    var cards: [Flashcard]
    let createdAt: Date?

    init(id: UUID = UUID(), name: String, cards: [Flashcard] = [], createdAt: Date? = nil) {
        self.id = id
        self.name = name
        self.cards = cards
        self.createdAt = createdAt
    }
}

struct Flashcard: Identifiable, Hashable, Codable {
    let id: UUID
    var question: String
    var answer: String
    var topic: String
    var answerType: AnswerType
    var choices: [String]
    var stats: FlashcardStats

    init(
        id: UUID = UUID(),
        question: String,
        answer: String,
        topic: String = "General",
        answerType: AnswerType = .reveal,
        choices: [String] = [],
        stats: FlashcardStats = FlashcardStats()
    ) {
        self.id = id
        self.question = question
        self.answer = answer
        self.topic = topic.isEmpty ? "General" : topic
        self.answerType = answerType
        self.choices = choices
        self.stats = stats
    }
}

struct FlashcardStats: Codable, Hashable {
    var correctCount: Int
    var incorrectCount: Int
    var lastReviewed: Date?
    var streak: Int

    var totalAttempts: Int { correctCount + incorrectCount }
    var accuracy: Double {
        guard totalAttempts > 0 else { return 0 }
        return Double(correctCount) / Double(totalAttempts)
    }

    init(correctCount: Int = 0, incorrectCount: Int = 0, lastReviewed: Date? = nil, streak: Int = 0) {
        self.correctCount = correctCount
        self.incorrectCount = incorrectCount
        self.lastReviewed = lastReviewed
        self.streak = streak
    }
}

enum AppState {
    case deckSelection
    case onboarding
    case quiz
    case results
}

// MARK: - AI Chat Message

struct AIChatMessage: Identifiable {
    let id = UUID()
    let isUser: Bool
    let content: String
    let timestamp: Date

    init(isUser: Bool, content: String) {
        self.isUser = isUser
        self.content = content
        self.timestamp = Date()
    }
}

@MainActor
final class FlashcardViewModel: ObservableObject {
    // MARK: - Deck State
    @Published var decks: [Deck] = []
    @Published var currentDeck: Deck?
    @Published var isLoadingDecks: Bool = false
    @Published var errorMessage: String?

    // MARK: - Card State
    @Published var cards: [Flashcard] = []
    @Published var currentCard: Flashcard?
    @Published var isFlipped: Bool = false
    @Published var appState: AppState = .deckSelection
    @Published var hasAnswered: Bool = false
    @Published var lastAnswerCorrect: Bool? = nil

    @Published private(set) var sessionCorrect: Int = 0
    @Published private(set) var sessionTotal: Int = 0

    // MARK: - AI State
    @Published var isGeneratingCards: Bool = false
    @Published var isAIHelperLoading: Bool = false
    @Published var aiHelperResponse: String? = nil
    @Published var aiChatHistory: [AIChatMessage] = []

    private let supabase = SupabaseService.shared
    private let openAI = OpenAIService.shared

    var canStartQuiz: Bool {
        cards.count >= 1
    }

    var masteryProgress: Double {
        let totalAttempts = cards.map { $0.stats.totalAttempts }.reduce(0, +)
        guard totalAttempts > 0 else { return 0 }
        let totalCorrect = cards.map { $0.stats.correctCount }.reduce(0, +)
        return Double(totalCorrect) / Double(totalAttempts)
    }

    var sessionAccuracy: Double {
        guard sessionTotal > 0 else { return 0 }
        return Double(sessionCorrect) / Double(sessionTotal)
    }

    // MARK: - Deck Management

    func loadDecks() async {
        isLoadingDecks = true
        errorMessage = nil

        do {
            let deckRecords = try await supabase.fetchDecks()
            var loadedDecks: [Deck] = []

            for record in deckRecords {
                let cardRecords = try await supabase.fetchFlashcards(forDeckId: record.id)
                let cards = cardRecords.map { cardRecord in
                    Flashcard(
                        id: cardRecord.id,
                        question: cardRecord.question,
                        answer: cardRecord.answer,
                        topic: cardRecord.topic,
                        answerType: AnswerType(rawValue: cardRecord.answerType) ?? .reveal,
                        choices: cardRecord.choices,
                        stats: FlashcardStats(
                            correctCount: cardRecord.correctCount,
                            incorrectCount: cardRecord.incorrectCount,
                            lastReviewed: cardRecord.lastReviewed,
                            streak: cardRecord.streak
                        )
                    )
                }
                loadedDecks.append(Deck(
                    id: record.id,
                    name: record.name,
                    cards: cards,
                    createdAt: record.createdAt
                ))
            }

            decks = loadedDecks
        } catch {
            errorMessage = "Failed to load decks: \(error.localizedDescription)"
        }

        isLoadingDecks = false
    }

    func createDeck(name: String) async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        do {
            let record = try await supabase.createDeck(name: trimmedName)
            let newDeck = Deck(id: record.id, name: record.name, cards: [], createdAt: record.createdAt)
            decks.insert(newDeck, at: 0)
            selectDeck(newDeck)
        } catch {
            errorMessage = "Failed to create deck: \(error.localizedDescription)"
        }
    }

    func deleteDeck(_ deck: Deck) async {
        do {
            try await supabase.deleteDeck(id: deck.id)
            decks.removeAll { $0.id == deck.id }
            if currentDeck?.id == deck.id {
                currentDeck = nil
                cards = []
                appState = .deckSelection
            }
        } catch {
            errorMessage = "Failed to delete deck: \(error.localizedDescription)"
        }
    }

    func selectDeck(_ deck: Deck) {
        currentDeck = deck
        cards = deck.cards
        appState = .onboarding
    }

    func backToDeckSelection() {
        currentDeck = nil
        cards = []
        sessionCorrect = 0
        sessionTotal = 0
        currentCard = nil
        isFlipped = false
        hasAnswered = false
        lastAnswerCorrect = nil
        appState = .deckSelection
    }

    // MARK: - Card Management

    func addCard(
        question: String,
        answer: String,
        topic: String = "",
        answerType: AnswerType = .reveal,
        choices: [String] = []
    ) async {
        guard let deckId = currentDeck?.id else { return }

        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAnswer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedQuestion.isEmpty, !trimmedAnswer.isEmpty else { return }

        var finalChoices = choices.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if answerType == .multipleChoice {
            if !finalChoices.contains(trimmedAnswer) {
                finalChoices.append(trimmedAnswer)
            }
            finalChoices.shuffle()
        }

        do {
            let record = try await supabase.createFlashcard(
                deckId: deckId,
                question: trimmedQuestion,
                answer: trimmedAnswer,
                topic: trimmedTopic.isEmpty ? "General" : trimmedTopic,
                answerType: answerType.rawValue,
                choices: finalChoices
            )

            let newCard = Flashcard(
                id: record.id,
                question: record.question,
                answer: record.answer,
                topic: record.topic,
                answerType: answerType,
                choices: record.choices
            )
            cards.append(newCard)

            // Update the deck in decks array
            if let deckIndex = decks.firstIndex(where: { $0.id == deckId }) {
                decks[deckIndex].cards.append(newCard)
            }
        } catch {
            errorMessage = "Failed to add card: \(error.localizedDescription)"
        }
    }

    func removeCard(at offsets: IndexSet) async {
        for index in offsets {
            let card = cards[index]
            do {
                try await supabase.deleteFlashcard(id: card.id)
            } catch {
                errorMessage = "Failed to delete card: \(error.localizedDescription)"
                return
            }
        }
        cards.remove(atOffsets: offsets)

        // Update the deck in decks array
        if let deckId = currentDeck?.id, let deckIndex = decks.firstIndex(where: { $0.id == deckId }) {
            decks[deckIndex].cards = cards
        }
    }

    func removeCard(_ card: Flashcard) async {
        do {
            try await supabase.deleteFlashcard(id: card.id)
            cards.removeAll { $0.id == card.id }

            // Update the deck in decks array
            if let deckId = currentDeck?.id, let deckIndex = decks.firstIndex(where: { $0.id == deckId }) {
                decks[deckIndex].cards = cards
            }
        } catch {
            errorMessage = "Failed to delete card: \(error.localizedDescription)"
        }
    }

    // MARK: - Quiz Flow

    func startQuiz() {
        guard canStartQuiz else { return }
        sessionCorrect = 0
        sessionTotal = 0
        isFlipped = false
        hasAnswered = false
        lastAnswerCorrect = nil
        appState = .quiz
        selectNextCard()
    }

    func flipCard() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            isFlipped = true
        }
    }

    func markAnswer(isCorrect: Bool) {
        guard let currentCardID = currentCard?.id,
              let index = cards.firstIndex(where: { $0.id == currentCardID }) else { return }

        if isCorrect {
            cards[index].stats.correctCount += 1
            cards[index].stats.streak = cards[index].stats.streak >= 0 ? cards[index].stats.streak + 1 : 1
            sessionCorrect += 1
        } else {
            cards[index].stats.incorrectCount += 1
            cards[index].stats.streak = cards[index].stats.streak <= 0 ? cards[index].stats.streak - 1 : -1
        }
        cards[index].stats.lastReviewed = Date()
        sessionTotal += 1

        // Save stats to Supabase
        Task {
            await saveCardStats(cards[index])
        }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isFlipped = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.selectNextCard(excluding: currentCardID)
        }
    }

    func submitAnswer(_ userAnswer: String) {
        guard let currentCardID = currentCard?.id,
              let index = cards.firstIndex(where: { $0.id == currentCardID }) else { return }

        let correctAnswer = cards[index].answer.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let submittedAnswer = userAnswer.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        let isCorrect = correctAnswer == submittedAnswer

        if isCorrect {
            cards[index].stats.correctCount += 1
            cards[index].stats.streak = cards[index].stats.streak >= 0 ? cards[index].stats.streak + 1 : 1
            sessionCorrect += 1
        } else {
            cards[index].stats.incorrectCount += 1
            cards[index].stats.streak = cards[index].stats.streak <= 0 ? cards[index].stats.streak - 1 : -1
        }
        cards[index].stats.lastReviewed = Date()
        sessionTotal += 1

        // Save stats to Supabase
        Task {
            await saveCardStats(cards[index])
        }

        hasAnswered = true
        lastAnswerCorrect = isCorrect
    }

    private func saveCardStats(_ card: Flashcard) async {
        do {
            try await supabase.updateFlashcardStats(
                id: card.id,
                correctCount: card.stats.correctCount,
                incorrectCount: card.stats.incorrectCount,
                streak: card.stats.streak,
                lastReviewed: card.stats.lastReviewed
            )

            // Update the deck in decks array
            if let deckId = currentDeck?.id,
               let deckIndex = decks.firstIndex(where: { $0.id == deckId }),
               let cardIndex = decks[deckIndex].cards.firstIndex(where: { $0.id == card.id }) {
                decks[deckIndex].cards[cardIndex].stats = card.stats
            }
        } catch {
            errorMessage = "Failed to save card stats: \(error.localizedDescription)"
        }
    }

    func nextCard() {
        guard let currentCardID = currentCard?.id else { return }

        hasAnswered = false
        lastAnswerCorrect = nil

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isFlipped = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.selectNextCard(excluding: currentCardID)
        }
    }

    func endQuiz() {
        appState = .results
    }

    func restartQuiz() {
        for index in cards.indices {
            cards[index].stats = FlashcardStats()
        }
        startQuiz()
    }

    func backToOnboarding() {
        sessionCorrect = 0
        sessionTotal = 0
        currentCard = nil
        isFlipped = false
        hasAnswered = false
        lastAnswerCorrect = nil
        appState = .onboarding
    }

    // MARK: - Adaptive Card Selection

    private func selectNextCard(excluding excludedID: UUID? = nil) {
        guard !cards.isEmpty else {
            currentCard = nil
            return
        }

        let candidates = cards.filter { $0.id != excludedID }
        let selectionPool = candidates.isEmpty ? cards : candidates

        if let nextCard = selectWeightedCard(from: selectionPool) {
            currentCard = nextCard
        } else {
            currentCard = selectionPool.randomElement()
        }
    }

    private func selectWeightedCard(from candidates: [Flashcard]) -> Flashcard? {
        let weightedPairs = candidates.map { card -> (Flashcard, Double) in
            let weight = weight(for: card)
            return (card, max(weight, 0.1))
        }

        let totalWeight = weightedPairs.map { $0.1 }.reduce(0, +)
        guard totalWeight > 0 else { return nil }

        let target = Double.random(in: 0..<totalWeight)
        var cumulativeWeight: Double = 0

        for pair in weightedPairs {
            cumulativeWeight += pair.1
            if target <= cumulativeWeight {
                return pair.0
            }
        }

        return weightedPairs.last?.0
    }

    private func weight(for card: Flashcard) -> Double {
        let stats = card.stats

        let difficultyWeight = Double(stats.incorrectCount + 1) / Double(stats.correctCount + 1)

        let recencyWeight: Double
        if let lastReviewed = stats.lastReviewed {
            let minutesSinceReview = Date().timeIntervalSince(lastReviewed) / 60
            recencyWeight = min(max(minutesSinceReview / 2 + 0.5, 0.5), 4)
        } else {
            recencyWeight = 2.5
        }

        let noveltyWeight = stats.totalAttempts == 0 ? 1.5 : 1.0

        let accuracyBoost: Double
        if stats.totalAttempts > 0 && stats.accuracy < 0.5 {
            accuracyBoost = 2.0
        } else if stats.totalAttempts > 0 && stats.accuracy < 0.75 {
            accuracyBoost = 1.3
        } else {
            accuracyBoost = 1.0
        }

        let streakMultiplier: Double
        if stats.streak <= -2 {
            streakMultiplier = 1.0 + Double(abs(stats.streak)) * 0.5
        } else if stats.streak >= 2 {
            streakMultiplier = 1.0 / (1.0 + Double(stats.streak) * 0.3)
        } else {
            streakMultiplier = 1.0
        }

        return difficultyWeight * recencyWeight * noveltyWeight * accuracyBoost * streakMultiplier
    }

    // MARK: - AI Features

    func generateCardsWithAI(topic: String, count: Int = 5, difficulty: String = "medium") async {
        guard let deckId = currentDeck?.id else { return }

        isGeneratingCards = true
        errorMessage = nil

        do {
            // Pass deck name and existing questions for context
            let deckName = currentDeck?.name
            let existingQuestions = cards.map { $0.question }
            let generatedCards = try await openAI.generateFlashcards(
                topic: topic,
                count: count,
                difficulty: difficulty,
                deckName: deckName,
                existingQuestions: existingQuestions
            )

            for card in generatedCards {
                let record = try await supabase.createFlashcard(
                    deckId: deckId,
                    question: card.question,
                    answer: card.answer,
                    topic: card.topic,
                    answerType: AnswerType.reveal.rawValue,
                    choices: []
                )

                let newCard = Flashcard(
                    id: record.id,
                    question: record.question,
                    answer: record.answer,
                    topic: record.topic,
                    answerType: .reveal,
                    choices: []
                )
                cards.append(newCard)

                if let deckIndex = decks.firstIndex(where: { $0.id == deckId }) {
                    decks[deckIndex].cards.append(newCard)
                }
            }
        } catch {
            errorMessage = "Failed to generate cards: \(error.localizedDescription)"
        }

        isGeneratingCards = false
    }

    func explainCurrentCard() async {
        guard let card = currentCard else { return }

        isAIHelperLoading = true
        aiHelperResponse = nil

        do {
            let explanation = try await openAI.explainCard(question: card.question, answer: card.answer)
            aiHelperResponse = explanation
        } catch {
            errorMessage = "Failed to get explanation: \(error.localizedDescription)"
        }

        isAIHelperLoading = false
    }

    func askStudyHelper(question: String) async {
        isAIHelperLoading = true
        aiHelperResponse = nil

        // Add user message to chat history
        aiChatHistory.append(AIChatMessage(isUser: true, content: question))

        do {
            // Build context including deck name and current card
            var contextParts: [String] = []
            if let deckName = currentDeck?.name {
                contextParts.append("Deck: \(deckName)")
            }
            if let card = currentCard {
                contextParts.append("Current flashcard - Question: \(card.question), Answer: \(card.answer)")
            }
            let context = contextParts.isEmpty ? nil : contextParts.joined(separator: ". ")

            let response = try await openAI.askQuestion(question: question, context: context)
            aiHelperResponse = response

            // Add AI response to chat history
            aiChatHistory.append(AIChatMessage(isUser: false, content: response))
        } catch {
            errorMessage = "Failed to get response: \(error.localizedDescription)"
        }

        isAIHelperLoading = false
    }

    func clearAIHelperResponse() {
        aiHelperResponse = nil
    }
}
