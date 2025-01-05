import Foundation
import CryptoKit  // 添加 CryptoKit 导入以使用 MD5

class LocalMusicLibrary: ObservableObject {
    static let shared = LocalMusicLibrary()
    
    @Published private(set) var songs: [Song] = []
    private let userDefaults = UserDefaults.standard
    
    // 添加 cookie 属性
    private let cookie: String = "kg_mid=dfae4c22d680eb5b60469dceb345eb39; kg_dfid=0jH6v01soQfC3Xvgwh25dAOo; 5SING_TAG_20250102=_ST-1.STW-0.SC-0.PL-0.FX-0.ZF-0.ZC-0.XZ-0.DZ-0%7COM_ST-1.STW-0.SC-0.PL-0.FX-0.ZF-0.ZC-0.XZ-0.DZ-0; Hm_lvt_aedee6983d4cfc62f509129360d6bb3d=1735655112,1735675747,1735898866; HMACCOUNT=D46FC601062A4B51; kg_dfid_collect=d41d8cd98f00b204e9800998ecf8427e; kg_mid_temp=dfae4c22d680eb5b60469dceb345eb39; Hm_lpvt_aedee6983d4cfc62f509129360d6bb3d=1735909762"
    
    // 添加 headers 属性
    private var headers: [String: String] {
        [
            "accept": "*/*",
            "accept-language": "zh-CN,zh;q=0.9",
            "cookie": cookie,
            "referer": "https://www.kugou.com/",
            "sec-ch-ua": "\"Google Chrome\";v=\"129\"",
            "user-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36"
        ]
    }
    
    // 添加 getMid 方法
    private func getMid() -> String {
        let cookies = cookie.split(separator: ";")
        for cookie in cookies {
            let parts = cookie.split(separator: "=", maxSplits: 1)
            if parts.count == 2 && parts[0].trimmingCharacters(in: .whitespaces) == "kg_mid" {
                return String(parts[1])
            }
        }
        return ""
    }
    
    // 添加 getDfid 方法
    private func getDfid() -> String {
        let cookies = cookie.split(separator: ";")
        for cookie in cookies {
            let parts = cookie.split(separator: "=", maxSplits: 1)
            if parts.count == 2 && parts[0].trimmingCharacters(in: .whitespaces) == "kg_dfid" {
                return String(parts[1])
            }
        }
        return ""
    }
    
    private init() {
        loadSongs()
    }
    
    private var songsDirectory: URL {
        // 获取应用的 Documents 目录
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let songsDir = paths.appendingPathComponent("Songs", isDirectory: true)
        
        // 确保目录存在
        if !FileManager.default.fileExists(atPath: songsDir.path) {
            try? FileManager.default.createDirectory(at: songsDir, withIntermediateDirectories: true)
        }
        
        return songsDir
    }
    
    private func loadSongs() {
        if let data = userDefaults.data(forKey: "SavedSongs"),
           let decoded = try? JSONDecoder().decode([Song].self, from: data) {
            // 更新文件 URL 以匹配当前应用的 Documents 目录
            songs = decoded.map { song in
                var updatedSong = song
                if song.isDownloaded {
                    let fileName = "\(song.artist)_\(song.title)"
                    updatedSong.localMp3URL = songsDirectory.appendingPathComponent("\(fileName).mp3")
                    updatedSong.localLrcURL = songsDirectory.appendingPathComponent("\(fileName).lrc")
                    
                    // 验证文件是否存在
                    if let mp3URL = updatedSong.localMp3URL,
                       let lrcURL = updatedSong.localLrcURL,
                       FileManager.default.fileExists(atPath: mp3URL.path),
                       FileManager.default.fileExists(atPath: lrcURL.path) {
                        updatedSong.isDownloaded = true
                    } else {
                        updatedSong.isDownloaded = false
                        updatedSong.localMp3URL = nil
                        updatedSong.localLrcURL = nil
                    }
                }
                return updatedSong
            }
        }
    }
    
    private func saveSongs() {
        if let encoded = try? JSONEncoder().encode(songs) {
            userDefaults.set(encoded, forKey: "SavedSongs")
        }
    }
    
    func addSong(_ song: Song) {
        if !songs.contains(where: { $0.id == song.id }) {
            songs.append(song)
            saveSongs()
        }
    }
    
    func removeSong(_ song: Song) {
        songs.removeAll { $0.id == song.id }
        // 删除本地文件
        if let mp3URL = song.localMp3URL {
            try? FileManager.default.removeItem(at: mp3URL)
        }
        if let lrcURL = song.localLrcURL {
            try? FileManager.default.removeItem(at: lrcURL)
        }
        saveSongs()
    }
    
    func downloadSong(_ song: Song) async throws -> Song {
        print("开始下载歌曲: \(song.title) - \(song.artist)")
        
        // 确保目录存在
        try FileManager.default.createDirectory(at: songsDirectory, withIntermediateDirectories: true)
        print("歌曲目录: \(songsDirectory.path)")
        
        // 生成文件名（移除可能的非法字符）
        let safeArtist = song.artist.replacingOccurrences(of: "[\\/:*?\"<>|]", with: "_", options: .regularExpression)
        let safeTitle = song.title.replacingOccurrences(of: "[\\/:*?\"<>|]", with: "_", options: .regularExpression)
        let fileName = "\(safeArtist)_\(safeTitle)"
        
        let mp3URL = songsDirectory.appendingPathComponent("\(fileName).mp3")
        let lrcURL = songsDirectory.appendingPathComponent("\(fileName).lrc")
        
        // 检查文件是否已存在
        if FileManager.default.fileExists(atPath: mp3URL.path) {
            try FileManager.default.removeItem(at: mp3URL)
        }
        if FileManager.default.fileExists(atPath: lrcURL.path) {
            try FileManager.default.removeItem(at: lrcURL)
        }
        
        // 获取下载链接和歌词
        print("获取歌曲详情...")
        let (downloadURL, songInfo) = try await getMp3DownloadURL(songId: song.id)
        print("获取到下载链接: \(downloadURL)")
        
        // 打印歌曲详细信息
        if let timelength = songInfo.timelength {
            let duration = timelength / 1000 // 转换为秒
            let minutes = duration / 60
            let seconds = duration % 60
            print("歌曲时长: \(minutes):\(String(format: "%02d", seconds))")
        }
        if let filesize = songInfo.filesize {
            let filesizeMB = Double(filesize) / 1024 / 1024
            print("文件大小: \(String(format: "%.2f", filesizeMB))MB")
        }
        if let audioName = songInfo.audio_name {
            print("歌曲名称: \(audioName)")
        }
        if let authorName = songInfo.author_name {
            print("歌手名称: \(authorName)")
        }
        if songInfo.have_album == 1, let albumName = songInfo.album_name {
            print("专辑名称: \(albumName)")
        }
        
        // 下载歌曲
        print("开始下载MP3文件...")
        var request = URLRequest(url: downloadURL)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (mp3Data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            print("MP3下载响应状态码: \(httpResponse.statusCode)")
        }
        print("MP3文件大小: \(mp3Data.count / 1024)KB")
        
        // 保存MP3文件
        try mp3Data.write(to: mp3URL, options: .atomic)
        print("MP3文件保存成功")
        
        // 保存歌词（如果有）
        if let lyrics = songInfo.lyrics {
            print("发现歌词，开始保存...")
            try lyrics.write(to: lrcURL, atomically: true, encoding: .utf8)
            print("歌词保存成功")
        } else {
            print("没有找到歌词")
        }
        
        // 验证文件是否成功保存
        guard FileManager.default.fileExists(atPath: mp3URL.path),
              FileManager.default.fileExists(atPath: lrcURL.path) else {
            throw NSError(domain: "LocalMusicLibrary", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "文件保存失败"])
        }
        
        // 更新歌曲对象
        var updatedSong = song
        updatedSong.localMp3URL = mp3URL
        updatedSong.localLrcURL = lrcURL
        updatedSong.isDownloaded = true
        
        // 更新本地存储
        if let index = songs.firstIndex(where: { $0.id == song.id }) {
            songs[index] = updatedSong
        } else {
            songs.append(updatedSong)
        }
        saveSongs()
        
        return updatedSong
    }
    
    private func getMp3DownloadURL(songId: String) async throws -> (URL, SongDetailData) {
        print("开始获取歌曲详情，ID: \(songId)")
        let clienttime = Int(Date().timeIntervalSince1970 * 1000)
        let signature = generateDetailSignature(songId: songId, clienttime: clienttime)
        print("生成签名: \(signature)")
        
        var components = URLComponents(string: "https://wwwapi.kugou.com/play/songinfo")!
        components.queryItems = [
            URLQueryItem(name: "srcappid", value: "2919"),
            URLQueryItem(name: "clientver", value: "20000"),
            URLQueryItem(name: "clienttime", value: String(clienttime)),
            URLQueryItem(name: "mid", value: getMid()),
            URLQueryItem(name: "uuid", value: getMid()),
            URLQueryItem(name: "dfid", value: getDfid()),
            URLQueryItem(name: "appid", value: "1014"),
            URLQueryItem(name: "platid", value: "4"),
            URLQueryItem(name: "encode_album_audio_id", value: songId),
            URLQueryItem(name: "token", value: ""),
            URLQueryItem(name: "userid", value: "0"),
            URLQueryItem(name: "signature", value: signature)
        ]
        
        print("请求URL: \(components.url?.absoluteString ?? "nil")")
        
        var request = URLRequest(url: components.url!)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            print("详情接口响应状态码: \(httpResponse.statusCode)")
        }
        
        // 打印原始响应数据用于调试
        if let jsonString = String(data: data, encoding: .utf8) {
            print("详情接口原始响应: \(jsonString)")
        }
        
        let songDetail = try JSONDecoder().decode(SongDetailResponse.self, from: data)
        
        // 检查状态码
        guard songDetail.status == 1 && songDetail.err_code == 0 else {
            print("获取歌曲详情失败: status=\(songDetail.status), err_code=\(songDetail.err_code)")
            throw URLError(.badServerResponse)
        }
        
        guard let playURL = URL(string: songDetail.data.play_url) else {
            print("无效的播放URL: \(songDetail.data.play_url)")
            throw URLError(.badURL)
        }
        
        return (playURL, songDetail.data)
    }
    
    private func generateDetailSignature(songId: String, clienttime: Int) -> String {
        let params = [
            "NVPh5oo715z5DIWAeQlhMDsWXXQV4hwt",
            "appid=1014",
            "clienttime=\(clienttime)",
            "clientver=20000",
            "dfid=\(getDfid())",
            "encode_album_audio_id=\(songId)",
            "mid=\(getMid())",
            "platid=4",
            "srcappid=2919",
            "token=",
            "userid=0",
            "uuid=\(getMid())",
            "NVPh5oo715z5DIWAeQlhMDsWXXQV4hwt"
        ]
        
        let signStr = params.joined()
        guard let data = signStr.data(using: .utf8) else {
            return ""
        }
        
        let hash = Insecure.MD5.hash(data: data)
        return hash.map { String(format: "%02hhx", $0) }.joined()
    }
    
    // 更新响应模型
    private struct SongDetailResponse: Codable {
        let status: Int
        let err_code: Int
        let data: SongDetailData
    }
    
    private struct SongDetailData: Codable {
        let hash: String
        let timelength: Int?
        let filesize: Int?
        let audio_name: String?
        let have_album: Int
        let album_name: String?
        let album_id: String?
        let img: String?
        let have_mv: Int
        let video_id: Int
        let author_name: String?
        let song_name: String?
        let lyrics: String?
        let author_id: String
        let privilege: Int
        let privilege2: String
        let play_url: String
        let play_backup_url: String?
        let authors: [Author]?
        let is_free_part: Int
        let bitrate: Int
        let has_privilege: Bool
        
        struct Author: Codable {
            let author_id: String
            let author_name: String
            let is_publish: String
            let sizable_avatar: String?
            let e_author_id: String
            let avatar: String?
        }
    }
} 
