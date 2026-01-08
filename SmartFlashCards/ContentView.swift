import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var viewModel = FlashcardViewModel()

    var body: some View {
        Group {
            switch viewModel.appState {
            case .deckSelection:
                DeckSelectionView(viewModel: viewModel)
            case .onboarding:
                OnboardingView(viewModel: viewModel)
            case .quiz:
                QuizView(viewModel: viewModel)
            case .results:
                ResultsView(viewModel: viewModel)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.appState)
        .task {
            await viewModel.loadDecks()
        }
    }
}

// MARK: - Deck Selection View

struct DeckSelectionView: View {
    @ObservedObject var viewModel: FlashcardViewModel
    @State private var showingCreateDeck = false
    @State private var newDeckName = ""
    @State private var hoveredDeckId: UUID?

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(.systemIndigo).opacity(0.1), Color(.systemPurple).opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    if viewModel.isLoadingDecks {
                        loadingState
                    } else if viewModel.decks.isEmpty {
                        emptyState
                    } else {
                        decksList
                    }
                }
            }
            .navigationTitle("My Decks")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateDeck = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.indigo)
                    }
                }
            }
            .sheet(isPresented: $showingCreateDeck) {
                createDeckSheet
            }
            .alert("Error", isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.indigo)
            Text("Loading your decks...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.indigo.opacity(0.2), .purple.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 120, height: 120)

                Image(systemName: "rectangle.stack.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.indigo)
            }

            VStack(spacing: 8) {
                Text("No Decks Yet")
                    .font(.title2.weight(.bold))

                Text("Create your first flashcard deck\nto start studying")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showingCreateDeck = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.headline)
                    Text("Create Deck")
                        .font(.headline)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing)
                )
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .shadow(color: .indigo.opacity(0.4), radius: 10, y: 5)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding()
    }

    private var decksList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.decks) { deck in
                    DeckCard(deck: deck, isHovered: hoveredDeckId == deck.id) {
                        viewModel.selectDeck(deck)
                    } onDelete: {
                        Task { await viewModel.deleteDeck(deck) }
                    }
                    .onHover { isHovered in
                        withAnimation(.easeOut(duration: 0.2)) {
                            hoveredDeckId = isHovered ? deck.id : nil
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private var createDeckSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "rectangle.stack.badge.plus")
                        .font(.system(size: 40))
                        .foregroundStyle(.indigo)
                    Text("New Deck")
                        .font(.title2.weight(.bold))
                }
                .padding(.top, 20)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Deck Name")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    TextField("e.g., Spanish Vocabulary", text: $newDeckName)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .padding(12)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.indigo.opacity(0.3), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 24)

                Spacer()

                HStack(spacing: 12) {
                    Button("Cancel") {
                        newDeckName = ""
                        showingCreateDeck = false
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button {
                        Task {
                            await viewModel.createDeck(name: newDeckName)
                            newDeckName = ""
                            showingCreateDeck = false
                        }
                    } label: {
                        Text("Create")
                            .frame(minWidth: 80)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    .controlSize(.large)
                    .disabled(newDeckName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.bottom, 24)
            }
        }
        .frame(width: 380, height: 280)
    }
}

struct DeckCard: View {
    let deck: Deck
    let isHovered: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 50, height: 50)

                    Image(systemName: "rectangle.stack.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(deck.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    HStack(spacing: 12) {
                        Label("\(deck.cards.count) cards", systemImage: "square.stack")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let created = deck.createdAt {
                            Text(created, style: .date)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: .black.opacity(isHovered ? 0.15 : 0.08), radius: isHovered ? 12 : 6, y: isHovered ? 6 : 3)
            )
            .scaleEffect(isHovered ? 1.02 : 1)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Deck", systemImage: "trash")
            }
        }
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @ObservedObject var viewModel: FlashcardViewModel
    @State private var showingAddCard = false
    @State private var showingAIGenerate = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(.systemIndigo).opacity(0.08), Color(.systemPurple).opacity(0.04)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    if viewModel.cards.isEmpty {
                        emptyState
                    } else {
                        cardsList
                    }

                    bottomBar
                }

                // Loading overlay for AI generation
                if viewModel.isGeneratingCards {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                    AILoadingView(message: "Generating flashcards...")
                }
            }
            .navigationTitle(viewModel.currentDeck?.name ?? "Deck")
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button {
                        viewModel.backToDeckSelection()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Decks")
                        }
                        .foregroundStyle(.indigo)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAIGenerate = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                            Text("AI Generate")
                        }
                        .foregroundStyle(.purple)
                    }
                }
            }
            .sheet(isPresented: $showingAddCard) {
                AddCardSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showingAIGenerate) {
                AIGenerateSheet(viewModel: viewModel, isPresented: $showingAIGenerate)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.orange.opacity(0.2), .yellow.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 120, height: 120)

                Image(systemName: "plus.rectangle.on.rectangle")
                    .font(.system(size: 50))
                    .foregroundStyle(.orange)
            }

            VStack(spacing: 8) {
                Text("Add Your First Card")
                    .font(.title2.weight(.bold))

                Text("Add cards manually or use AI\nto generate them automatically")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Button {
                    showingAddCard = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text("Add Card")
                    }
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .shadow(color: .orange.opacity(0.4), radius: 10, y: 5)
                }
                .buttonStyle(.plain)

                Button {
                    showingAIGenerate = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                        Text("AI Generate")
                    }
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .shadow(color: .purple.opacity(0.4), radius: 10, y: 5)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
    }

    private var cardsList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(viewModel.cards) { card in
                    CardListItem(card: card) {
                        Task { await viewModel.removeCard(card) }
                    }
                }
            }
            .padding(20)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 16) {
            Divider()

            HStack(spacing: 10) {
                Button {
                    showingAddCard = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("Add")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(.indigo)

                Button {
                    showingAIGenerate = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text("AI")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(.purple)

                Button {
                    viewModel.startQuiz()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                        Text("Start Quiz")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .disabled(!viewModel.canStartQuiz)
            }
            .padding(.horizontal, 20)

            if !viewModel.cards.isEmpty {
                Text("\(viewModel.cards.count) card\(viewModel.cards.count == 1 ? "" : "s") ready to study")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 16)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.9))
    }
}

// MARK: - AI Generate Sheet

struct AIGenerateSheet: View {
    @ObservedObject var viewModel: FlashcardViewModel
    @Binding var isPresented: Bool

    @State private var topic = ""
    @State private var cardCount = 5
    @State private var difficulty = "medium"

    let difficulties = ["easy", "medium", "hard"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.purple.opacity(0.2), .pink.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 80, height: 80)
                        Image(systemName: "sparkles")
                            .font(.system(size: 35))
                            .foregroundStyle(.purple)
                    }
                    Text("AI Card Generator")
                        .font(.title2.weight(.bold))
                    Text("Enter a topic and AI will create flashcards for you")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 10)

                // Form
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Topic")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        TextField("e.g., Photosynthesis, World War 2, Python basics", text: $topic)
                            .textFieldStyle(.plain)
                            .font(.body)
                            .padding(12)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                            )
                    }

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Cards")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                            Picker("Count", selection: $cardCount) {
                                ForEach([3, 5, 8, 10], id: \.self) { num in
                                    Text("\(num)").tag(num)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Difficulty")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                            Picker("Difficulty", selection: $difficulty) {
                                ForEach(difficulties, id: \.self) { diff in
                                    Text(diff.capitalized).tag(diff)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // Buttons
                HStack(spacing: 12) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button {
                        Task {
                            await viewModel.generateCardsWithAI(topic: topic, count: cardCount, difficulty: difficulty)
                            if viewModel.errorMessage == nil {
                                isPresented = false
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                            Text("Generate")
                        }
                        .frame(minWidth: 100)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .controlSize(.large)
                    .disabled(topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.bottom, 24)
            }
        }
        .frame(width: 450, height: 420)
    }
}

struct CardListItem: View {
    let card: Flashcard
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(card.topic)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing))
                        )

                    Text(card.answerType.rawValue)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.15), in: Capsule())

                    Spacer()
                }

                Text(card.question)
                    .font(.body.weight(.medium))
                    .lineLimit(2)

                Text(card.answer)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Visible delete button
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .padding(10)
                    .background(
                        Circle()
                            .fill(Color.red.opacity(isHovered ? 0.15 : 0.08))
                    )
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0.6)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Add Card Sheet

struct AddCardSheet: View {
    @ObservedObject var viewModel: FlashcardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var question = ""
    @State private var answer = ""
    @State private var topic = ""
    @State private var answerType: AnswerType = .reveal
    @State private var choice1 = ""
    @State private var choice2 = ""
    @State private var choice3 = ""
    @State private var isSaving = false

    private var canSave: Bool {
        let hasQuestion = !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasAnswer = !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if answerType == .multipleChoice {
            let wrongChoices = [choice1, choice2, choice3]
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            return hasQuestion && hasAnswer && wrongChoices.count >= 1
        }

        return hasQuestion && hasAnswer
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What's the question?", text: $question, axis: .vertical)
                        .lineLimit(2...5)
                } header: {
                    Label("Question", systemImage: "questionmark.circle")
                }

                Section {
                    Picker("Answer Type", selection: $answerType) {
                        ForEach(AnswerType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Label("Answer Mode", systemImage: "hand.tap")
                } footer: {
                    switch answerType {
                    case .reveal:
                        Text("Swipe right if correct, left if wrong")
                    case .multipleChoice:
                        Text("Choose from multiple options")
                    case .textInput:
                        Text("Type the answer (case-insensitive)")
                    }
                }

                Section {
                    TextField("Correct answer", text: $answer, axis: .vertical)
                        .lineLimit(2...5)
                } header: {
                    Label("Correct Answer", systemImage: "checkmark.circle")
                }

                if answerType == .multipleChoice {
                    Section {
                        TextField("Wrong choice 1", text: $choice1)
                        TextField("Wrong choice 2 (optional)", text: $choice2)
                        TextField("Wrong choice 3 (optional)", text: $choice3)
                    } header: {
                        Label("Wrong Choices", systemImage: "xmark.circle")
                    }
                }

                Section {
                    TextField("e.g., Math, History, Science", text: $topic)
                } header: {
                    Label("Topic", systemImage: "tag")
                }
            }
            .navigationTitle("New Card")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Button("Add") { saveCard() }
                            .disabled(!canSave)
                    }
                }
            }
        }
        .frame(minWidth: 420, minHeight: 500)
    }

    private func saveCard() {
        isSaving = true
        var choices: [String] = []
        if answerType == .multipleChoice {
            choices = [choice1, choice2, choice3]
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }

        Task {
            await viewModel.addCard(
                question: question,
                answer: answer,
                topic: topic,
                answerType: answerType,
                choices: choices
            )
            dismiss()
        }
    }
}

// MARK: - Quiz View

struct QuizView: View {
    @ObservedObject var viewModel: FlashcardViewModel
    @State private var textAnswer = ""
    @State private var showStudyHelper = false
    @State private var studyHelperQuestion = ""

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(.systemIndigo).opacity(0.06), Color(.systemPurple).opacity(0.03)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            HStack(spacing: 0) {
                // Main quiz content
                VStack(spacing: 0) {
                    // Header
                    QuizHeader(viewModel: viewModel)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)

                    Spacer()

                    // Card content
                    if let card = viewModel.currentCard {
                        switch card.answerType {
                        case .reveal:
                            SwipeableCardView(card: card, viewModel: viewModel)
                        case .multipleChoice:
                            MultipleChoiceCardView(card: card, viewModel: viewModel)
                        case .textInput:
                            TextInputCardView(card: card, viewModel: viewModel, textAnswer: $textAnswer)
                        }
                    }

                    Spacer()

                    // Bottom buttons
                    HStack(spacing: 16) {
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                showStudyHelper.toggle()
                                if showStudyHelper {
                                    viewModel.clearAIHelperResponse()
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                Text("AI Helper")
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(showStudyHelper ? .white : .purple)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(showStudyHelper ? Color.purple : Color.purple.opacity(0.15), in: Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            viewModel.endQuiz()
                        } label: {
                            Text("End Quiz")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.gray.opacity(0.1), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity)

                // AI Study Helper sidebar
                if showStudyHelper {
                    AIStudyHelperPanel(viewModel: viewModel, question: $studyHelperQuestion)
                        .frame(width: 320)
                        .transition(.move(edge: .trailing))
                }
            }
        }
    }
}

struct QuizHeader: View {
    @ObservedObject var viewModel: FlashcardViewModel

    var body: some View {
        VStack(spacing: 16) {
            // Title and score
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.currentDeck?.name ?? "Quiz")
                        .font(.title3.weight(.bold))
                    Text("\(viewModel.cards.count) cards")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Score badges
                HStack(spacing: 12) {
                    ScoreBadge(count: viewModel.sessionCorrect, isCorrect: true)
                    ScoreBadge(count: viewModel.sessionTotal - viewModel.sessionCorrect, isCorrect: false)
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * viewModel.masteryProgress, height: 8)
                        .animation(.spring(response: 0.4), value: viewModel.masteryProgress)
                }
            }
            .frame(height: 8)

            // Accuracy
            if viewModel.sessionTotal > 0 {
                Text("\(Int(viewModel.sessionAccuracy * 100))% accuracy")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.08), radius: 15, y: 5)
        )
    }
}

struct ScoreBadge: View {
    let count: Int
    let isCorrect: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.subheadline)
            Text("\(count)")
                .font(.headline.monospacedDigit())
        }
        .foregroundStyle(isCorrect ? .green : .red)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(isCorrect ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
        )
    }
}

// MARK: - Swipeable Card View (Quizlet-style)

struct SwipeableCardView: View {
    let card: Flashcard
    @ObservedObject var viewModel: FlashcardViewModel

    @State private var offset: CGSize = .zero
    @State private var rotation: Double = 0

    private let swipeThreshold: CGFloat = 100

    private var swipeProgress: CGFloat {
        min(abs(offset.width) / swipeThreshold, 1)
    }

    private var isSwipingRight: Bool {
        offset.width > 0
    }

    var body: some View {
        ZStack {
            // Feedback indicators
            HStack {
                // Left indicator (wrong)
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.15))
                        .frame(width: 80, height: 80)
                    Image(systemName: "xmark")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.red)
                }
                .opacity(offset.width < 0 ? Double(swipeProgress) : 0)
                .scaleEffect(offset.width < 0 ? 0.8 + swipeProgress * 0.4 : 0.8)

                Spacer()

                // Right indicator (correct)
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 80, height: 80)
                    Image(systemName: "checkmark")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.green)
                }
                .opacity(offset.width > 0 ? Double(swipeProgress) : 0)
                .scaleEffect(offset.width > 0 ? 0.8 + swipeProgress * 0.4 : 0.8)
            }
            .padding(.horizontal, 40)

            // The card
            FlashcardView(
                card: card,
                isFlipped: viewModel.isFlipped,
                swipeOffset: offset,
                onFlip: { viewModel.flipCard() }
            )
            .offset(offset)
            .rotationEffect(.degrees(rotation))
            .gesture(
                viewModel.isFlipped ?
                DragGesture()
                    .onChanged { gesture in
                        offset = gesture.translation
                        rotation = Double(gesture.translation.width / 20)
                    }
                    .onEnded { gesture in
                        if abs(gesture.translation.width) > swipeThreshold {
                            // Swipe completed
                            let isCorrect = gesture.translation.width > 0
                            withAnimation(.easeOut(duration: 0.3)) {
                                offset = CGSize(width: isCorrect ? 500 : -500, height: 0)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                viewModel.markAnswer(isCorrect: isCorrect)
                                offset = .zero
                                rotation = 0
                            }
                        } else {
                            // Snap back
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                offset = .zero
                                rotation = 0
                            }
                        }
                    }
                : nil
            )
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.isFlipped)

            // Swipe hint when flipped
            if viewModel.isFlipped && offset == .zero {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left")
                        Text("Wrong")
                        Text("|")
                            .foregroundStyle(.tertiary)
                        Text("Correct")
                        Image(systemName: "arrow.right")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.gray.opacity(0.1)))
                }
                .padding(.bottom, 20)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Multiple Choice Card View

struct MultipleChoiceCardView: View {
    let card: Flashcard
    @ObservedObject var viewModel: FlashcardViewModel
    @State private var selectedChoice: String? = nil

    var body: some View {
        VStack(spacing: 20) {
            questionCard
                .padding(.horizontal, 20)

            VStack(spacing: 10) {
                ForEach(card.choices, id: \.self) { choice in
                    choiceButton(choice)
                }
            }
            .padding(.horizontal, 20)

            if viewModel.hasAnswered {
                feedbackAndNext
                    .padding(.horizontal, 20)
            }
        }
    }

    private var questionCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text(card.topic)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing))
                    )

                Spacer()
            }

            Text(card.question)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(LinearGradient(colors: [.blue.opacity(0.3), .cyan.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
        )
    }

    private func choiceButton(_ choice: String) -> some View {
        let isSelected = selectedChoice == choice
        let isCorrect = choice.lowercased() == card.answer.lowercased()
        let showResult = viewModel.hasAnswered

        return Button {
            if !viewModel.hasAnswered {
                selectedChoice = choice
                viewModel.submitAnswer(choice)
            }
        } label: {
            HStack {
                Text(choice)
                    .font(.body)
                    .multilineTextAlignment(.leading)

                Spacer()

                if showResult && isSelected {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(isCorrect ? .green : .red)
                } else if showResult && isCorrect {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(backgroundColor(isCorrect: isCorrect, isSelected: isSelected, showResult: showResult))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(borderColor(isCorrect: isCorrect, isSelected: isSelected, showResult: showResult), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.hasAnswered)
        .animation(.easeOut(duration: 0.2), value: showResult)
    }

    private func backgroundColor(isCorrect: Bool, isSelected: Bool, showResult: Bool) -> Color {
        if showResult {
            if isCorrect { return Color.green.opacity(0.15) }
            else if isSelected { return Color.red.opacity(0.15) }
        }
        return Color(nsColor: .controlBackgroundColor)
    }

    private func borderColor(isCorrect: Bool, isSelected: Bool, showResult: Bool) -> Color {
        if showResult {
            if isCorrect { return .green }
            else if isSelected { return .red }
        }
        return Color.gray.opacity(0.2)
    }

    private var feedbackAndNext: some View {
        VStack(spacing: 14) {
            if let correct = viewModel.lastAnswerCorrect {
                HStack(spacing: 8) {
                    Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.title3)
                    Text(correct ? "Correct!" : "The answer is: \(card.answer)")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(correct ? .green : .red)
            }

            Button {
                selectedChoice = nil
                viewModel.nextCard()
            } label: {
                HStack {
                    Text("Next")
                    Image(systemName: "arrow.right")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
        }
    }
}

// MARK: - Text Input Card View

struct TextInputCardView: View {
    let card: Flashcard
    @ObservedObject var viewModel: FlashcardViewModel
    @Binding var textAnswer: String

    var body: some View {
        VStack(spacing: 20) {
            questionCard
                .padding(.horizontal, 20)

            VStack(spacing: 12) {
                TextField("Type your answer...", text: $textAnswer)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .padding(14)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.purple.opacity(0.3), lineWidth: 2)
                    )
                    .disabled(viewModel.hasAnswered)
                    .onSubmit {
                        if !viewModel.hasAnswered && !textAnswer.isEmpty {
                            viewModel.submitAnswer(textAnswer)
                        }
                    }

                if !viewModel.hasAnswered {
                    Button {
                        viewModel.submitAnswer(textAnswer)
                    } label: {
                        HStack {
                            Text("Submit")
                            Image(systemName: "paperplane.fill")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .disabled(textAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(.horizontal, 20)

            if viewModel.hasAnswered {
                feedbackAndNext
                    .padding(.horizontal, 20)
            }
        }
    }

    private var questionCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text(card.topic)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing))
                    )

                Spacer()
            }

            Text(card.question)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(LinearGradient(colors: [.purple.opacity(0.3), .pink.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
        )
    }

    private var feedbackAndNext: some View {
        VStack(spacing: 14) {
            if let correct = viewModel.lastAnswerCorrect {
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.title3)
                        Text(correct ? "Correct!" : "Incorrect")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(correct ? .green : .red)

                    if !correct {
                        Text("Answer: \(card.answer)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Button {
                textAnswer = ""
                viewModel.nextCard()
            } label: {
                HStack {
                    Text("Next")
                    Image(systemName: "arrow.right")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
        }
    }
}

// MARK: - Flashcard View

struct FlashcardView: View {
    let card: Flashcard
    let isFlipped: Bool
    var swipeOffset: CGSize = .zero
    var onFlip: () -> Void

    private var swipeProgress: CGFloat {
        min(abs(swipeOffset.width) / 100, 1)
    }

    private var borderColor: Color {
        if swipeOffset.width > 20 {
            return .green.opacity(0.3 + swipeProgress * 0.5)
        } else if swipeOffset.width < -20 {
            return .red.opacity(0.3 + swipeProgress * 0.5)
        }
        return isFlipped ? .green.opacity(0.3) : .indigo.opacity(0.3)
    }

    var body: some View {
        ZStack {
            cardFace(isAnswer: true)
                .rotation3DEffect(.degrees(isFlipped ? 0 : 180), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 1 : 0)

            cardFace(isAnswer: false)
                .rotation3DEffect(.degrees(isFlipped ? -180 : 0), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 0 : 1)
        }
        .onTapGesture {
            if !isFlipped {
                onFlip()
            }
        }
    }

    private func cardFace(isAnswer: Bool) -> some View {
        VStack(spacing: 20) {
            HStack {
                Text(card.topic)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                colors: isAnswer ? [.green, .mint] : [.indigo, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    )

                Spacer()

                Text(isAnswer ? "ANSWER" : "QUESTION")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text(isAnswer ? card.answer : card.question)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Spacer()

            if !isAnswer {
                HStack(spacing: 6) {
                    Image(systemName: "hand.tap")
                    Text("Tap to flip")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .frame(height: 320)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.12), radius: 25, y: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(borderColor, lineWidth: 3)
        )
    }
}

// MARK: - Results View

struct ResultsView: View {
    @ObservedObject var viewModel: FlashcardViewModel
    @State private var animateScore = false

    private var scorePercentage: Int {
        guard viewModel.sessionTotal > 0 else { return 0 }
        return Int((Double(viewModel.sessionCorrect) / Double(viewModel.sessionTotal)) * 100)
    }

    private var scoreMessage: String {
        switch scorePercentage {
        case 90...100: return "Outstanding!"
        case 70..<90: return "Great job!"
        case 50..<70: return "Good effort!"
        default: return "Keep practicing!"
        }
    }

    private var scoreGradient: [Color] {
        switch scorePercentage {
        case 90...100: return [.green, .mint]
        case 70..<90: return [.blue, .cyan]
        case 50..<70: return [.orange, .yellow]
        default: return [.red, .pink]
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [scoreGradient[0].opacity(0.1), scoreGradient[1].opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Score circle
                ZStack {
                    Circle()
                        .stroke(scoreGradient[0].opacity(0.2), lineWidth: 16)
                        .frame(width: 180, height: 180)

                    Circle()
                        .trim(from: 0, to: animateScore ? CGFloat(scorePercentage) / 100 : 0)
                        .stroke(
                            LinearGradient(colors: scoreGradient, startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 16, lineCap: .round)
                        )
                        .frame(width: 180, height: 180)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 4) {
                        Text("\(animateScore ? scorePercentage : 0)%")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                        Text(scoreMessage)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                // Stats
                VStack(spacing: 12) {
                    Text("Quiz Complete!")
                        .font(.title.weight(.bold))

                    if let deckName = viewModel.currentDeck?.name {
                        Text(deckName)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 24) {
                        StatItem(value: viewModel.sessionCorrect, label: "Correct", color: .green)
                        StatItem(value: viewModel.sessionTotal - viewModel.sessionCorrect, label: "Wrong", color: .red)
                        StatItem(value: viewModel.sessionTotal, label: "Total", color: .indigo)
                    }
                    .padding(.top, 8)
                }

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        viewModel.restartQuiz()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Try Again")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)

                    HStack(spacing: 12) {
                        Button {
                            viewModel.backToOnboarding()
                        } label: {
                            Text("Edit Deck")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            viewModel.backToDeckSelection()
                        } label: {
                            Text("All Decks")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                animateScore = true
            }
        }
    }
}

struct StatItem: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 60)
    }
}

// MARK: - AI Study Helper Panel

struct AIStudyHelperPanel: View {
    @ObservedObject var viewModel: FlashcardViewModel
    @Binding var question: String

    private func submitQuestion() {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !viewModel.isAIHelperLoading else { return }
        question = ""
        Task {
            await viewModel.askStudyHelper(question: q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                Text("AI Study Helper")
                    .font(.headline)
                Spacer()

                if !viewModel.aiChatHistory.isEmpty {
                    Button {
                        viewModel.aiChatHistory.removeAll()
                        viewModel.aiHelperResponse = nil
                    } label: {
                        Text("Clear")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Color.purple.opacity(0.1))

            Divider()

            // Content
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 16) {
                        // Quick explain button
                        if viewModel.currentCard != nil {
                            Button {
                                Task {
                                    await viewModel.explainCurrentCard()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundStyle(.yellow)
                                    Text("Explain this card")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(nsColor: .controlBackgroundColor))
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.isAIHelperLoading)
                        }

                        // Chat history
                        ForEach(viewModel.aiChatHistory) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }

                        // Loading indicator
                        if viewModel.isAIHelperLoading {
                            AIThinkingView()
                                .id("loading")
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.aiChatHistory.count) { _, _ in
                    if let lastMessage = viewModel.aiChatHistory.last {
                        withAnimation {
                            scrollProxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: viewModel.isAIHelperLoading) { _, isLoading in
                    if isLoading {
                        withAnimation {
                            scrollProxy.scrollTo("loading", anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Ask question input at bottom
            VStack(alignment: .leading, spacing: 8) {
                if let card = viewModel.currentCard {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle.fill")
                            .font(.caption2)
                        Text("Context: \(card.question.prefix(40))...")
                            .lineLimit(1)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                HStack {
                    TextField("Ask about this card...", text: $question)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .onSubmit {
                            submitQuestion()
                        }

                    Button {
                        submitQuestion()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.purple)
                    }
                    .buttonStyle(.plain)
                    .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isAIHelperLoading)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
            }
            .padding()
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 1),
            alignment: .leading
        )
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: AIChatMessage

    var body: some View {
        HStack {
            if message.isUser { Spacer() }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if !message.isUser {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(.purple)
                    }
                    Text(message.isUser ? "You" : "AI")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Text(message.content)
                    .font(.body)
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(message.isUser ? Color.indigo.opacity(0.15) : Color.purple.opacity(0.08))
                    )
            }
            .frame(maxWidth: 280, alignment: message.isUser ? .trailing : .leading)

            if !message.isUser { Spacer() }
        }
    }
}

// MARK: - AI Loading Views

struct AILoadingView: View {
    let message: String
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1
    @State private var dotCount = 0

    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var dots: String {
        String(repeating: ".", count: dotCount)
    }

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                // Outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.purple.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 30,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .scaleEffect(scale)

                // Rotating ring
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [.purple, .pink, .purple.opacity(0.3)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(rotation))

                // Inner icon
                Image(systemName: "sparkles")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .scaleEffect(scale)
            }

            VStack(spacing: 8) {
                Text(message)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Powered by AI\(dots)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 100)
            }
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .shadow(color: .purple.opacity(0.3), radius: 30)
        )
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 1).repeatForever()) {
                scale = 1.1
            }
        }
        .onReceive(timer) { _ in
            dotCount = (dotCount + 1) % 4
        }
    }
}

struct AIThinkingView: View {
    @State private var animatingDots = [false, false, false]

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 10, height: 10)
                        .scaleEffect(animatingDots[index] ? 1.3 : 0.7)
                        .opacity(animatingDots[index] ? 1 : 0.4)
                }
            }

            Text("AI is thinking...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.08))
        )
        .onAppear {
            animateDots()
        }
    }

    private func animateDots() {
        for index in 0..<3 {
            withAnimation(
                .easeInOut(duration: 0.4)
                .repeatForever()
                .delay(Double(index) * 0.15)
            ) {
                animatingDots[index] = true
            }
        }
    }
}

#Preview {
    ContentView()
}
