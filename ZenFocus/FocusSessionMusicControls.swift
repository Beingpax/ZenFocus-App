import SwiftUI
struct FocusSessionMusicControls: View {
    @ObservedObject var musicManager: MusicManager
    
    var body: some View {
        HStack(spacing: 12) {
            if musicManager.tracks.isEmpty {
                Text("No music added")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
            } else if let currentTrack = musicManager.currentTrack {
                Text(currentTrack.title)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(minWidth: 100)
                
                HStack(spacing: 8) {
                    Button(action: {
                        if musicManager.isPlaying {
                            musicManager.pause()
                        } else {
                            musicManager.resume()
                        }
                    }) {
                        Image(systemName: musicManager.isPlaying ? "pause.fill" : "play.fill")
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(musicManager.isPlaying ? "Pause" : "Play")
                    
                    Slider(value: $musicManager.volume, in: 0...1)
                        .frame(width: 80)
                        .help("Volume")
                    
                    Button(action: { musicManager.stop() }) {
                        Image(systemName: "stop.fill")
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Stop")
                }
            } else {
                Button(action: playRandomTrack) {
                    Label("Play Music", systemImage: "play.circle")
                        .font(.system(size: 12))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 8)
    }
    
    private func playRandomTrack() {
        if let track = musicManager.tracks.randomElement() {
            musicManager.play(track: track)
        }
    }
} 
