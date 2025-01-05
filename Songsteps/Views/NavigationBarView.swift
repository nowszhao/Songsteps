import SwiftUI

struct NavigationBarView: View {
    let currentSong: Song?
    let onPlaylistTap: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                
                if let song = currentSong {
                    VStack(spacing: 4) {
                        Text(song.title)
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                        Text(song.artist)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Songsteps")
                        .font(.title.bold())
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Button {
                    print("打开播放列表")
                    onPlaylistTap()
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
        }
        .padding(.top)
    }
} 