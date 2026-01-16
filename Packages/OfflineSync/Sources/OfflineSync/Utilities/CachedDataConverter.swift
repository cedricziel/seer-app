import Foundation
import JellyfinClient
import SeerCore

/// Utility for converting between cached and live data types
public struct CachedDataConverter {
    public init() {}

    /// Converts a CachedMediaItem to MediaItem for display
    public func convertToMediaItem(_ cached: CachedMediaItem) -> MediaItem {
        MediaItem(
            id: cached.id,
            name: cached.name,
            overview: cached.overview,
            year: cached.year,
            communityRating: cached.communityRating,
            officialRating: cached.officialRating,
            runTimeTicks: cached.runTimeTicks,
            type: MediaItem.MediaType(rawValue: cached.mediaType) ?? .unknown,
            seriesName: cached.seriesName,
            seriesId: cached.seriesId,
            seasonName: cached.seasonName,
            indexNumber: cached.indexNumber,
            parentIndexNumber: cached.parentIndexNumber,
            premiereDate: cached.premiereDate,
            userData: convertToUserData(cached)
        )
    }

    /// Converts cached user data to MediaItem.UserData
    public func convertToUserData(_ cached: CachedMediaItem) -> MediaItem.UserData? {
        var json: [String: Any] = [:]
        if let ticks = cached.playbackPositionTicks { json["PlaybackPositionTicks"] = ticks }
        if let count = cached.playCount { json["PlayCount"] = count }
        json["IsFavorite"] = cached.isFavorite
        json["Played"] = cached.isPlayed
        if let date = cached.lastPlayedDate {
            let formatter = ISO8601DateFormatter()
            json["LastPlayedDate"] = formatter.string(from: date)
        }

        guard let data = try? JSONSerialization.data(withJSONObject: json),
              let userData = try? JSONDecoder().decode(MediaItem.UserData.self, from: data)
        else {
            return nil
        }
        return userData
    }

    /// Converts a CachedLibrary to Library for display
    public func convertToLibrary(_ cached: CachedLibrary) -> Library? {
        let json: [String: Any] = [
            "Id": cached.id,
            "Name": cached.name,
            "CollectionType": cached.collectionType ?? ""
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: json),
              let library = try? JSONDecoder().decode(Library.self, from: data)
        else {
            return nil
        }
        return library
    }

    /// Creates UserData from raw values
    public func createUserData(
        playbackPositionTicks: Int64?,
        playCount: Int?,
        isFavorite: Bool?,
        played: Bool?,
        lastPlayedDate: Date?
    ) -> MediaItem.UserData? {
        var json: [String: Any] = [:]
        if let ticks = playbackPositionTicks { json["PlaybackPositionTicks"] = ticks }
        if let count = playCount { json["PlayCount"] = count }
        if let fav = isFavorite { json["IsFavorite"] = fav }
        if let played { json["Played"] = played }
        if let date = lastPlayedDate {
            let formatter = ISO8601DateFormatter()
            json["LastPlayedDate"] = formatter.string(from: date)
        }

        guard let data = try? JSONSerialization.data(withJSONObject: json),
              let userData = try? JSONDecoder().decode(MediaItem.UserData.self, from: data)
        else {
            return nil
        }
        return userData
    }
}
