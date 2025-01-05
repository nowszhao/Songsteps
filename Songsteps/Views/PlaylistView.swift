import SwiftUI

struct PlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var searchService = MusicSearchService()
    @StateObject private var library = LocalMusicLibrary.shared
    @State private var searchText = ""
    @State private var showingSearchResults = false
    
    let onSongSelected: (Song) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索栏
                SearchBar(text: $searchText, isSearching: searchService.isSearching) {
                    print("触发搜索: \(searchText)")
                    Task {
                        showingSearchResults = true
                        await searchService.search(keyword: searchText)
                    }
                }
                .padding()
                
                if showingSearchResults && !searchText.isEmpty {
                    // 搜索结果列表
                    SearchResultsList(
                        results: searchService.searchResults,
                        library: library,
                        onSongSelected: { song in
                            library.addSong(song)
                            showingSearchResults = false
                            searchText = ""
                        }
                    )
                } else {
                    // 已下载歌曲列表
                    SavedSongsList(
                        songs: library.songs,
                        onSongSelected: onSongSelected
                    )
                }
            }
            .navigationTitle("播放列表")
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
}

// 搜索栏组件
struct SearchBar: View {
    @Binding var text: String
    let isSearching: Bool
    let onSubmit: () -> Void
    
    var body: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("搜索歌曲", text: $text)
                    .submitLabel(.search)
                    .onSubmit(onSubmit)
                
                if !text.isEmpty {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            if isSearching {
                ProgressView()
                    .padding(.leading, 8)
            }
        }
    }
}

// 搜索结果列表
struct SearchResultsList: View {
    let results: [Song]
    let library: LocalMusicLibrary
    let onSongSelected: (Song) -> Void
    @State private var downloadingIds: Set<String> = []
    @State private var errorMessage: String?
    
    var body: some View {
        List(results) { song in
            HStack {
                VStack(alignment: .leading) {
                    Text(song.title)
                        .font(.headline)
                    Text(song.artist)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if downloadingIds.contains(song.id) {
                    ProgressView()
                } else if library.songs.contains(where: { $0.id == song.id }) {
                    Image(systemName: "checkmark")
                        .foregroundColor(.green)
                } else {
                    Button {
                        Task {
                            downloadingIds.insert(song.id)
                            do {
                                let downloadedSong = try await library.downloadSong(song)
                                onSongSelected(downloadedSong)
                            } catch {
                                errorMessage = "下载失败：\(error.localizedDescription)"
                            }
                            downloadingIds.remove(song.id)
                        }
                    } label: {
                        Image(systemName: "icloud.and.arrow.down")
                    }
                }
            }
        }
        .alert("错误", isPresented: .constant(errorMessage != nil)) {
            Button("确定") {
                errorMessage = nil
            }
        } message: {
            if let message = errorMessage {
                Text(message)
            }
        }
    }
}

// 已保存歌曲列表
struct SavedSongsList: View {
    let songs: [Song]
    let onSongSelected: (Song) -> Void
    @StateObject private var library = LocalMusicLibrary.shared
    
    var body: some View {
        if songs.isEmpty {
            ContentUnavailableView(
                "暂无歌曲",
                systemImage: "music.note.list",
                description: Text("搜索并添加歌曲到播放列表")
            )
        } else {
            List {
                ForEach(songs) { song in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(song.title)
                                .font(.headline)
                            Text(song.artist)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(song.formattedDuration)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSongSelected(song)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            library.removeSong(song)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
} 
