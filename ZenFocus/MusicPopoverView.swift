import SwiftUI

struct MusicPopoverView: View {
    @ObservedObject var musicManager: MusicManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Focus Music")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(12)
            
            Divider()
            
            if musicManager.tracks.isEmpty {
                emptyStateView
            } else {
                trackListView
            }
            
            // Controls
            VStack(spacing: 8) {
                Divider()
                
                // Volume control
                HStack(spacing: 8) {
                    Image(systemName: musicManager.volume == 0 ? "speaker.slash.fill" : 
                                   musicManager.volume < 0.3 ? "speaker.fill" :
                                   musicManager.volume < 0.7 ? "speaker.wave.1.fill" : "speaker.wave.2.fill")
                        .foregroundColor(.secondary)
                        .frame(width: 16)
                    
                    Slider(value: $musicManager.volume, in: 0...1)
                        .accentColor(.accentColor)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                
                // Playback controls
                HStack(spacing: 20) {
                    Button(action: { musicManager.playPrevious() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(musicManager.tracks.isEmpty)
                    
                    Button(action: {
                        if musicManager.isPlaying {
                            musicManager.pause()
                        } else if let track = musicManager.currentTrack {
                            musicManager.resume()
                        } else if let firstTrack = musicManager.tracks.first {
                            musicManager.play(track: firstTrack)
                        }
                    }) {
                        Image(systemName: musicManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(musicManager.tracks.isEmpty)
                    
                    Button(action: { musicManager.playNext() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(musicManager.tracks.isEmpty)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        }
        .frame(width: 200)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note")
                .font(.system(size: 24))
                .foregroundColor(.secondary)
            Text("No focus music added")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
    }
    
    private var trackListView: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(musicManager.tracks) { track in
                    TrackRow(track: track, 
                            isPlaying: musicManager.currentTrack?.id == track.id,
                            isCurrentTrack: musicManager.currentTrack?.id == track.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if musicManager.currentTrack?.id == track.id {
                                if musicManager.isPlaying {
                                    musicManager.pause()
                                } else {
                                    musicManager.resume()
                                }
                            } else {
                                musicManager.play(track: track)
                            }
                        }
                }
            }
            .padding(.vertical, 4)
        }
        .frame(height: 120)
    }
}

struct TrackRow: View {
    let track: MusicTrack
    let isPlaying: Bool
    let isCurrentTrack: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isPlaying ? "speaker.wave.2.fill" : "music.note")
                .foregroundColor(isCurrentTrack ? .accentColor : .secondary)
                .font(.system(size: 10))
                .frame(width: 12)
            
            Text(track.title)
                .font(.system(size: 11))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundColor(isCurrentTrack ? .accentColor : .primary)
            
            Spacer()
            
            if isCurrentTrack {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(isCurrentTrack ? Color.accentColor.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
    }
} 