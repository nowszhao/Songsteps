import SwiftUI

struct AudioVisualizerView: View {
    let audioData: [Float]
    let lyricWaveform: [Float]
    let recordedWaveform: [Float]
    let isRecording: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 原始歌词波形
                HStack(spacing: 2) {
                    ForEach(Array(stride(from: 0, to: lyricWaveform.count, by: 2)), id: \.self) { i in
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.blue.opacity(0.5))
                                .frame(
                                    width: (geometry.size.width / CGFloat(lyricWaveform.count/2)) - 2,
                                    height: geometry.size.height/2 * CGFloat(lyricWaveform[i])
                                )
                            
                            Rectangle()
                                .fill(Color.blue.opacity(0.5))
                                .frame(
                                    width: (geometry.size.width / CGFloat(lyricWaveform.count/2)) - 2,
                                    height: geometry.size.height/2 * CGFloat(abs(lyricWaveform[i+1]))
                                )
                        }
                    }
                }
                
                // 录音波形
                if !recordedWaveform.isEmpty {
                    HStack(spacing: 2) {
                        ForEach(Array(stride(from: 0, to: recordedWaveform.count, by: 2)), id: \.self) { i in
                            VStack(spacing: 0) {
                                Rectangle()
                                    .fill(Color.red.opacity(0.5))
                                    .frame(
                                        width: (geometry.size.width / CGFloat(recordedWaveform.count/2)) - 2,
                                        height: geometry.size.height/2 * CGFloat(recordedWaveform[i])
                                    )
                                
                                Rectangle()
                                    .fill(Color.red.opacity(0.5))
                                    .frame(
                                        width: (geometry.size.width / CGFloat(recordedWaveform.count/2)) - 2,
                                        height: geometry.size.height/2 * CGFloat(abs(recordedWaveform[i+1]))
                                    )
                            }
                        }
                    }
                }
                
                // 录音指示器
                if isRecording {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .position(x: 10, y: 10)
                }
            }
        }
        .frame(height: 100)
    }
} 