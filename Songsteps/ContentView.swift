//
//  ContentView.swift
//  Songsteps
//
//  Created by changhozhao on 2025/1/4.
//

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
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部导航区域
            VStack(spacing: 8) {
                Text("Songsteps")
                    .font(.title.bold())
                    .foregroundColor(.primary)
                
                Text("跟唱练习")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top)
            
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
                    
                    Spacer()
                    
                    Image(systemName: "list.bullet")
                        .font(.title3)
                        .foregroundColor(.secondary)
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
                }
            }
            .padding()
            
            Spacer()
            
            // 底部控制面板
            VStack(spacing: 20) {
                // 播放控制区
                HStack(spacing: 40) {
                    // 循环按钮
                    Button {
                        isLoopEnabled.toggle()
                        audioManager.isLoopEnabled = isLoopEnabled
                        print("切换循环模式: \(isLoopEnabled)")
                        
                        if isLoopEnabled {
                            if let currentLyricLine = lyrics.first(where: { $0.text == currentLyric }) {
                                let nextLyricIndex = lyrics.firstIndex(where: { $0.time > currentLyricLine.time }) ?? lyrics.count
                                let endTime = nextLyricIndex < lyrics.count ? lyrics[nextLyricIndex].time : audioManager.duration
                                audioManager.setLoopRange(startTime: currentLyricLine.time, endTime: endTime)
                            }
                        }
                    } label: {
                        Image(systemName: isLoopEnabled ? "repeat.circle.fill" : "repeat.circle")
                            .font(.title2)
                            .foregroundColor(isLoopEnabled ? .green : .secondary)
                    }
                    
                    // 播放/暂停按钮
                    Button {
                        if audioManager.isPlaying {
                            print("暂停播放")
                            audioManager.pause()
                        } else {
                            print("开始播放")
                            if let selectedLyric = lastSelectedLyric {
                                audioManager.play(fromTime: selectedLyric.time)
                            } else if let currentLyric = lyrics.first(where: { $0.text == self.currentLyric }) {
                                audioManager.play(fromTime: currentLyric.time)
                            } else {
                                audioManager.play()
                            }
                        }
                    } label: {
                        Image(systemName: audioManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 54))
                            .foregroundColor(.accentColor)
                    }
                    
                    // 语言选择按钮
                    Menu {
                        ForEach(RecognitionLanguage.allCases, id: \.self) { language in
                            Button(language.displayName) {
                                print("切换识别语言: \(language.displayName)")
                                audioManager.switchRecognitionLanguage(to: language)
                            }
                        }
                    } label: {
                        Image(systemName: "globe")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 录音控制区
                HStack(spacing: 30) {
                    // 录音按钮
                    Button {
                        if audioManager.isRecording {
                            print("停止录音")
                            audioManager.stopRecording()
                        } else {
                            print("开始录音")
                            if let currentLyric = lyrics.first(where: { $0.text == self.currentLyric }) {
                                let nextLyricIndex = lyrics.firstIndex(where: { $0.time > currentLyric.time }) ?? lyrics.count
                                let endTime = nextLyricIndex < lyrics.count ? lyrics[nextLyricIndex].time : audioManager.duration
                                audioManager.startRecording(startTime: currentLyric.time, endTime: endTime)
                            }
                        }
                    } label: {
                        Label(
                            audioManager.isRecording ? "停止录音" : "开始录音",
                            systemImage: audioManager.isRecording ? "stop.circle.fill" : "record.circle"
                        )
                        .font(.headline)
                        .foregroundColor(audioManager.isRecording ? .red : .accentColor)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(audioManager.isRecording ? Color.red.opacity(0.15) : Color.accentColor.opacity(0.15))
                        .cornerRadius(20)
                    }
                    
                    if !audioManager.recordedWaveform.isEmpty {
                        // 播放录音按钮
                        Button {
                            if audioManager.isPlayingRecording {
                                print("停止播放录音")
                                audioManager.stopPlayingRecording()
                            } else {
                                print("播放录音")
                                audioManager.playRecording()
                            }
                        } label: {
                            Label(
                                audioManager.isPlayingRecording ? "停止播放" : "播放录音",
                                systemImage: audioManager.isPlayingRecording ? "stop.fill" : "play.fill"
                            )
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color(.systemGray6))
                            .cornerRadius(20)
                        }
                    }
                }
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
            loadAudioAndLyrics()
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
    }
    
    private func loadAudioAndLyrics() {
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
    
    private func updateCurrentLyric(at time: Double) {
        print("更新歌词 - 当前时间: \(time)")
        
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
            print("找到匹配时间的歌词: \(currentLyric.text), 时间: \(currentLyric.time)")
            
            if self.currentLyric != currentLyric.text {
                print("更新显示歌词从: \(self.currentLyric) 到: \(currentLyric.text)")
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
