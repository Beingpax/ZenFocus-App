import Foundation
import AmplitudeSwift
import SwiftUI

class AnalyticsService: ObservableObject {
    private let amplitude: Amplitude
    @AppStorage("analyticsEnabled") var isEnabled: Bool = true
    
    init() {
        self.amplitude = Amplitude(configuration: Configuration(
            apiKey: "633d9616979bd07a149be788191f6640"
        ))
    }
    
    func configure() {
        // Additional configuration can be done here if needed
    }
    
    func trackEvent(_ eventName: String, properties: [String: Any]? = nil) {
        guard isEnabled else { return }
        
        amplitude.track(
            eventType: eventName,
            eventProperties: properties
        )
    }
    
    func trackAppLaunch() {
        trackEvent("app_launched")
    }
    
    func trackAppClose() {
        trackEvent("app_closed")
    }
    
    func trackAppUpdate(from oldVersion: String, to newVersion: String) {
        let properties: [String: Any] = [
            "old_version": oldVersion,
            "new_version": newVersion
        ]
        
        trackEvent("app_updated", properties: properties)
    }
    
    func setUserProperty(_ key: String, value: Any) {
        guard isEnabled else { return }
        
        let identify = Identify().set(property: key, value: value)
        amplitude.identify(identify: identify)
    }
    
    func setUserId(_ userId: String) {
        amplitude.setUserId(userId: userId)
    }
    
    func logoutUser() {
        amplitude.reset()
    }
}
