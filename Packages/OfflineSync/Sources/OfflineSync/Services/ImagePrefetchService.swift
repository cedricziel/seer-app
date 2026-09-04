import Foundation
import JellyfinClient
import Kingfisher
import SeerCore
import SwiftData

/// Handles prefetching and caching of images using Kingfisher
@MainActor
public final class ImagePrefetchService {
    /// Maximum number of images to prefetch per sync
    private let maxPrefetchCount = 200

    /// Image width for prefetched thumbnails
    private let prefetchImageWidth = 300

    public init() {}

    /// Prefetches primary images for recently synced items
    public func prefetchImages(
        for serverConfig: ServerConfiguration,
        modelContext: ModelContext,
        service _: JellyfinService
    ) async throws {
        // Get most recently synced items without local images
        let configID = serverConfig.id
        let descriptor = FetchDescriptor<CachedMediaItem>(
            predicate: #Predicate {
                $0.serverConfigurationID == configID &&
                    $0.hasLocalPrimaryImage == false
            },
            sortBy: [SortDescriptor(\.lastSyncedAt, order: .reverse)]
        )
        var fetchDescriptor = descriptor
        fetchDescriptor.fetchLimit = maxPrefetchCount

        let items = try modelContext.fetch(fetchDescriptor)

        // Build URLs for prefetching
        let urls = items.compactMap { item -> URL? in
            buildImageURL(
                serverURL: serverConfig.jellyfinURL,
                itemId: item.id,
                type: "Primary",
                width: prefetchImageWidth
            )
        }

        // Prefetch using Kingfisher
        await prefetchURLs(urls)

        // Mark items as having local images
        for item in items {
            item.hasLocalPrimaryImage = true
        }
        try modelContext.save()
    }

    /// Prefetches a single image for an item
    public func prefetchImage(
        for item: CachedMediaItem,
        serverURL: URL,
        type: String = "Primary"
    ) async {
        guard let url = buildImageURL(
            serverURL: serverURL,
            itemId: item.id,
            type: type,
            width: prefetchImageWidth
        ) else { return }

        await prefetchURLs([url])
    }

    /// Checks if an image is cached locally
    public func isImageCached(itemId: String, serverURL: URL, type: String = "Primary") -> Bool {
        guard let url = buildImageURL(
            serverURL: serverURL,
            itemId: itemId,
            type: type,
            width: prefetchImageWidth
        ) else { return false }

        return ImageCache.default.isCached(forKey: url.absoluteString)
    }

    /// Clears expired images from cache
    public func clearExpiredCache() {
        ImageCache.default.cleanExpiredCache()
    }

    /// Gets current cache size in bytes
    public func getCacheSize() async -> UInt {
        await withCheckedContinuation { continuation in
            ImageCache.default.calculateDiskStorageSize { result in
                switch result {
                case let .success(size):
                    continuation.resume(returning: size)
                case .failure:
                    continuation.resume(returning: 0)
                }
            }
        }
    }

    // MARK: - Private Methods

    private func buildImageURL(
        serverURL: URL,
        itemId: String,
        type: String,
        width: Int
    ) -> URL? {
        // appendingPathComponent keeps any reverse-proxy base path (e.g. /jellyfin)
        var components = URLComponents(
            url: serverURL.appendingPathComponent("Items/\(itemId)/Images/\(type)"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "maxWidth", value: String(width)),
            URLQueryItem(name: "quality", value: "90")
        ]
        return components?.url
    }

    private func prefetchURLs(_ urls: [URL]) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let prefetcher = ImagePrefetcher(urls: urls)
            prefetcher.start()
            // Kingfisher prefetcher runs asynchronously, so we just start it and continue
            continuation.resume()
        }
    }
}
