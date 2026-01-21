//
//  TMDBService.swift
//  Pump Fitness
//
//  Created for Trackerio
//

import Foundation

class TMDBService {
    static let shared = TMDBService()
    
    private let accessToken = "eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiIzNzcyMTlhNmI3ZTE4ODc5YTQwYjU5NDFlZWUyZjA2NSIsIm5iZiI6MTc0NTk2MzQ4Mi41MjEsInN1YiI6IjY4MTE0OWRhNWFkMGI2N2M2NmViMjY0YyIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.KqQ7DFsQbuLKobyL9AGd5eD27ODXboi4Tw80JnKhQrg"
    
    private init() {}
    
    func search(query: String) async throws -> [TMDBItem] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.themoviedb.org/3/search/multi?query=\(encodedQuery)&include_adult=false&language=en-US&page=1") else {
            return []
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("TMDB API Error: \(response)")
            return []
        }
        
        let decoded = try JSONDecoder().decode(TMDBResponse.self, from: data)
        // Filter out people, only keep movie and tv
        return decoded.results.filter { $0.mediaType == "movie" || $0.mediaType == "tv" }
    }
}
