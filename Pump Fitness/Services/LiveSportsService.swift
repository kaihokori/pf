import Foundation
import Combine

@MainActor
class LiveSportsService: ObservableObject {
    static let shared = LiveSportsService()
    
    private let apiKey = "050f50df774561a84ad00a8fd56f7c55"
    private let baseURL = "https://api.sportsrc.org/v2/"
    
    @Published var availableSports: [SportDefinition] = []
    @Published var matches: [String: [LeagueGroup]] = [:] // Keyed by sport ID
    
    func fetchSports() async {
        guard let url = URL(string: "https://api.sportsrc.org/?data=sports") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let result = try JSONDecoder().decode(SportsResponse.self, from: data)
            if let sports = result.data {
                self.availableSports = sports
            }
        } catch {
            print("Error fetching sports: \(error)")
        }
    }
    
    func fetchMatches(for sportId: String) async {
        // Fetch live and upcoming
        // Note: The API requires separate calls or maybe supports multiple statuses?
        // Docs: &status=inprogress
        // Let's fetch all (default) or specify. 
        // Docs say: Get Live, Upcoming, or Finished matches.
        // If we want "schedule, live scores", we probably want upcoming and inprogress.
        // Let's try fetching "visual" which usually implies a mix or just fetch without status to get default?
        // Let's make 2 calls for now to be safe and merge, or just 1 if supported.
        // The API seems to filter by status single value.
        
        // Let's just fetch "inprogress" (live) and "upcoming" (schedule).
        
        for status in ["inprogress", "upcoming"] {
            guard let url = URL(string: "\(baseURL)?type=matches&sport=\(sportId)&status=\(status)") else { continue }
            
            var request = URLRequest(url: url)
            request.addValue(apiKey, forHTTPHeaderField: "X-API-KEY")
            
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                let result = try JSONDecoder().decode(MatchesResponse.self, from: data)
                
                if let groups = result.data {
                    // primitive merge
                    var current = self.matches[sportId] ?? []
                    // remove existing of this status to replace? Or just append?
                    // Grouping is by League. Merging is tricky.
                    // Let's just rebuild.
                    if status == "inprogress" {
                        current.removeAll() // Start fresh on first call
                    }
                    current.append(contentsOf: groups)
                    self.matches[sportId] = current
                }
            } catch {
                print("Error fetching matches for \(sportId) status \(status): \(error)")
            }
        }
    }
    
    func getStreamLink(matchId: String) async -> String? {
        guard let url = URL(string: "\(baseURL)?type=detail&id=\(matchId)") else { return nil }
        var request = URLRequest(url: url)
        request.addValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        
        struct DetailResponse: Codable {
            struct MatchData: Codable {
                let sources: [StreamSource]?
            }
            let data: MatchData?
        }
        
        struct StreamSource: Codable {
            let streamUrl: String?
            let embedUrl: String?
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let result = try JSONDecoder().decode(DetailResponse.self, from: data)
            if let sources = result.data?.sources, let first = sources.first {
                return first.streamUrl ?? first.embedUrl
            }
        } catch {
            print("Error fetching details: \(error)")
        }
        return nil
    }
}
