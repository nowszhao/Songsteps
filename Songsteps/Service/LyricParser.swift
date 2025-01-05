import Foundation



struct LyricMetadata {
    let id: String
    let artist: String
    let title: String
    let album: String
}

class LyricParser {
    static func parse(_ lrcContent: String) -> (metadata: LyricMetadata?, lyrics: [LyricLine]) {
        let lines = lrcContent.components(separatedBy: .newlines)
        var lyrics: [LyricLine] = []
        var id = "", artist = "", title = "", album = ""
        
        for line in lines {
            if line.isEmpty { continue }
            
            // 解析元数据
            if line.hasPrefix("[id:") { id = line.replacingOccurrences(of: "[id:", with: "").replacingOccurrences(of: "]", with: "") }
            if line.hasPrefix("[ar:") { artist = line.replacingOccurrences(of: "[ar:", with: "").replacingOccurrences(of: "]", with: "") }
            if line.hasPrefix("[ti:") { title = line.replacingOccurrences(of: "[ti:", with: "").replacingOccurrences(of: "]", with: "") }
            if line.hasPrefix("[al:") { album = line.replacingOccurrences(of: "[al:", with: "").replacingOccurrences(of: "]", with: "") }
            
            // 解析歌词时间戳
            let pattern = "\\[(\\d{2}):(\\d{2})\\.(\\d{2})\\](.*)"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            let range = NSRange(location: 0, length: line.utf16.count)
            
            if let match = regex.firstMatch(in: line, options: [], range: range) {
                let minutesRange = match.range(at: 1)
                let secondsRange = match.range(at: 2)
                let millisecondsRange = match.range(at: 3)
                let textRange = match.range(at: 4)
                
                if let minutesRange = Range(minutesRange, in: line),
                   let secondsRange = Range(secondsRange, in: line),
                   let millisecondsRange = Range(millisecondsRange, in: line),
                   let textRange = Range(textRange, in: line) {
                    
                    let minutes = Double(line[minutesRange]) ?? 0
                    let seconds = Double(line[secondsRange]) ?? 0
                    let milliseconds = Double(line[millisecondsRange]) ?? 0
                    let text = String(line[textRange]).trimmingCharacters(in: .whitespaces)
                    
                    let timeInSeconds = minutes * 60 + seconds + milliseconds / 100
                    lyrics.append(LyricLine(text: text, time: timeInSeconds))
                }
            }
        }
        
        let metadata = LyricMetadata(id: id, artist: artist, title: title, album: album)
        return (metadata, lyrics)
    }
} 