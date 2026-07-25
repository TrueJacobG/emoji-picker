import Foundation
import OSLog

struct InsertionLogger {
    // Set to true to enable logging for debugging
    private static let isEnabled = false
    
    private static let logger = Logger(
        subsystem: "com.github.truejacobg.emoji-picker",
        category: "insertion"
    )
    
    private static let logFileURL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Library")
        .appendingPathComponent("Logs")
        .appendingPathComponent("emoji-picker-insertion.log")
    
    static func log(_ tag: String, _ message: String) {
        guard isEnabled else { return }
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let formattedMessage = "[\(timestamp)] [\(tag)] \(message)"
        
        // Log to unified logging system
        logger.info("\(formattedMessage, privacy: .public)")
        
        // Also write to file
        appendToFile(formattedMessage)
    }
    
    static func clearLog() {
        guard isEnabled else { return }
        try? "".write(to: logFileURL, atomically: true, encoding: .utf8)
    }
    
    private static func appendToFile(_ message: String) {
        let fileExists = FileManager.default.fileExists(atPath: logFileURL.path)
        if !fileExists {
            try? FileManager.default.createDirectory(
                at: logFileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        }
        
        guard let fileHandle = FileHandle(forWritingAtPath: logFileURL.path) else {
            try? message.write(to: logFileURL, atomically: true, encoding: .utf8)
            return
        }
        
        defer {
            try? fileHandle.close()
        }
        
        fileHandle.seekToEndOfFile()
        guard let data = "\(message)\n".data(using: .utf8) else { return }
        fileHandle.write(data)
    }
}