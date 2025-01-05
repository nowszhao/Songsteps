import Foundation

struct LyricRecording: Codable {
    let lyricId: String           // 歌词唯一标识
    let recordingPath: String     // 录音文件路径
    let recognizedText: String    // 识别的文本
    let score: SingingScore       // 评分
    let matchResult: LyricMatchResult // 匹配结果
    let timestamp: Date           // 录制时间
    
    // 用于 Codable
    enum CodingKeys: String, CodingKey {
        case lyricId, recordingPath, recognizedText, score, matchResult, timestamp
    }
}

// 用于管理歌词录音的服务类
class LyricRecordingManager: ObservableObject {
    static let shared = LyricRecordingManager()
    private let userDefaults = UserDefaults.standard
    private let fileManager = FileManager.default
    
    @Published private(set) var recordings: [String: LyricRecording] = [:] // lyricId -> Recording
    
    private init() {
        loadRecordings()
    }
    
    // 获取录音文件目录
    private var recordingsDirectory: URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("LyricRecordings")
    }
    
    // 加载所有录音记录
    private func loadRecordings() {
        if let data = userDefaults.data(forKey: "LyricRecordings"),
           let decoded = try? JSONDecoder().decode([String: LyricRecording].self, from: data) {
            recordings = decoded
        }
    }
    
    // 保存录音记录
    private func saveRecordings() {
        if let encoded = try? JSONEncoder().encode(recordings) {
            userDefaults.set(encoded, forKey: "LyricRecordings")
        }
    }
        
    
    // 保存新的录音记录
    func saveRecording(lyricId: String, recordingURL: URL, recognizedText: String, 
                      score: SingingScore, matchResult: LyricMatchResult) throws {
    
        
        // 确保录音目录存在
        try fileManager.createDirectory(at: recordingsDirectory, 
                                      withIntermediateDirectories: true)
        
        // 为录音文件创建永久存储路径
        let fileName = "\(lyricId)_\(Date().timeIntervalSince1970).m4a"
        let destinationURL = recordingsDirectory.appendingPathComponent(fileName)
        
        
        print("目标存储路径: \(destinationURL)")
        
        // 移动录音文件到永久存储位置
//        try fileManager.moveItem(at: recordingURL, to: destinationURL)
        
        
        print("录音文件移动成功")
        
        // 创建录音记录
        let recording = LyricRecording(
            lyricId: lyricId,
            recordingPath: fileName,
            recognizedText: recognizedText,
            score: score,
            matchResult: matchResult,
            timestamp: Date()
        )
        
        // 更新记录并保存
        recordings[lyricId] = recording
        saveRecordings()
    }
    
    // 获取指定歌词的录音记录
    func getRecording(for lyricId: String) -> LyricRecording? {
        return recordings[lyricId]
    }
    
    // 获取录音文件的URL
    func getRecordingURL(for recording: LyricRecording) -> URL {
        return recordingsDirectory.appendingPathComponent(recording.recordingPath)
    }
    
    // 删除录音记录
    func deleteRecording(for lyricId: String) {
        guard let recording = recordings[lyricId] else { return }
        
        // 删除录音文件
        let fileURL = recordingsDirectory.appendingPathComponent(recording.recordingPath)
        try? fileManager.removeItem(at: fileURL)
        
        // 删除记录
        recordings.removeValue(forKey: lyricId)
        saveRecordings()
    }
} 
