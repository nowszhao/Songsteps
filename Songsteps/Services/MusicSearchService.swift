import Foundation
import CryptoKit

class MusicSearchService: ObservableObject {
    private let cookie: String = "kg_mid=dfae4c22d680eb5b60469dceb345eb39; kg_dfid=0jH6v01soQfC3Xvgwh25dAOo; 5SING_TAG_20250102=_ST-1.STW-0.SC-0.PL-0.FX-0.ZF-0.ZC-0.XZ-0.DZ-0%7COM_ST-1.STW-0.SC-0.PL-0.FX-0.ZF-0.ZC-0.XZ-0.DZ-0; Hm_lvt_aedee6983d4cfc62f509129360d6bb3d=1735655112,1735675747,1735898866; HMACCOUNT=D46FC601062A4B51; kg_dfid_collect=d41d8cd98f00b204e9800998ecf8427e; kg_mid_temp=dfae4c22d680eb5b60469dceb345eb39; Hm_lpvt_aedee6983d4cfc62f509129360d6bb3d=1735909762"
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
    
    @Published var searchResults: [Song] = []
    @Published var isSearching = false
    @Published var error: Error?
    
    func search(keyword: String) async {
        print("开始搜索: \(keyword)")
        guard !keyword.isEmpty else {
            print("搜索关键词为空，退出搜索")
            return
        }
        
        await MainActor.run {
            self.isSearching = true
            print("设置搜索状态: isSearching = true")
        }
        
        do {
            let clienttime = Int(Date().timeIntervalSince1970 * 1000)
            let signature = generateSearchSignature(keyword: keyword, clienttime: clienttime)
            print("生成搜索签名: \(signature)")
            
            var components = URLComponents(string: "https://complexsearch.kugou.com/v2/search/song")!
            components.queryItems = [
                URLQueryItem(name: "callback", value: "callback123"),
                URLQueryItem(name: "srcappid", value: "2919"),
                URLQueryItem(name: "clientver", value: "1000"),
                URLQueryItem(name: "clienttime", value: String(clienttime)),
                URLQueryItem(name: "mid", value: getMid()),
                URLQueryItem(name: "uuid", value: getMid()),
                URLQueryItem(name: "dfid", value: getDfid()),
                URLQueryItem(name: "keyword", value: keyword),
                URLQueryItem(name: "page", value: "1"),
                URLQueryItem(name: "pagesize", value: "30"),
                URLQueryItem(name: "bitrate", value: "0"),
                URLQueryItem(name: "isfuzzy", value: "0"),
                URLQueryItem(name: "inputtype", value: "0"),
                URLQueryItem(name: "platform", value: "WebFilter"),
                URLQueryItem(name: "userid", value: "0"),
                URLQueryItem(name: "iscorrection", value: "1"),
                URLQueryItem(name: "privilege_filter", value: "0"),
                URLQueryItem(name: "filter", value: "10"),
                URLQueryItem(name: "token", value: ""),
                URLQueryItem(name: "appid", value: "1014"),
                URLQueryItem(name: "signature", value: signature)
            ]
            
            print("构建搜索URL: \(components.url?.absoluteString ?? "nil")")
            
            var request = URLRequest(url: components.url!)
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            print("收到响应: \(response)")
            
            if let jsonString = String(data: data, encoding: .utf8) {
                print("原始响应数据: \(jsonString)")
            }
            
            // 处理 JSONP 响应，确保正确去除回调包装
            var jsonString = String(data: data, encoding: .utf8)!
            if jsonString.hasPrefix("callback123(") {
                // 找到最后一个右括号的位置
                if let lastParenIndex = jsonString.lastIndex(of: ")") {
                    // 提取 callback123( 和最后一个 ) 之间的内容
                    let startIndex = jsonString.index(jsonString.startIndex, offsetBy: 12)
                    jsonString = String(jsonString[startIndex..<lastParenIndex])
                }
            }
            
            print("处理后的 JSON 字符串: \(jsonString)")
            
            let jsonData = jsonString.data(using: .utf8)!
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys
            
            do {
                let searchResponse = try decoder.decode(SearchResponse.self, from: jsonData)
                // 检查错误码
                if let errorCode = searchResponse.error_code, errorCode != 0 {
                    throw NSError(
                        domain: "KugouAPI",
                        code: errorCode,
                        userInfo: [NSLocalizedDescriptionKey: searchResponse.error_msg ?? "Unknown error"]
                    )
                }
                
                print("解析到 \(searchResponse.data.lists.count) 条搜索结果")
                
                await MainActor.run {
                    self.searchResults = searchResponse.data.lists.map { item in
                        print("处理搜索结果: \(item.SongName) - \(item.SingerName)")
                        return Song(
                            id: item.EMixSongID,
                            title: item.SongName,
                            artist: item.SingerName,
                            duration: item.Duration,
                            fileHash: item.FileHash,
                            mixSongId: item.MixSongID,
                            hqFileHash: item.HQFileHash,
                            sqFileHash: item.SQFileHash
                        )
                    }
                    self.isSearching = false
                    self.error = nil
                }
            } catch {
                print("JSON 解析错误: \(error)")
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("缺少键: \(key.stringValue), 路径: \(context.codingPath)")
                    case .typeMismatch(let type, let context):
                        print("类型不匹配: 期望 \(type), 路径: \(context.codingPath)")
                    case .valueNotFound(let type, let context):
                        print("值为空: 类型 \(type), 路径: \(context.codingPath)")
                    case .dataCorrupted(let context):
                        print("数据损坏: \(context)")
                    @unknown default:
                        print("未知解码错误")
                    }
                }
                throw error
            }
        } catch {
            print("搜索出错: \(error.localizedDescription)")
            await MainActor.run {
                self.error = error
                self.isSearching = false
            }
        }
    }
    
    private func generateSearchSignature(keyword: String, clienttime: Int) -> String {
        // 按照酷狗音乐的签名规则构建参数数组
        let params = [
            "NVPh5oo715z5DIWAeQlhMDsWXXQV4hwt",
            "appid=1014",
            "bitrate=0",
            "callback=callback123",
            "clienttime=\(clienttime)",
            "clientver=1000",
            "dfid=\(self.getDfid())",
            "filter=10",
            "inputtype=0",
            "iscorrection=1",
            "isfuzzy=0",
            "keyword=\(keyword)",
            "mid=\(self.getMid())",
            "page=1",
            "pagesize=30",
            "platform=WebFilter",
            "privilege_filter=0",
            "srcappid=2919",
            "token=",
            "userid=0",
            "uuid=\(self.getMid())",
            "NVPh5oo715z5DIWAeQlhMDsWXXQV4hwt"
        ]
        
        // 连接所有参数
        let signStr = params.joined()
        
        // 计算 MD5
        guard let data = signStr.data(using: .utf8) else {
            return ""
        }
        
        let hash = Insecure.MD5.hash(data: data)
        return hash.map { String(format: "%02hhx", $0) }.joined()
    }
    
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
    
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

// 解析响应的数据结构
private struct SearchResponse: Codable {
    let status: Int
    let error_code: Int?
    let error_msg: String?
    let data: SearchData
}

private struct SearchData: Codable {
    let lists: [SongItem]
    let total: Int
    let correctiontip: String
    let correctiontype: Int
    let correctionrelate: String
    let pagesize: Int
    let page: Int
}

private struct SongItem: Codable {
    let EMixSongID: String
    let SongName: String
    let SingerName: String
    let Duration: Int
    let FileHash: String
    let MixSongID: String
    let HQFileHash: String?
    let SQFileHash: String?
    let Privilege: Int
    let FileName: String
    let AlbumID: String?
    let Album: String?
    let AlbumPrivilege: Int?
    
    // 处理可能的键名不匹配
    enum CodingKeys: String, CodingKey {
        case EMixSongID
        case SongName
        case SingerName
        case Duration
        case FileHash
        case MixSongID
        case HQFileHash
        case SQFileHash
        case Privilege
        case FileName
        case AlbumID = "EAlbumID"
        case Album = "AlbumName"
        case AlbumPrivilege
    }
} 
