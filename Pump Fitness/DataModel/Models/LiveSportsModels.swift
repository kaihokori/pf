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
    let strTimeLocal: String?
    let strTimestamp: String?
    let strStatus: String? // "Match Finished", "Not Started", etc.
    let strRound: String?
    let strSeason: String?
    let strHomeGoalDetails: String?
    let strAwayGoalDetails: String?
    let strHomeRedCards: String?
    let strAwayRedCards: String?
    let strHomeYellowCards: String?
    let strAwayYellowCards: String?
    let strVenue: String?
    let strCity: String?
    let strCountry: String?
    let intSpectators: String?
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
        // Preferred: ISO8601 Timestamp (e.g., "2026-01-20T19:45:00")
        if let timestamp = strTimestamp {
            let isoFormatter = ISO8601DateFormatter()
            // TheSportsDB often omits timezone Z, implies UTC usually, or includes offset
            isoFormatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
            if let date = isoFormatter.date(from: timestamp) {
                return date
            }
            // Some responses might lack the 'Z' or offset, TheSportsDB varies.
            // Try standard formatter if ISO fails
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            if let date = formatter.date(from: timestamp) {
                return date
            }
        }
        
        // Fallback: Combine dateEvent + strTime
        guard let dateStr = dateEvent else { return nil }
        let formatter = DateFormatter()
        
        if let timeStr = strTime {
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            formatter.timeZone = TimeZone(secondsFromGMT: 0) // API times are usually GMT
            return formatter.date(from: "\(dateStr) \(timeStr)")
        } else {
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.date(from: dateStr)
        }
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
    enum GroupType {
        case standard // Matches for the specific date
        case upcoming // Fallback: Next games
        case recent   // Fallback: Past games
    }
    
    let leagueId: String
    let leagueName: String
    let events: [SportsDBEvent]
    var type: GroupType = .standard
    var id: String { leagueId }
    
    // Compatibility for existing code
    var isUpcoming: Bool { type == .upcoming }
}
