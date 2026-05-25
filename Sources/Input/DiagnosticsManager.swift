import Foundation

final class DiagnosticsManager {
    static let shared = DiagnosticsManager()
    
    private let logFileURL: URL
    private let maxLogSize = 1024 * 1024 // 1MB
    private let queue = DispatchQueue(label: "com.maclauncher.diagnostics", qos: .background)
    
    private init() {
        let fileManager = FileManager.default
        let logDir = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs")
            .appendingPathComponent("MacLauncher")
        
        try? fileManager.createDirectory(at: logDir, withIntermediateDirectories: true, attributes: nil)
        logFileURL = logDir.appendingPathComponent("diagnostics.log")
        
        log("--- Diagnostics Initialized ---")
    }
    
    func log(_ message: String) {
        queue.async {
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let line = "[\(timestamp)] \(message)\n"
            print(line, terminator: "")
            
            self.write(line)
            self.rotateIfNeeded()
        }
    }
    
    private func write(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        
        if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
            defer { try? fileHandle.close() }
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
        } else {
            try? data.write(to: logFileURL)
        }
    }
    
    private func rotateIfNeeded() {
        let fileManager = FileManager.default
        guard let attrs = try? fileManager.attributesOfItem(atPath: logFileURL.path),
              let size = attrs[.size] as? UInt64,
              size > maxLogSize else { return }
        
        let backupURL = logFileURL.deletingPathExtension().appendingPathExtension("old.log")
        try? fileManager.removeItem(at: backupURL)
        try? fileManager.moveItem(at: logFileURL, to: backupURL)
        log("--- Log Rotated ---")
    }
}
