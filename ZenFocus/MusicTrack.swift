import Foundation

struct MusicTrack: Identifiable, Codable {
    let id: UUID
    let title: String
    let fileName: String
    let dateAdded: Date
    
    init(id: UUID = UUID(), title: String, fileName: String, dateAdded: Date = Date()) {
        self.id = id
        self.title = title
        self.fileName = fileName
        self.dateAdded = dateAdded
    }
} 