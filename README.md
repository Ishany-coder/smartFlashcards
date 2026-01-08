# 🧠 Smart Flashcards

Smart Flashcards is an **adaptive, AI-powered flashcard system built entirely in Swift**.  
It’s designed to help you study smarter, not harder, by focusing on what you need to learn most.  
Whether you’re cramming for a test, learning a new skill, or just love self-improvement, this system adapts to **YOU**.  

---

## ✨ Features

- **🎯 Adaptive Learning**  
  Smart Flashcards tracks your performance and automatically adjusts which questions appear.  
  - Questions you struggle with show up more frequently.  
  - Questions you answer correctly often appear less.  
  - Say goodbye to wasted study time on things you already know!  

- **🤖 AI Assistant**  
  Need a hint or extra explanation? The built-in AI assistant can:  
  - Give hints for tricky questions  
  - Explain answers in detail  
  - Suggest related questions for deeper learning  

- **💾 Supabase Data Storage**  
  All your flashcards, progress, and statistics are securely stored using Supabase.  
  - Sync across devices  
  - Keep track of long-term learning progress  
  - Never lose your hard-earned study data  

---

## 🚀 Getting Started

### Prerequisites
- **Xcode** (latest version recommended)  
- **Swift 5+**  
- **Supabase account**  
- **OpenAI account** for AI-powered assistance  

### Installation
1. Clone the repository:  
   ```bash
   git clone https://github.com/yourusername/smart-flashcards.git
   ```
2. Open the project in **Xcode**.  
3. Install dependencies if using Swift Package Manager (SPM).  

### Configuration
1. **Replace API Keys**:  
   - Open `OpenAIService.swift` and replace the placeholder with your **OpenAI API key**.  
   - Open `SupabaseConfig.swift` and replace the placeholders with your **Supabase URL** and **anon key**.  

2. Optional: store your keys securely using `.env` or a secrets manager.  

---

## 🎓 How to Use

1. Run the project in **Xcode** on a simulator or device.  
2. Add your own flashcards or import existing sets.  
3. Start a study session! The system will:  
   - Show questions based on your past performance  
   - Give AI-powered hints or explanations when you need help  
   - Track and store your progress in Supabase  

4. Review stats to see which topics you’ve mastered and which need more practice.  

---

## 💡 Why Smart Flashcards?

Traditional flashcards treat every question the same, which can waste time. Smart Flashcards:  
- Focuses **exactly where you need it**  
- Adapts dynamically as you improve  
- Provides **AI-powered guidance** for tricky questions  
- Stores everything safely in the cloud for continuous learning  

It’s like having a personal tutor in your pocket! 🏆  

---

## 🤝 Contributing

Ideas? Bug fixes? Improvements? Contributions are welcome!  
- Submit a **pull request** with your changes  
- Open an **issue** if you have questions, suggestions, or feedback  

---

## 📣 Acknowledgements

- [Supabase](https://supabase.com) – for cloud storage & database support  
- OpenAI – for powering the AI assistant that makes learning smarter  

---

**Happy studying! 🚀📚**
