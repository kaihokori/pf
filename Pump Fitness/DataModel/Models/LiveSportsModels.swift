import Foundation

struct SportsResponse: Codable {
    let success: Bool?
    let data: [SportDefinition]?
}

struct SportDefinition: Identifiable, Codable, Hashable {
    let id: String
    let name: String
}

// Matches Response
struct MatchesResponse: Codable {
    let success: Bool?
    let data: [LeagueGroup]?
}

struct LeagueGroup: Codable, Identifiable {
    var id: String { league.name + (league.country ?? "") }
    let league: LeagueInfo
    let matches: [LiveMatch]
}

struct LeagueInfo: Codable {
    let name: String
    let country: String?
    let flag: String? // URL
    let logo: String? // URL
}

struct LiveMatch: Codable, Identifiable {
    let id: String
    let title: String
    let timestamp: Double // Milliseconds
    let status: String // "finished", "upcoming", "inprogress"
    let status_detail: String?
    let teams: MatchTeams
    let score: MatchScore?
    
    // Helper for date
    var startTime: Date {
        Date(timeIntervalSince1970: timestamp / 1000)
    }
}

struct MatchTeams: Codable {
    let home: TeamInfo
    let away: TeamInfo
}

struct TeamInfo: Codable {
    let name: String
    let code: String?
    let badge: String? // URL
}

struct MatchScore: Codable {
    let current: ScoreDetail?
    let display: String?
}

struct ScoreDetail: Codable {
    let home: Int?
    let away: Int?
}
