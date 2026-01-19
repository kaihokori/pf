import Foundation

// MARK: - API Responses

struct SportsDBLeaguesResponse: Codable {
    let leagues: [SportsDBLeague]?
}

struct SportsDBEventsResponse: Codable {
    let events: [SportsDBEvent]?
}

struct SportsDBTeamsResponse: Codable {
    let teams: [SportsDBTeam]?
}

// MARK: - Models

struct SportsDBLeague: Codable, Identifiable, Hashable {
    let idLeague: String
    let strLeague: String
    let strSport: String?
    let strLeagueAlternate: String?
    
    var id: String { idLeague }
}

struct SportsDBEvent: Codable, Identifiable, Hashable {
    let idEvent: String
    let idLeague: String?
    let strLeague: String?
    let strHomeTeam: String?
    let strAwayTeam: String?
    let intHomeScore: String?
    let intAwayScore: String?
    let dateEvent: String?
    let strTime: String?
    let strStatus: String? // "Match Finished", "Not Started", etc.
    let strThumb: String?
    let strVideo: String?
    let strPoster: String?
    let strSquare: String?
    
    var id: String { idEvent }
    
    // Computed properties for UI
    var homeScore: Int? {
        guard let score = intHomeScore else { return nil }
        return Int(score)
    }
    
    var awayScore: Int? {
        guard let score = intAwayScore else { return nil }
        return Int(score)
    }
    
    var eventDate: Date? {
        // Format: 2024-10-12
        guard let dateStr = dateEvent else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateStr)
    }
    
    var eventTime: String {
        guard let time = strTime else { return "TBD" }
        return String(time.prefix(5)) // "20:00:00" -> "20:00"
    }
}

struct SportsDBTeam: Codable, Identifiable {
    let idTeam: String
    let strTeam: String
    let strTeamBadge: String?
    
    var id: String { idTeam }
}

// Helper for UI grouping
struct LeagueEventsGroup: Identifiable {
    let leagueId: String
    let leagueName: String
    let events: [SportsDBEvent]
    var id: String { leagueId }
}
