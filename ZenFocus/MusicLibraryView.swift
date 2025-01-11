import SwiftUI
import UniformTypeIdentifiers

struct MusicLibraryView: View {
    @StateObject private var musicManager = MusicManager.shared
    @State private var isImporting = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 16) {
            headerView
            
            if musicManager.tracks.isEmpty {
                emptyStateView
            } else {
                trackListView
            }
        }
        .padding()
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.audio, .mp3, .wav],
            allowsMultipleSelection: true
        ) { result in
            handleMusicImport(result)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private var headerView: some View {
        HStack {
            Text("Focus Music")
                .font(.title2)
                .bold()
            
            Spacer()
            
            addMusicButton
        }
        .padding(.horizontal)
    }
    
    private var addMusicButton: some View {
        Button(action: { isImporting = true }) {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                Text("Add Focus Music")
                    .font(.system(size: 14))
            }
            .foregroundColor(.accentColor)
        }
        .buttonStyle(PlainButtonStyle())
        .help("Add Focus Music")
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No focus music added yet")
                .font(.headline)
            Text("Add music files to enhance your focus sessions")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            addMusicButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var trackListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(musicManager.tracks) { track in
                    MusicTrackCard(track: track, isPlaying: musicManager.currentTrack?.id == track.id, musicManager: musicManager)
                        .contextMenu {
                            Button(action: { musicManager.deleteTrack(track) }) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func handleMusicImport(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            for url in urls {
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    try musicManager.importTrack(from: url)
                }
            }
        } catch {
            errorMessage = "Failed to import music: \(error.localizedDescription)"
            showingError = true
            ZenFocusLogger.shared.error("Failed to import music", error: error)
        }
    }
}

struct MusicTrackCard: View {
    let track: MusicTrack
    let isPlaying: Bool
    @ObservedObject var musicManager: MusicManager
    
    var body: some View {
        HStack {
            Image(systemName: isPlaying ? "speaker.wave.2.fill" : "music.note")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(isPlaying ? .green : .blue)
                .frame(width: 32, height: 32)
                .background((isPlaying ? Color.green : Color.blue).opacity(0.2))
                .clipShape(Circle())
            
            VStack(alignment: .leading) {
                Text(track.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(track.dateAdded, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke((isPlaying ? Color.green : Color.blue).opacity(0.3), lineWidth: 1)
        )
        .onTapGesture {
            if isPlaying {
                musicManager.pause()
            } else {
                musicManager.play(track: track)
            }
        }
    }
}

extension UTType {
    static let mp3 = UTType(filenameExtension: "mp3")!
    static let wav = UTType(filenameExtension: "wav")!
} 