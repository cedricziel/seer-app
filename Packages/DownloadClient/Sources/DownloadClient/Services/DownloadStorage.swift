import Foundation

/// Actor for managing downloaded file storage
public actor DownloadStorage {
    /// Base downloads directory
    private let downloadsDirectory: URL

    public enum StorageError: LocalizedError, Sendable {
        case directoryCreationFailed
        case fileNotFound
        case moveFileFailed
        case deleteFailed
        case insufficientStorage
        case storageUnavailable

        public var errorDescription: String? {
            switch self {
            case .directoryCreationFailed:
                "Failed to create downloads directory"
            case .fileNotFound:
                "Downloaded file not found"
            case .moveFileFailed:
                "Failed to move downloaded file"
            case .deleteFailed:
                "Failed to delete file"
            case .insufficientStorage:
                "Insufficient storage space"
            case .storageUnavailable:
                "Storage location unavailable"
            }
        }
    }

    public init() throws {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw StorageError.storageUnavailable
        }
        downloadsDirectory = documentsPath.appendingPathComponent("Downloads", isDirectory: true)

        // Create downloads directory if needed
        if !FileManager.default.fileExists(atPath: downloadsDirectory.path) {
            try FileManager.default.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
        }
    }

    // MARK: - Directory Management

    /// Get the directory for a specific server and media type
    public func directoryForMedia(
        serverID: String,
        mediaType: String,
        itemID: String
    ) -> URL {
        downloadsDirectory
            .appendingPathComponent(serverID, isDirectory: true)
            .appendingPathComponent(mediaType, isDirectory: true)
            .appendingPathComponent(itemID, isDirectory: true)
    }

    /// Ensure a directory exists, creating it if needed
    public func ensureDirectoryExists(_ url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    // MARK: - File Operations

    /// Move a downloaded file to its permanent location
    public func moveDownloadedFile(
        from tempURL: URL,
        serverID: String,
        mediaType: String,
        itemID: String,
        fileName: String
    ) throws -> String {
        let directory = directoryForMedia(serverID: serverID, mediaType: mediaType, itemID: itemID)
        try ensureDirectoryExists(directory)

        let destinationURL = directory.appendingPathComponent(fileName)

        // Remove existing file if present
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        try FileManager.default.moveItem(at: tempURL, to: destinationURL)

        // Mark as excluded from iCloud backup
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableURL = destinationURL
        try mutableURL.setResourceValues(resourceValues)

        // Return relative path from downloads directory
        let relativePath = "\(serverID)/\(mediaType)/\(itemID)/\(fileName)"
        return relativePath
    }

    /// Get full URL for a relative path
    public func fullURL(forRelativePath relativePath: String) -> URL {
        downloadsDirectory.appendingPathComponent(relativePath)
    }

    /// Check if a downloaded file exists
    public func fileExists(relativePath: String) -> Bool {
        let url = fullURL(forRelativePath: relativePath)
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// Delete a downloaded file and clean up empty directories
    public func deleteFile(relativePath: String) throws {
        let url = fullURL(forRelativePath: relativePath)

        guard FileManager.default.fileExists(atPath: url.path) else {
            return // Already deleted
        }

        try FileManager.default.removeItem(at: url)

        // Clean up empty parent directories
        try cleanupEmptyDirectories(from: url.deletingLastPathComponent())
    }

    /// Delete all files for a specific item
    public func deleteAllFiles(serverID: String, mediaType: String, itemID: String) throws {
        let directory = directoryForMedia(serverID: serverID, mediaType: mediaType, itemID: itemID)

        guard FileManager.default.fileExists(atPath: directory.path) else {
            return
        }

        try FileManager.default.removeItem(at: directory)

        // Clean up empty parent directories
        try cleanupEmptyDirectories(from: directory.deletingLastPathComponent())
    }

    /// Clean up empty directories recursively up to downloads directory
    private func cleanupEmptyDirectories(from url: URL) throws {
        guard url.path.hasPrefix(downloadsDirectory.path), url != downloadsDirectory else {
            return
        }

        let contents = try? FileManager.default.contentsOfDirectory(atPath: url.path)
        if contents?.isEmpty == true {
            try FileManager.default.removeItem(at: url)
            try cleanupEmptyDirectories(from: url.deletingLastPathComponent())
        }
    }

    // MARK: - Storage Management

    /// Calculate total size of all downloads
    public func totalDownloadedSize() throws -> Int64 {
        var totalSize: Int64 = 0

        guard let enumerator = FileManager.default.enumerator(
            at: downloadsDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            if resourceValues.isRegularFile == true {
                totalSize += Int64(resourceValues.fileSize ?? 0)
            }
        }

        return totalSize
    }

    /// Get available storage space
    public func availableStorageSpace() throws -> Int64 {
        let resourceValues = try downloadsDirectory
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return resourceValues.volumeAvailableCapacityForImportantUsage ?? 0
    }

    /// Check if there's enough space for a download
    public func hasSpaceForDownload(estimatedBytes: Int64) throws -> Bool {
        let available = try availableStorageSpace()
        // Keep at least 500MB buffer
        let buffer: Int64 = 500 * 1024 * 1024
        return available - buffer >= estimatedBytes
    }

    /// Get file size for a downloaded file
    public func fileSize(relativePath: String) throws -> Int64 {
        let url = fullURL(forRelativePath: relativePath)
        let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(resourceValues.fileSize ?? 0)
    }

    // MARK: - Temporary Files

    /// Get temporary directory for in-progress downloads
    public var temporaryDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("downloads", isDirectory: true)
    }

    /// Ensure temporary directory exists
    public func ensureTemporaryDirectoryExists() throws {
        try ensureDirectoryExists(temporaryDirectory)
    }

    /// Clean up old temporary files
    public func cleanupTemporaryFiles() throws {
        let tempDir = temporaryDirectory
        guard FileManager.default.fileExists(atPath: tempDir.path) else { return }

        let contents = try FileManager.default.contentsOfDirectory(
            at: tempDir,
            includingPropertiesForKeys: [.creationDateKey]
        )

        let cutoffDate = Date().addingTimeInterval(-24 * 60 * 60) // 24 hours ago

        for fileURL in contents {
            let resourceValues = try fileURL.resourceValues(forKeys: [.creationDateKey])
            if let creationDate = resourceValues.creationDate, creationDate < cutoffDate {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }
}
