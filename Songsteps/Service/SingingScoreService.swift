import Foundation

struct SingingScore: Codable {
    let textMatchScore: Int
    let completenessScore: Int
    let totalScore: Int
    let feedback: String
}

class SingingScoreService {
    // 计算文本相似度（Levenshtein 距离）
    private func calculateLevenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1 = Array(s1)
        let s2 = Array(s2)
        var matrix = Array(repeating: Array(repeating: 0, count: s2.count + 1), count: s1.count + 1)
        
        // 初始化第一行和第一列
        for i in 0...s1.count {
            matrix[i][0] = i
        }
        for j in 0...s2.count {
            matrix[0][j] = j
        }
        
        // 填充矩阵
        for i in 1...s1.count {
            for j in 1...s2.count {
                if s1[i-1] == s2[j-1] {
                    matrix[i][j] = matrix[i-1][j-1]
                } else {
                    matrix[i][j] = min(
                        matrix[i-1][j] + 1,    // 删除
                        matrix[i][j-1] + 1,    // 插入
                        matrix[i-1][j-1] + 1   // 替换
                    )
                }
            }
        }
        
        return matrix[s1.count][s2.count]
    }
    
    // 计算文本相似度得分
    private func calculateTextMatchScore(_ original: String, _ recognized: String) -> Int {
        let distance = calculateLevenshteinDistance(original, recognized)
        let maxLength = max(original.count, recognized.count)
        let similarity = 1.0 - (Double(distance) / Double(maxLength))
        return Int(similarity * 100)
    }
    
    // 计算完整度得分
    private func calculateCompletenessScore(_ original: String, _ recognized: String) -> Int {
        let originalLength = original.count
        let recognizedLength = recognized.count
        let lengthRatio = Double(recognizedLength) / Double(originalLength)
        
        // 如果识别文本长度超过原文的150%或少于50%，扣分更多
        if lengthRatio > 1.5 || lengthRatio < 0.5 {
            return max(0, Int(50 * lengthRatio))
        }
        
        return min(100, Int(100 * lengthRatio))
    }
    
    // 生成反馈信息
    private func generateFeedback(textMatchScore: Int, completenessScore: Int) -> String {
        var feedback = ""
        
        if textMatchScore < 60 {
            feedback += "发音准确度需要提高。"
        } else if textMatchScore < 80 {
            feedback += "发音还不错，继续加油！"
        } else {
            feedback += "发音非常准确！"
        }
        
        if completenessScore < 60 {
            feedback += "建议完整演唱整句歌词。"
        } else if completenessScore < 80 {
            feedback += "歌词完整度良好。"
        } else {
            feedback += "歌词完整度很好！"
        }
        
        return feedback
    }
    
    // 主评分函数
    func calculateScore(originalLyric: String, recognizedText: String) -> SingingScore {
        // 处理空字符串情况
        guard !originalLyric.isEmpty else {
            return SingingScore(
                textMatchScore: 0,
                completenessScore: 0,
                totalScore: 0,
                feedback: "无法评分：原始歌词为空"
            )
        }
        
        guard !recognizedText.isEmpty else {
            return SingingScore(
                textMatchScore: 0,
                completenessScore: 0,
                totalScore: 0,
                feedback: "未检测到语音，请重新尝试"
            )
        }
        
        // 预处理文本
        let processedOriginal = originalLyric.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let processedRecognized = recognizedText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 计算各项分数
        let textMatchScore = calculateTextMatchScore(processedOriginal, processedRecognized)
        let completenessScore = calculateCompletenessScore(processedOriginal, processedRecognized)
        
        // 计算总分（文本匹配占70%，完整度占30%）
        let totalScore = Int(Double(textMatchScore) * 0.7 + Double(completenessScore) * 0.3)
        
        // 生成反馈
        let feedback = generateFeedback(textMatchScore: textMatchScore, completenessScore: completenessScore)
        
        return SingingScore(
            textMatchScore: textMatchScore,
            completenessScore: completenessScore,
            totalScore: totalScore,
            feedback: feedback
        )
    }
    
    // 生成匹配结果
    func generateMatchResult(originalLyric: String, recognizedText: String) -> LyricMatchResult {
        // 处理空字符串情况
        guard !originalLyric.isEmpty else {
            return LyricMatchResult(
                originalWords: [],
                totalWords: 0,
                matchedWords: 0
            )
        }
        
        guard !recognizedText.isEmpty else {
            let originalWords = originalLyric.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
            let matchResults = originalWords.map { WordMatch(
                word: $0,
                isMatched: false,
                recognizedWord: nil
            )}
            
            return LyricMatchResult(
                originalWords: matchResults,
                totalWords: originalWords.count,
                matchedWords: 0
            )
        }
        
        // 分词处理（这里使用简单的空格分词，可以根据需要改进）
        let originalWords = originalLyric.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        let recognizedWords = recognizedText.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        var matchResults: [WordMatch] = []
        var matchedCount = 0
        
        for originalWord in originalWords {
            let processedOriginal = originalWord.lowercased()
            let isMatched = recognizedWords.contains { word in
                let processedWord = word.lowercased()
                return processedWord == processedOriginal
            }
            
            if isMatched {
                matchedCount += 1
            }
            
            matchResults.append(WordMatch(
                word: originalWord,
                isMatched: isMatched,
                recognizedWord: nil
            ))
        }
        
        return LyricMatchResult(
            originalWords: matchResults,
            totalWords: originalWords.count,
            matchedWords: matchedCount
        )
    }
} 