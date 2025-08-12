import SwiftData
import Foundation

@Model
final class Recording {
    var id: UUID
    var filename: String
    var fileURL: URL
    var createdAt: Date
    var duration: TimeInterval?
    var fileSize: Int64?
    
    init(filename: String, fileURL: URL, createdAt: Date = Date()) {
        self.id = UUID()
        self.filename = filename
        self.fileURL = fileURL
        self.createdAt = createdAt
    }
}

@Model
final class AppSettings {
    var id: UUID
    var isMonitoringEnabled: Bool
    var lastUpdated: Date
    
    init(isMonitoringEnabled: Bool = false) {
        self.id = UUID()
        self.isMonitoringEnabled = isMonitoringEnabled
        self.lastUpdated = Date()
    }
}
