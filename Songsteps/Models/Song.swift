import Foundation

struct Song: Identifiable, Codable {
    let id: String
    let title: String
    let artist: String
    let duration: Int
    let fileHash: String
    let mixSongId: String
    let hqFileHash: String?
    let sqFileHash: String?
    
    // 添加本地存储相关的属性
    var localMp3URL: URL?
    var localLrcURL: URL?
    var isDownloaded: Bool
    
    // 添加格式化后的时长计算属性
    var formattedDuration: String {
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // 自定义编码键
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case artist
        case duration
        case fileHash
        case mixSongId
        case hqFileHash
        case sqFileHash
        case localMp3URL
        case localLrcURL
        case isDownloaded
    }
    
    // 初始化方法
    init(id: String, title: String, artist: String, duration: Int, fileHash: String, mixSongId: String, hqFileHash: String?, sqFileHash: String?) {
        self.id = id
        self.title = title
        self.artist = artist
        self.duration = duration
        self.fileHash = fileHash
        self.mixSongId = mixSongId
        self.hqFileHash = hqFileHash
        self.sqFileHash = sqFileHash
        self.localMp3URL = nil
        self.localLrcURL = nil
        self.isDownloaded = false
    }
} 