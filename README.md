# Smart Flashcards

Smart Flashcards is an intelligent, adaptive flashcard system built entirely in **Swift**. 
It automatically adjusts the frequency of questions based on your performance—questions you struggle 
with appear more often, while ones you answer correctly appear less frequently.

## Features

- **Adaptive Learning:**  
  Focus on questions you get wrong more often and skip ones you’ve mastered.  

- **AI Assistant:**  
  Provides hints, explanations, and extra guidance to boost learning.  

- **Data Storage with Supabase:**  
  All flashcards, progress, and stats are securely stored and synced.

## Getting Started

### Prerequisites
- Xcode (latest version recommended)  
- Swift 5+  
- Supabase account  
- OpenAI account for AI assistance  

### Installation
1. Clone the repository:  
   ```bash
   git clone https://github.com/yourusername/smart-flashcards.git
   ```
2. Open the project in **Xcode**.  
3. Install dependencies using Swift Package Manager if needed.

### Configuration
1. **Replace API Keys**:  
   - Open `OpenAIService.swift` and replace the placeholder with your **OpenAI API key**.  
   - Open `SupabaseConfig.swift` and replace the placeholders with your **Supabase URL** and **anon key**.  

2. Ensure your `.env` or config files are updated if storing keys securely.

### Usage
1. Run the project in Xcode on a simulator or device.  
2. Add or import your flashcards.  
3. Start studying—the system adapts questions based on your answers and provides AI guidance.

## Contributing
Contributions welcome! Submit a pull request or open an issue with ideas or improvements.  

## License
MIT License

## Acknowledgements
- [Supabase](https://supabase.com)  
- OpenAI for AI assistant functionality
