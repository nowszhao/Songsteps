import SwiftUI

struct RecordingControlsView: View {
    @ObservedObject var audioManager: AudioManager
    let lyrics: [LyricLine]
    let currentLyric: String
    
    var body: some View {
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
} 
