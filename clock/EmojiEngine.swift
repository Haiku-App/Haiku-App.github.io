import Foundation
import NaturalLanguage

struct EmojiEngine {
    static let shared = EmojiEngine()
    
    private let emojiMap: [String: String] = [
        // Academics & STEM
        "physics": "⚛️", "mechanics": "⚙️", "chemistry": "🧪", "thermodynamics": "🔥",
        "calculus": "∫", "math": "🧮", "study": "📚", "college": "🎓", "equilibrium": "⚖️",
        
        // App Dev & Finance
        "code": "👨‍💻", "ios": "📱", "swift": "🦅", "finance": "💸", "money": "💰",
        "budget": "📊", "accountability": "🤝", "streak": "🔥", "startup": "🚀",
        
        // Hobbies & Interests
        "chess": "♟️", "basketball": "🏀", "draw": "✏️", "sketch": "🎨",
        "haircut": "💈", "barber": "✂️", "fade": "💈", "manhwa": "📱",
        "novel": "📖", "read": "📚",
        
        // Routine & Lifestyle
        "morning": "🌅", "wakeup": "⏰", "routine": "📝", "run": "🏃",
        "workout": "💪", "gym": "🏋️", "meditate": "🧘", "sleep": "😴",
        
        // Food & Drink
        "eat": "🍽️", "coffee": "☕", "matcha": "🍵", "water": "💧", "cook": "👨‍🍳",
        
        // General Productivity
        "work": "💻", "write": "✍️", "email": "📧", "deadline": "⏰", "project": "📊"
    ]
    
    func suggestEmoji(for text: String) -> String {
        let lowercaseText = text.lowercased()
        
        // 1. Precise exact matches first
        if let emoji = emojiMap[lowercaseText] {
            return emoji
        }
        
        // 2. Setup Tagger and Word Embedding
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = lowercaseText
        
        // Load Apple's built-in English semantic word embeddings
        let embedding = NLEmbedding.wordEmbedding(for: .english)
        
        var bestEmoji = "✨" // Default fallback
        var closestDistance: NLDistance = 0.6 // Semantic threshold (0 is identical, 1 is unrelated)
        var foundExactLemma = false
        
        tagger.enumerateTags(in: lowercaseText.startIndex..<lowercaseText.endIndex, unit: .word, scheme: .lemma, options: [.omitPunctuation, .omitWhitespace]) { tag, range in
            let word = String(lowercaseText[range])
            let lemma = tag?.rawValue ?? word
            
            // 3. Exact Lemma Match (e.g., "running" -> "run")
            if let emoji = emojiMap[lemma] {
                bestEmoji = emoji
                foundExactLemma = true
                return false // Stop searching, exact match found
            }
            
            // 4. "Apple Intelligence" Semantic Matching
            if let embedding = embedding {
                for (key, emoji) in emojiMap {
                    // FIX: Changed from 'if let' to just 'let'
                    let distance = embedding.distance(between: lemma, and: key)
                    
                    if distance < closestDistance {
                        closestDistance = distance
                        bestEmoji = emoji
                    }
                }
            }
            
            // 5. Basic containment fallback
            if bestEmoji == "✨" {
                for (key, emoji) in emojiMap {
                    if word.contains(key) || lemma.contains(key) {
                        bestEmoji = emoji
                        return false
                    }
                }
            }
            
            return true // Continue to next word in the sentence
        }
        
        // If we found an exact lemma, return it immediately
        if foundExactLemma { return bestEmoji }
        
        // 6. Final safety fallback for full strings
        if bestEmoji == "✨" {
            for (key, emoji) in emojiMap {
                if lowercaseText.contains(key) {
                    return emoji
                }
            }
        }
        
        return bestEmoji
    }
}
