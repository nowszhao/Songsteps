import SwiftUI

struct LyricsSheetView: View {
    let lyrics: [LyricLine]
    let currentTime: Double
    let onLyricSelected: (LyricLine) -> Void
    @Binding var selectedLyricId: String?
    
    var body: some View {
        ScrollViewReader { proxy in
            List(lyrics, id: \.time) { lyric in
                Text(lyric.text)
                    .font(.body)
                    .padding(.vertical, 8)
                    .foregroundColor(isCurrentLyric(lyric) ? .blue : .primary)
                    .id(lyric.time)
                    .onTapGesture {
                        onLyricSelected(lyric)
                    }
            }
            .onChange(of: currentTime) { _ in
                if let currentLyric = lyrics.first(where: { isCurrentLyric($0) }) {
                    withAnimation {
                        proxy.scrollTo(currentLyric.time, anchor: .center)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private func isCurrentLyric(_ lyric: LyricLine) -> Bool {
        let nextTime = lyrics.first(where: { $0.time > lyric.time })?.time ?? Double.infinity
        return lyric.time <= currentTime && currentTime < nextTime
    }
} 