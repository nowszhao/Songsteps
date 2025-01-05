import Foundation

struct WordMatch: Codable {
    let word: String
    let isMatched: Bool
    let recognizedWord: String?
}

struct LyricMatchResult: Codable {
    let originalWords: [WordMatch]
    let totalWords: Int
    let matchedWords: Int
    
    var matchPercentage: Double {
        guard totalWords > 0 else { return 0 }
        return Double(matchedWords) / Double(totalWords) * 100
    }
} 