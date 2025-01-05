import Foundation

struct LyricLine: Identifiable, Hashable {
    let id: String
    let text: String
    let time: Double
    
    init(text: String, time: Double) {
        self.id = UUID().uuidString
        self.text = text
        self.time = time
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: LyricLine, rhs: LyricLine) -> Bool {
        return lhs.id == rhs.id
    }
} 