//
//  EntertainmentModels.swift
//  Pump Fitness
//
//  Created for Trackerio
//

import Foundation

struct TMDBItem: Identifiable, Codable, Hashable {
    let id: Int
    let title: String? // For movies
    let name: String? // For TV
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String? // For movies
    let firstAirDate: String? // For TV
    let mediaType: String? // "movie" or "tv"
    let genreIds: [Int]?
    
    var displayTitle: String {
        title ?? name ?? "Unknown"
    }
    
    var displayDate: String {
        let dateString = releaseDate ?? firstAirDate
        guard let dateString, !dateString.isEmpty else { return "" }
        // Simple year extraction
        let prefix = dateString.prefix(4)
        return String(prefix)
    }
    
    var fullPosterUrl: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(path)")
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, name, overview, mediaType = "media_type"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case genreIds = "genre_ids"
    }
}

struct TMDBResponse: Codable {
    let results: [TMDBItem]
}


// Moved to Account.swift for persistence
// struct WatchedEntertainmentItem: Identifiable, Codable, Hashable { ... }

