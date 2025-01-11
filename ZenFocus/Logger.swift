import Foundation
import os

class ZenFocusLogger {
    static let shared = ZenFocusLogger()
    private let logger: Logger
    
    private init() {
        logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ZenFocus")
    }
    
    func error(_ message: String, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        var logMessage = "[\(fileName):\(line)] \(function) - \(message)"
        if let error = error {
            logMessage += "\nError details: \(error.localizedDescription)"
        }
        logger.error("\(logMessage)")
        
        #if DEBUG
        print("ERROR: \(logMessage)")
        #endif
    }
    
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function) - \(message)"
        logger.warning("\(logMessage)")
        
        #if DEBUG
        print("WARNING: \(logMessage)")
        #endif
    }
    
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function) - \(message)"
        logger.info("\(logMessage)")
        
        #if DEBUG
        print("INFO: \(logMessage)")
        #endif
    }
    
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function) - \(message)"
        logger.debug("\(logMessage)")
        print("DEBUG: \(logMessage)")
        #endif
    }
}