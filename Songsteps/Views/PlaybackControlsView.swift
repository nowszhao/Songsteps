import SwiftUI

struct PlaybackControlsView: View {
    @ObservedObject var audioManager: AudioManager
    let lyrics: [LyricLine]
    let currentLyric: String
    @Binding var isLoopEnabled: Bool
    let lastSelectedLyric: LyricLine?
    
    // 定义可选的播放速度
    private let speedOptions: [(label: String, value: Float)] = [
        ("0.5×", 0.5),
        ("0.75×", 0.75),
        ("1.0×", 1.0),
        ("1.25×", 1.25),
        ("1.5×", 1.5),
        ("2.0×", 2.0)
    ]
    
    var body: some View {
        HStack(spacing: 20) {
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

            
            // 播放/暂停按钮
            Button {
                if audioManager.isPlaying {
                    print("暂停播放")
                    audioManager.pause()
                } else {
                    print("开始播放")
                    if let selectedLyric = lastSelectedLyric {
                        audioManager.play(fromTime: selectedLyric.time)
                    } else if let currentLyric = lyrics.first(where: { $0.text == currentLyric }) {
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
            
            
            // 播放速度按钮
            Button {
                if audioManager.isSpeaking {
                    print("停止朗读歌词")
                    audioManager.stopSpeaking()
                } else {
                    print("开始朗读歌词: \(currentLyric)")
                    audioManager.speakLyric(currentLyric)
                }
            } label: {
                Image(systemName: audioManager.isSpeaking ? "text.bubble.fill" : "text.bubble")
                    .font(.title2)
                    .foregroundColor(audioManager.isSpeaking ? .green : .secondary)
            }
            
            // 播放速度按钮
            Menu {
                ForEach(speedOptions, id: \.value) { option in
                    Button(option.label) {
                        print("设置播放速度: \(option.value)")
                        audioManager.setPlaybackRate(option.value)
                    }
                }
            } label: {
                Text(String(format: "%.1f×", audioManager.playbackRate))
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
    }
} 
