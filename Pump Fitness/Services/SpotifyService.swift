//
//  SpotifyService.swift
//  Pump Fitness
//
//  Created for Trackerio.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class SpotifyService: ObservableObject {
    static let shared = SpotifyService()
    
    @Published var isAuthorized = false
    @Published var isConnected = false
    
    // Cache
    @Published var topSongs: [SongModel] = []
    @Published var topArtists: [ArtistModel] = []
    @Published var topAlbums: [AlbumModel] = []
    @Published var genreDistribution: [(String, Double)] = []
    
    init() {
        // In a real app, check Keychain for tokens
        self.isConnected = UserDefaults.standard.bool(forKey: "spotify_connected")
        if self.isConnected {
            self.isAuthorized = true
            Task { await fetchData() }
        }
    }
    
    func connect() async -> Bool {
        // Simulate OAuth flow
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        self.isConnected = true
        self.isAuthorized = true
        UserDefaults.standard.set(true, forKey: "spotify_connected")
        await fetchData()
        return true
    }
    
    func disconnect() {
        self.isConnected = false
        self.isAuthorized = false
        UserDefaults.standard.set(false, forKey: "spotify_connected")
        clearData()
    }
    
    func fetchData() async {
        guard isConnected else { return }
        // Mock data for Spotify
        // In a real implementation, this would call Spotify Web API
        
        self.topSongs = [
            SongModel(id: "sp_1", title: "Blinding Lights", artist: "The Weeknd", artwork: nil, artworkUIImage: UIImage(systemName: "music.note"), playCount: 150, skipCount: 0, lastPlayedDate: Date()),
            SongModel(id: "sp_2", title: "As It Was", artist: "Harry Styles", artwork: nil, artworkUIImage: UIImage(systemName: "music.quarternote.3"), playCount: 120, skipCount: 2, lastPlayedDate: Date()),
            SongModel(id: "sp_3", title: "Heat Waves", artist: "Glass Animals", artwork: nil, artworkUIImage: UIImage(systemName: "music.mic"), playCount: 110, skipCount: 1, lastPlayedDate: Date())
        ]
        
        self.topArtists = [
            ArtistModel(id: "sp_a1", name: "The Weeknd", artworkUIImage: nil, playCount: 500),
            ArtistModel(id: "sp_a2", name: "Taylor Swift", artworkUIImage: nil, playCount: 450),
            ArtistModel(id: "sp_a3", name: "Drake", artworkUIImage: nil, playCount: 400)
        ]
        
        self.topAlbums = [
            AlbumModel(id: "sp_al1", title: "After Hours", artist: "The Weeknd", artworkUIImage: nil, playCount: 200),
            AlbumModel(id: "sp_al2", title: "Midnights", artist: "Taylor Swift", artworkUIImage: nil, playCount: 180)
        ]
        
        self.genreDistribution = [
            ("Pop", 0.4),
            ("R&B", 0.3),
            ("Hip-Hop", 0.3)
        ]
    }
    
    private func clearData() {
        topSongs = []
        topArtists = []
        topAlbums = []
        genreDistribution = []
    }
}
