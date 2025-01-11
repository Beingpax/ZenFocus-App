import Foundation
import AVFoundation

class MusicManager: NSObject, ObservableObject {
    static let shared = MusicManager()
    
    @Published var currentTrack: MusicTrack?
    @Published var isPlaying: Bool = false
    @Published var volume: Float = 0.5 {
        didSet {
            setVolume(volume)
        }
    }
    @Published var tracks: [MusicTrack] = []
    @Published var isShuffleEnabled: Bool = false
    
    private var audioPlayer: AVAudioPlayer?
    private let musicDirectory: URL
    private var playbackQueue: [MusicTrack] = []
    
    override init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        musicDirectory = documentsPath.appendingPathComponent("Music", isDirectory: true)
        
        super.init()
        
        createMusicDirectoryIfNeeded()
        loadTrackList()
    }
    
    private func createMusicDirectoryIfNeeded() {
        do {
            try FileManager.default.createDirectory(at: musicDirectory, withIntermediateDirectories: true)
        } catch {
            ZenFocusLogger.shared.error("Failed to create music directory", error: error)
        }
    }
    
    private func loadTrackList() {
        let trackListURL = musicDirectory.appendingPathComponent("tracklist.json")
        
        do {
            let data = try Data(contentsOf: trackListURL)
            tracks = try JSONDecoder().decode([MusicTrack].self, from: data)
        } catch {
            tracks = []
            ZenFocusLogger.shared.info("No existing track list found or error loading it")
        }
    }
    
    private func saveTrackList() {
        let trackListURL = musicDirectory.appendingPathComponent("tracklist.json")
        
        do {
            let data = try JSONEncoder().encode(tracks)
            try data.write(to: trackListURL)
        } catch {
            ZenFocusLogger.shared.error("Failed to save track list", error: error)
        }
    }
    
    func importTrack(from sourceURL: URL) throws {
        let fileName = "\(UUID().uuidString).\(sourceURL.pathExtension)"
        let destinationURL = musicDirectory.appendingPathComponent(fileName)
        
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        
        let track = MusicTrack(
            title: sourceURL.deletingPathExtension().lastPathComponent,
            fileName: fileName
        )
        
        tracks.append(track)
        saveTrackList()
    }
    
    func deleteTrack(_ track: MusicTrack) {
        let fileURL = musicDirectory.appendingPathComponent(track.fileName)
        
        do {
            try FileManager.default.removeItem(at: fileURL)
            tracks.removeAll { $0.id == track.id }
            saveTrackList()
            
            if currentTrack?.id == track.id {
                stop()
            }
        } catch {
            ZenFocusLogger.shared.error("Failed to delete track", error: error)
        }
    }
    
    func playNext() {
        guard !tracks.isEmpty else { return }
        
        if isShuffleEnabled {
            if let track = tracks.randomElement() {
                play(track: track)
            }
        } else if let currentIndex = tracks.firstIndex(where: { $0.id == currentTrack?.id }) {
            let nextIndex = (currentIndex + 1) % tracks.count
            play(track: tracks[nextIndex])
        } else {
            play(track: tracks[0])
        }
    }
    
    func playPrevious() {
        guard !tracks.isEmpty else { return }
        
        if let currentIndex = tracks.firstIndex(where: { $0.id == currentTrack?.id }) {
            let previousIndex = (currentIndex - 1 + tracks.count) % tracks.count
            play(track: tracks[previousIndex])
        } else {
            play(track: tracks[0])
        }
    }
    
    func toggleShuffle() {
        isShuffleEnabled.toggle()
    }
    
    func play(track: MusicTrack) {
        let fileURL = musicDirectory.appendingPathComponent(track.fileName)
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
            audioPlayer?.delegate = self
            audioPlayer?.volume = volume
            audioPlayer?.numberOfLoops = 0 // Play once, then move to next
            audioPlayer?.play()
            currentTrack = track
            isPlaying = true
        } catch {
            ZenFocusLogger.shared.error("Failed to play track", error: error)
            playNext() // Try playing next track if current one fails
        }
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
    }
    
    func resume() {
        audioPlayer?.play()
        isPlaying = true
    }
    
    func stop() {
        audioPlayer?.stop()
        isPlaying = false
        currentTrack = nil
    }
    
    private func setVolume(_ newVolume: Float) {
        audioPlayer?.volume = newVolume
    }
}

extension MusicManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            playNext() // Automatically play next track
        } else {
            isPlaying = false
            ZenFocusLogger.shared.error("Track playback finished unsuccessfully")
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            ZenFocusLogger.shared.error("Audio decode error", error: error)
        }
        playNext() // Try playing next track if current one fails
    }
} 