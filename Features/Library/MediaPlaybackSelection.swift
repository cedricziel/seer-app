import JellyfinClient

enum MediaPlaybackSelection {
    static func item(original: MediaItem, detailedItem: MediaItem?, selectedEpisode: MediaItem?) -> MediaItem {
        selectedEpisode ?? detailedItem ?? original
    }
}
