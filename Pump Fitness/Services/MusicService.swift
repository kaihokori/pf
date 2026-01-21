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
    
    // Toggleable sources
    @AppStorage("music.appleMusicEnabled") var isAppleMusicEnabled: Bool = true {
        didSet { Task { await fetchData() } }
    }
    @AppStorage("music.spotifyEnabled") var isSpotifyEnabled: Bool = false {
        didSet { Task { await fetchData() } }
    }
    
    // New Top Stats
    @Published var topSongs: [SongModel] = []
    @Published var topArtists: [ArtistModel] = []
    @Published var topAlbums: [AlbumModel] = []
    @Published var genreDistribution: [(String, Double)] = []
    
    init() {
        Task {
            let status = MusicAuthorization.currentStatus
            if status == .authorized {
                self.isAuthorized = true
            }
            // Check Spotify status too
            if SpotifyService.shared.isConnected {
                self.isAuthorized = true
            }
            await fetchData()
        }
    }
    
    func requestAuthorization() async {
        let status = await MusicAuthorization.request()
        if status == .authorized {
            self.isAuthorized = true
        } else {
            let mpStatus = await MPMediaLibrary.requestAuthorization()
            if mpStatus == .authorized {
                self.isAuthorized = true
            }
        }
        await fetchData()
    }
    
    func fetchData() async {
        var allSongs: [SongModel] = []
        var allArtists: [ArtistModel] = []
        var allAlbums: [AlbumModel] = []
        var allGenres: [String] = []
        var totalDuration: Double = 0
        
        // 1. Fetch Apple Music (Local Library)
        if isAppleMusicEnabled && (MusicAuthorization.currentStatus == .authorized || MPMediaLibrary.authorizationStatus() == .authorized) {
            let (amSongs, amArtists, amAlbums, amGenres, amTime) = fetchAppleMusicStats()
            allSongs.append(contentsOf: amSongs)
            allArtists.append(contentsOf: amArtists)
            allAlbums.append(contentsOf: amAlbums)
            allGenres.append(contentsOf: amGenres)
            totalDuration += amTime
        }
        
        // 2. Fetch Spotify
        if isSpotifyEnabled && SpotifyService.shared.isConnected {
            await SpotifyService.shared.fetchData()
            allSongs.append(contentsOf: SpotifyService.shared.topSongs)
            allArtists.append(contentsOf: SpotifyService.shared.topArtists)
            allAlbums.append(contentsOf: SpotifyService.shared.topAlbums)
            // Approximate genre handling for demo
             SpotifyService.shared.genreDistribution.forEach { (genre, pct) in
                 let count = Int(pct * 100)
                 allGenres.append(contentsOf: Array(repeating: genre, count: count))
             }
        }
        
        // 3. Merge & Sort
        processMergedData(songs: allSongs, artists: allArtists, albums: allAlbums, genres: allGenres, duration: totalDuration)
    }
    
    private func fetchAppleMusicStats() -> ([SongModel], [ArtistModel], [AlbumModel], [String], Double) {
         guard MPMediaLibrary.authorizationStatus() == .authorized else { return ([], [], [], [], 0) }
         
         let query = MPMediaQuery.songs()
         guard let items = query.items else { return ([], [], [], [], 0) }
         
         // Songs
         let songs = items.map { item in
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
         
         // Artists
         var artistCounts: [String: Int] = [:]
         var artistRepresentative: [String: MPMediaItem] = [:]
         for item in items {
             guard let artist = item.artist else { continue }
             artistCounts[artist, default: 0] += item.playCount
             if artistRepresentative[artist] == nil { artistRepresentative[artist] = item }
             else if artistRepresentative[artist]?.artwork == nil, item.artwork != nil { artistRepresentative[artist] = item }
         }
         let artists = artistCounts.map { (name, count) in
             ArtistModel(
                 id: name,
                 name: name,
                 artworkUIImage: artistRepresentative[name]?.artwork?.image(at: CGSize(width: 100, height: 100)),
                 playCount: count
             )
         }
         
         // Albums
         var albumCounts: [String: Int] = [:]
         var albumObjs: [String: MPMediaItem] = [:]
         for item in items {
            guard let title = item.albumTitle else { continue }
            let key = "\(title)|\(item.albumArtist ?? item.artist ?? "")"
            albumCounts[key, default: 0] += item.playCount
            if albumObjs[key] == nil { albumObjs[key] = item }
         }
         let albums = albumCounts.map { (key, count) -> AlbumModel in
             let item = albumObjs[key]!
             return AlbumModel(
                 id: "\(item.albumPersistentID)",
                 title: item.albumTitle ?? "",
                 artist: item.albumArtist ?? item.artist ?? "",
                 artworkUIImage: item.artwork?.image(at: CGSize(width: 120, height: 120)),
                 playCount: count
             )
         }
         
         // Genres
         var genres: [String] = []
         for item in items {
             if let g = item.genre, g != "Music" { genres.append(g) }
         }
         
         let totalDuration = items.reduce(0.0) { $0 + $1.playbackDuration }
         
         return (songs, artists, albums, genres, totalDuration)
    }
    
    private func processMergedData(songs: [SongModel], artists: [ArtistModel], albums: [AlbumModel], genres: [String], duration: Double) {
        // Sort Songs (Top 20)
        self.topSongs = Array(songs.sorted { $0.playCount > $1.playCount }.prefix(20))
        
        // Merge Artists (Combine counts for same artist name)
        var artistMap: [String: ArtistModel] = [:]
        for var art in artists {
            if let existing = artistMap[art.name] {
                let newCount = existing.playCount + art.playCount
                // Prefer artwork that exists
                let img = existing.artworkUIImage ?? art.artworkUIImage
                art = ArtistModel(id: existing.id, name: art.name, artworkUIImage: img, playCount: newCount)
            }
            artistMap[art.name] = art
        }
        self.topArtists = Array(artistMap.values.sorted { $0.playCount > $1.playCount }.prefix(10))
        if let first = self.topArtists.first { self.topArtist = first.name }
        
        // Merge Albums (Combine counts for same title+artist)
        var albumMap: [String: AlbumModel] = [:]
        for var alb in albums {
            let key = "\(alb.title)|\(alb.artist)"
            if let existing = albumMap[key] {
                let newCount = existing.playCount + alb.playCount
                let img = existing.artworkUIImage ?? alb.artworkUIImage
                alb = AlbumModel(id: existing.id, title: alb.title, artist: alb.artist, artworkUIImage: img, playCount: newCount)
            }
            albumMap[key] = alb
        }
        self.topAlbums = Array(albumMap.values.sorted { $0.playCount > $1.playCount }.prefix(10))
        
        // Genres
        let genreCounts = genres.reduce(into: [:]) { $0[$1, default: 0] += 1 }
        let totalGenres = Double(genres.count)
        if totalGenres > 0 {
            self.genreDistribution = genreCounts.map { ($0.key, Double($0.value) / totalGenres) }
                .sorted { $0.1 > $1.1 }
            if let top = self.genreDistribution.first?.0 { self.topGenre = top }
        } else {
             self.genreDistribution = []
             self.topGenre = "-"
        }
        
        self.totalMinutes = Int(duration / 60)
    }
}
