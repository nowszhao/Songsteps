import SwiftUI

struct ContentView: View {
    @StateObject private var audioManager = AudioManager()
    @State private var lyrics: [LyricLine] = []
    @State private var currentLyric: String = ""
    @State private var showingRecordingControls = false
    @State private var showingLyricSheet = false
    @State private var selectedLyricId: String?
    @State private var lastSelectedLyric: LyricLine?
    @State private var isLoopEnabled: Bool = false
    @State private var showingRecordingHistory = false
    @StateObject private var library = LocalMusicLibrary.shared
    @State private var showingPlaylist = false
    @State private var currentSong: Song?
    
    var body: some View {
        VStack(spacing: 0) {
            // 导航栏
            NavigationBarView(
                currentSong: currentSong,
                onPlaylistTap: { showingPlaylist = true }
            )
            
            // 音频可视化区域
            AudioVisualizerView(
                audioData: audioManager.audioData,
                lyricWaveform: audioManager.lyricWaveform,
                recordedWaveform: audioManager.recordedWaveform,
                isRecording: audioManager.isRecording
            )
            .frame(height: 100)
            .padding()
            
            // 歌词显示区域
            VStack(spacing: 12) {
                // 主歌词文本
                HStack {
                    Text(currentLyric)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .contentShape(Rectangle())
                .onTapGesture {
                    print("点击歌词，打开歌词列表")
                    showingLyricSheet = true
                }
                // 添加左右滑动手势
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            guard !lyrics.isEmpty else { return }
                            
                            // 获取当前歌词的索引
                            if let currentIndex = lyrics.firstIndex(where: { $0.text == currentLyric }) {
                                // 根据滑动方向决定是切换到上一句还是下一句
                                if value.translation.width > 50 {  // 右滑，切换到上一句
                                    if currentIndex > 0 {
                                        switchToLyric(lyrics[currentIndex - 1])
                                    }
                                } else if value.translation.width < -50 {  // 左滑，切换到下一句
                                    if currentIndex < lyrics.count - 1 {
                                        switchToLyric(lyrics[currentIndex + 1])
                                    }
                                }
                            }
                        }
                )
                
                if let matchResult = audioManager.currentMatchResult {
                    // 匹配结果卡片
                    VStack(spacing: 8) {
                        // 评分展示
                        HStack(spacing: 20) {
                            if let score = audioManager.lastScore {
                                ScoreItemView(
                                    title: "总分",
                                    score: score.totalScore,
                                    color: .blue
                                )
                                
                                ScoreItemView(
                                    title: "准确度",
                                    score: score.textMatchScore,
                                    color: .green
                                )
                                
                                ScoreItemView(
                                    title: "完整度",
                                    score: score.completenessScore,
                                    color: .orange
                                )
                            }
                        }
                        .padding(.vertical, 8)
                        
                        Divider()
                        
                        // 单词匹配结果
                        FlowLayout(spacing: 4) {
                            ForEach(matchResult.originalWords.indices, id: \.self) { index in
                                let word = matchResult.originalWords[index]
                                Text(word.word)
                                    .font(.callout)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(word.isMatched ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                                    .foregroundColor(word.isMatched ? .green : .red)
                                    .cornerRadius(8)
                            }
                        }
                        
                        if !audioManager.recognizedText.isEmpty {
                            Divider()
                            
                            // 识别结果
                            HStack {
                                Image(systemName: "text.bubble")
                                    .foregroundColor(.secondary)
                                Text(audioManager.recognizedText)
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                } else {
                    // 添加默认展示状态
                    VStack(spacing: 12) {
                        Image(systemName: "music.mic")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        
                        Text("点击录音按钮开始演唱")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("演唱后可以查看评分和匹配结果")
                            .font(.subheadline)
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
            .padding()
            
            Spacer()
            
            // 底部控制面板
            VStack(spacing: 20) {
                // 播放控制区
                PlaybackControlsView(
                    audioManager: audioManager,
                    lyrics: lyrics,
                    currentLyric: currentLyric,
                    isLoopEnabled: $isLoopEnabled,
                    lastSelectedLyric: lastSelectedLyric
                )
                
                // 录音控制区
                RecordingControlsView(
                    audioManager: audioManager,
                    lyrics: lyrics,
                    currentLyric: currentLyric
                )
            }
            .padding(.vertical, 20)
            .padding(.horizontal)
            .background(
                Color(.systemBackground)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: -4)
            )
        }
        .padding()
        .onAppear {
            loadAudioAndLyrics1()
            audioManager.setupRecording()
            if let firstLyric = lyrics.first {
                currentLyric = firstLyric.text
                audioManager.onLyricChanged(
                    lyricId: firstLyric.id,
                    text: firstLyric.text,
                    startTime: firstLyric.time,
                    endTime: lyrics.count > 1 ? lyrics[1].time : audioManager.duration
                )
            }
        }
        .onChange(of: audioManager.currentTime) { newTime in
            updateCurrentLyric(at: newTime)
        }
        .sheet(isPresented: $showingLyricSheet) {
            LyricListView(
                lyrics: lyrics,
                currentTime: audioManager.currentTime,
                onLyricSelected: { lyric in
                    print("选中歌词: \(lyric.text), 时间: \(lyric.time), ID: \(lyric.id)")
                    lastSelectedLyric = lyric
                    currentLyric = lyric.text
                    
                    let nextLyricIndex = lyrics.firstIndex(where: { $0.time > lyric.time }) ?? lyrics.count
                    let endTime = nextLyricIndex < lyrics.count ? lyrics[nextLyricIndex].time : audioManager.duration
                    
                    audioManager.onLyricChanged(
                        lyricId: lyric.id,
                        text: lyric.text,
                        startTime: lyric.time,
                        endTime: endTime
                    )
                    
                    if isLoopEnabled {
                        audioManager.setLoopRange(startTime: lyric.time, endTime: endTime)
                    }
                    
                    audioManager.seekTo(time: lyric.time)
                    showingLyricSheet = false
                }
            )
        }
        .sheet(isPresented: $showingPlaylist) {
            PlaylistView { song in
                loadSong(song)
                showingPlaylist = false
            }
        }
    }
    
    
    private func loadAudioAndLyrics1() {
        // 加载音频文件
        if let audioUrl = Bundle.main.url(forResource: "a", withExtension: "mp3") {
            audioManager.setupAudio(url: audioUrl)
        }
        
        // 加载歌词文件
        if let lrcUrl = Bundle.main.url(forResource: "a", withExtension: "lrc"),
           let lrcContent = try? String(contentsOf: lrcUrl, encoding: .utf8) {
            let (_, parsedLyrics) = LyricParser.parse(lrcContent)
            lyrics = parsedLyrics.sorted(by: { $0.time < $1.time })
            
            if let firstLyric = lyrics.first {
                currentLyric = firstLyric.text
                audioManager.onLyricChanged(
                    lyricId: firstLyric.id,
                    text: firstLyric.text,
                    startTime: firstLyric.time,
                    endTime: lyrics.count > 1 ? lyrics[1].time : audioManager.duration
                )
            }
        }
    }
    
    private func loadAudioAndLyrics(mp3URL: URL, lrcURL: URL) -> Bool {
        print("加载歌曲: \(mp3URL.lastPathComponent)")
        
        // 停止当前播放和录音
        audioManager.stop()
        audioManager.stopRecording()
        
        // 加载音频文件
        audioManager.setupAudio(url: mp3URL)
        
        // 加载歌词文件
        if let lrcContent = try? String(contentsOf: lrcURL, encoding: .utf8) {
            let (_, parsedLyrics) = LyricParser.parse(lrcContent)
            lyrics = parsedLyrics.sorted(by: { $0.time < $1.time })
            
            if let firstLyric = lyrics.first {
                currentLyric = firstLyric.text
                audioManager.onLyricChanged(
                    lyricId: firstLyric.id,
                    text: firstLyric.text,
                    startTime: firstLyric.time,
                    endTime: lyrics.count > 1 ? lyrics[1].time : audioManager.duration
                )
                return true
            }
        }
        return false
    }
    
    private func updateCurrentLyric(at time: Double) {
//        print("更新歌词 - 当前时间: \(time)")
        
        if let lastSelected = lastSelectedLyric {
            let nextLyricIndex = lyrics.firstIndex(where: { $0.time > lastSelected.time }) ?? lyrics.count
            let nextTime = nextLyricIndex < lyrics.count ? lyrics[nextLyricIndex].time : Double.infinity
            print("最后选中歌词: \(lastSelected.text), 开始时间: \(lastSelected.time), 结束时间: \(nextTime)")
            
            if time >= lastSelected.time && time < nextTime {
                print("在选中歌词时间范围内，保持当前歌词")
                return
            }
            print("超出选中歌词范围，清除选中状态")
            lastSelectedLyric = nil
        }

        // 正常的歌词更新逻辑
        if let currentLyric = lyrics.first(where: { lyric in
            let nextLyricIndex = lyrics.firstIndex(where: { $0.time > lyric.time }) ?? lyrics.count
            let nextTime = nextLyricIndex < lyrics.count ? lyrics[nextLyricIndex].time : Double.infinity
            return lyric.time <= time && time < nextTime
        }) {
//            print("找到匹配时间的歌词: \(currentLyric.text), 时间: \(currentLyric.time)")
            
            if self.currentLyric != currentLyric.text {
//                print("更新显示歌词从: \(self.currentLyric) 到: \(currentLyric.text)")
                self.currentLyric = currentLyric.text
                
                let nextLyricIndex = lyrics.firstIndex(where: { $0.time > currentLyric.time }) ?? lyrics.count
                let endTime = nextLyricIndex < lyrics.count ? lyrics[nextLyricIndex].time : audioManager.duration
                
                audioManager.onLyricChanged(
                    lyricId: currentLyric.id,
                    text: currentLyric.text,
                    startTime: currentLyric.time,
                    endTime: endTime
                )
                
                if isLoopEnabled {
                    audioManager.setLoopRange(startTime: currentLyric.time, endTime: endTime)
                }
            }
        }
    }
    
    func loadSong(_ song: Song) {
        print("loadSong song:", song)
        
        guard let audioUrl = song.localMp3URL,
              let lrcUrl = song.localLrcURL,
              FileManager.default.fileExists(atPath: audioUrl.path),
              FileManager.default.fileExists(atPath: lrcUrl.path),
              let lrcContent = try? String(contentsOf: lrcUrl, encoding: .utf8) else {
            print("歌曲加载失败: \(song.title)")
            // 如果文件不存在，从库中移除
            library.removeSong(song)
            return
        }
        
        // 更新当前歌曲
        currentSong = song
        
        // 加载音频文件
        audioManager.setupAudio(url: audioUrl)
        
        // 加载歌词文件
        let (_, parsedLyrics) = LyricParser.parse(lrcContent)
        lyrics = parsedLyrics.sorted(by: { $0.time < $1.time })
        
        if let firstLyric = lyrics.first {
            currentLyric = firstLyric.text
            audioManager.onLyricChanged(
                lyricId: firstLyric.id,
                text: firstLyric.text,
                startTime: firstLyric.time,
                endTime: lyrics.count > 1 ? lyrics[1].time : audioManager.duration
            )
        }
    }
    
    private func switchToLyric(_ lyric: LyricLine) {
        print("切换到歌词: \(lyric.text), 时间: \(lyric.time), ID: \(lyric.id)")
        lastSelectedLyric = lyric
        currentLyric = lyric.text
        
        let nextLyricIndex = lyrics.firstIndex(where: { $0.time > lyric.time }) ?? lyrics.count
        let endTime = nextLyricIndex < lyrics.count ? lyrics[nextLyricIndex].time : audioManager.duration
        
        audioManager.onLyricChanged(
            lyricId: lyric.id,
            text: lyric.text,
            startTime: lyric.time,
            endTime: endTime
        )
        
        if isLoopEnabled {
            audioManager.setLoopRange(startTime: lyric.time, endTime: endTime)
        }
        
        audioManager.seekTo(time: lyric.time)
    }
}

// 新增歌词列表视图
struct LyricListView: View {
    let lyrics: [LyricLine]
    let currentTime: Double
    let onLyricSelected: (LyricLine) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recordingManager = LyricRecordingManager.shared
    
    var body: some View {
        NavigationView {
            List {
                ForEach(lyrics) { lyric in
                    LyricItemView(
                        lyric: lyric,
                        isCurrentLyric: isCurrentLyric(lyric),
                        recordingManager: recordingManager
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        print("点击歌词: \(lyric.text), 时间: \(lyric.time), ID: \(lyric.id)")
                        onLyricSelected(lyric)
                    }
                }
            }
            .navigationTitle("歌词列表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // 使用时间范围来判断当前歌词
    private func isCurrentLyric(_ lyric: LyricLine) -> Bool {
        let nextTime = lyrics.first(where: { $0.time > lyric.time })?.time ?? Double.infinity
        let isInTimeRange = lyric.time <= currentTime && currentTime < nextTime
//      print("检查歌词是否当前: \(lyric.text), 时间范围: \(lyric.time)-\(nextTime), 当前时间: \(currentTime), 结果: \(isInTimeRange)")
        return isInTimeRange
    }
}

struct LyricItemView: View {
    let lyric: LyricLine
    let isCurrentLyric: Bool
    let recordingManager: LyricRecordingManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(lyric.text)
                    .font(.body)
                    .foregroundColor(isCurrentLyric ? .primary : .secondary)
                
                if let recording = recordingManager.getRecording(for: lyric.id) {
                    HStack(spacing: 8) {
                        Label("\(recording.score.totalScore)", systemImage: "music.note")
                            .foregroundColor(.green)
                        Text("准确度: \(recording.score.textMatchScore)%")
                            .foregroundColor(.blue)
                        Text("完整度: \(recording.score.completenessScore)%")
                            .foregroundColor(.orange)
                    }
                    .font(.caption)
                }
            }
            
            Spacer()
            
            if recordingManager.getRecording(for: lyric.id) != nil {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(isCurrentLyric ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
}

struct ScoreItemView: View {
    let title: String
    let score: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(score)")
                .font(.title2.bold())
                .foregroundColor(color)
        }
        .frame(minWidth: 60)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    ContentView()
}
