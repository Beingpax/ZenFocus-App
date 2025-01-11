import Foundation
import AppKit
import SwiftUI

class ReminderSoundManager: ObservableObject {
    private var timer: Timer?
    
    @AppStorage("reminderInterval") private var reminderInterval = 600 // 10 minutes in seconds
    @AppStorage("reminderSound") private var reminderSound = "Glass"
    
    init() {}
    
    func startReminderTimer() {
        stopReminderTimer()
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(reminderInterval), repeats: true) { [weak self] _ in
            self?.playReminderSound()
        }
    }
    
    func stopReminderTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func playReminderSound() {
        if let sound = NSSound(named: NSSound.Name(reminderSound)) {
            sound.play()
        } else {
            print("Error: Could not play reminder sound")
            // You could also post a notification here to inform the user
        }
    }
}
