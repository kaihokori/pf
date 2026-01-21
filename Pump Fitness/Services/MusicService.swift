//
//  MusicService.swift
//  Pump Fitness
//
//  Created for Trackerio.
//

import Foundation
import MusicKit
import MediaPlayer
import SwiftUI
import Combine

struct SongModel: Identifiable, Hashable {
    let id: String
    let title: String
    let artist: String
    let artwork: Artwork?
    let artworkUIImage: UIImage?
    let playCount: Int
    let skipCount: Int
    let lastPlayedDate: Date?
}

struct ArtistModel: Identifiable, Hashable {
    let id: String
    let name: String
    let artworkUIImage: UIImage?
    let playCount: Int
}

struct AlbumModel: Identifiable, Hashable {
    let id: String
    let title: String
    let artist: String
    let artworkUIImage: UIImage?
    let playCount: Int
}

@MainActor
class MusicService: ObservableObject {
    static let shared = MusicService()
    
    @Published var isAuthorized = false
    @Published var topGenre: String = "-"
    @Published var topArtist: String = "-"
    @Published var totalMinutes: Int = 0
    
    // New Top Stats
    @Published var topSongs: [SongModel] = []
    @Published var topArtists: [ArtistModel] = []
    @Published var topAlbums: [AlbumModel] = []
    @Published var genreDistribution: [(String, Double)] = []
    
    // Authorization status can be checked on init, but explicit request is better for UX
    init() {
        // Check current status
        Task {
            let status = MusicAuthorization.currentStatus
            if status == .authorized {
                self.isAuthorized = true
                await fetchData()
            }
        }
    }
    
    func requestAuthorization() async {
        let status = await MusicAuthorization.request()
        if status == .authorized {
            self.isAuthorized = true
            await fetchData()
        } else {
            // Also check MPMediaLibrary permission as fallback
            let mpStatus = await MPMediaLibrary.requestAuthorization()
            if mpStatus == .authorized {
                self.isAuthorized = true
                await fetchData()
            }
        }
    }
    
    func fetchData() async {
        // Fallback to local media library for "All Time" stats
        // MusicKit API is great for recents, but MPMediaLibrary is the source of truth for "All Time" play counts.
        fetchTopLibraryStats()
    }
    
    private func fetchTopLibraryStats() {
        guard MPMediaLibrary.authorizationStatus() == .authorized else { return }
        
        let query = MPMediaQuery.songs()
        guard let items = query.items else { return }
        
        // --- 1. Top 10 Songs ---
        let sortedSongs = items.sorted { $0.playCount > $1.playCount }
        let top10 = sortedSongs.prefix(10)
        
        self.topSongs = top10.map { item in
            SongModel(
                id: "\(item.persistentID)",
                title: item.title ?? "Unknown Title",
                artist: item.artist ?? "Unknown Artist",
                artwork: nil,
                artworkUIImage: item.artwork?.image(at: CGSize(width: 100, height: 100)),
                playCount: item.playCount,
                skipCount: item.skipCount,
                lastPlayedDate: item.lastPlayedDate
            )
        }
        
        // --- 2. Top 5 Artists ---
        // Aggregate play counts by Artist
        var artistCounts: [String: Int] = [:]
        var artistIds: [String: MPMediaEntityPersistentID] = [:] // Keep one ID for stability
        var artistRepresentative: [String: MPMediaItem] = [:]

        for item in items {
            guard let artist = item.artist else { continue }
            artistCounts[artist, default: 0] += item.playCount
            if artistIds[artist] == nil {
                artistIds[artist] = item.albumArtistPersistentID // or artistPersistentID
            }
            // Capture an item with artwork for this artist
            if artistRepresentative[artist] == nil {
                artistRepresentative[artist] = item
            } else if artistRepresentative[artist]?.artwork == nil, item.artwork != nil {
                 artistRepresentative[artist] = item
            }
        }
        
        let sortedArtists = artistCounts.sorted { $0.value > $1.value }.prefix(5)
        self.topArtists = sortedArtists.map { (name, count) in
            ArtistModel(
                id: name,
                name: name,
                artworkUIImage: artistRepresentative[name]?.artwork?.image(at: CGSize(width: 100, height: 100)),
                playCount: count
            )
        }
        
        // --- 3. Top 5 Albums ---
        var albumCounts: [String: Int] = [:]
        var albumObjs: [String: MPMediaItem] = [:] // Keep representative item
        
        for item in items {
            guard let title = item.albumTitle else { continue }
            // Key by title + artist to avoid collisions
            let key = "\(title)|\(item.albumArtist ?? item.artist ?? "")"
            albumCounts[key, default: 0] += item.playCount
            if albumObjs[key] == nil {
                albumObjs[key] = item
            }
        }
        
        let sortedAlbums = albumCounts.sorted { $0.value > $1.value }.prefix(5)
        self.topAlbums = sortedAlbums.map { (key, count) in
            let item = albumObjs[key]!
            return AlbumModel(
                id: "\(item.albumPersistentID)",
                title: item.albumTitle ?? "",
                artist: item.albumArtist ?? item.artist ?? "",
                artworkUIImage: item.artwork?.image(at: CGSize(width: 120, height: 120)),
                playCount: count
            )
        }
        
        // --- Stats for Header ---
        if let topArtist = topArtists.first {
            self.topArtist = topArtist.name
        }
        
        var genreCounts: [String: Int] = [:]
        for item in items {
            if let genre = item.genre, genre != "Music" {
                genreCounts[genre, default: 0] += 1
            }
        }
        
        if let topGenre = genreCounts.max(by: { $0.value < $1.value })?.key {
            self.topGenre = topGenre
        }
        
        let total = Double(items.count)
        self.genreDistribution = genreCounts.map { ($0.key, Double($0.value) / total) }
            .sorted { $0.1 > $1.1 }
            
        let totalTime = items.reduce(0.0) { $0 + $1.playbackDuration }
        self.totalMinutes = Int(totalTime / 60)
    }
}


private extension Array where Element: Hashable {
    func mostFrequent() -> Element? {
        let counts = reduce(into: [:]) { $0[$1, default: 0] += 1 }
        return counts.max(by: { $0.value < $1.value })?.key
    }
    
    func calculateDistribution() -> [(String, Double)] {
        guard !isEmpty else { return [] }
        let counts = reduce(into: [:]) { $0[$1, default: 0] += 1 }
        let total = Double(count)
        return counts.map { (convertGenre($0.key), Double($0.value) / total) } // Convert & Calculate
                     .sorted { $0.1 > $1.1 }
    }
    
    private func convertGenre(_ element: Element) -> String {
        return (element as? String) ?? "\(element)"
    }
}
