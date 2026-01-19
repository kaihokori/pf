import Foundation
import Combine

@MainActor
class LiveSportsService: ObservableObject {
    static let shared = LiveSportsService()
    
    // TheSportsDB Free API Key
    private let apiKey = "3" 
    private let baseURL = "https://www.thesportsdb.com/api/v1/json/3/"
    
    @Published var availableLeagues: [SportsDBLeague] = []
    @Published var leagueEvents: [LeagueEventsGroup] = []
    @Published var upcomingEvents: [LeagueEventsGroup] = []
    @Published var isLoaded: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Pre-populate with known popular leagues to ensure display even if API is rate-limited
        self.availableLeagues = Self.popularLeagues
    }
    
    // MARK: - Core Fetching
    
    func loadInitialData(trackedLeagueIds: [String]) async {
        // Step 1: Ensure leagues are fetched if they aren't already (beyond popular defaults)
        if availableLeagues.count <= Self.popularLeagues.count {
            await fetchAllLeagues()
        }
        
        // Step 2: Fetch upcoming events for tracked leagues
        if !trackedLeagueIds.isEmpty {
            await fetchUpcomingEvents(trackedLeagueIds: trackedLeagueIds)
        }
        
        self.isLoaded = true
    }
    
    func fetchAllLeagues() async {
        guard let url = URL(string: "\(baseURL)all_leagues.php") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(SportsDBLeaguesResponse.self, from: data)
            if let leagues = response.leagues {
                // Merge with defaults, avoiding duplicates
                let existingIds = Set(self.availableLeagues.map { $0.idLeague })
                let newLeagues = leagues.filter { !existingIds.contains($0.idLeague) }
                self.availableLeagues.append(contentsOf: newLeagues)
                self.availableLeagues.sort { $0.strLeague < $1.strLeague }
            }
        } catch {
            print("Error fetching leagues: \(error)")
        }
    }
    
    // Fallback data for Free Tier limitations
    static let popularLeagues: [SportsDBLeague] = [
        // US Major
        SportsDBLeague(idLeague: "4387", strLeague: "NBA", strSport: "Basketball", strLeagueAlternate: "National Basketball Association"),
        SportsDBLeague(idLeague: "4391", strLeague: "NFL", strSport: "American Football", strLeagueAlternate: "National Football League"),
        SportsDBLeague(idLeague: "4424", strLeague: "MLB", strSport: "Baseball", strLeagueAlternate: "Major League Baseball"),
        SportsDBLeague(idLeague: "4380", strLeague: "NHL", strSport: "Ice Hockey", strLeagueAlternate: "National Hockey League"),
        SportsDBLeague(idLeague: "4346", strLeague: "MLS", strSport: "Soccer", strLeagueAlternate: "Major League Soccer"),
        SportsDBLeague(idLeague: "4442", strLeague: "WNBA", strSport: "Basketball", strLeagueAlternate: "Women's National Basketball Association"),
        SportsDBLeague(idLeague: "4408", strLeague: "NCAA Division 1", strSport: "American Football", strLeagueAlternate: "College Football"),
        
        // European Soccer - Top 5 + Popular
        SportsDBLeague(idLeague: "4328", strLeague: "English Premier League", strSport: "Soccer", strLeagueAlternate: "Premier League"),
        SportsDBLeague(idLeague: "4335", strLeague: "La Liga", strSport: "Soccer", strLeagueAlternate: "Primera Division"),
        SportsDBLeague(idLeague: "4331", strLeague: "Bundesliga", strSport: "Soccer", strLeagueAlternate: "German Bundesliga"),
        SportsDBLeague(idLeague: "4332", strLeague: "Serie A", strSport: "Soccer", strLeagueAlternate: "Serie A"),
        SportsDBLeague(idLeague: "4334", strLeague: "Ligue 1", strSport: "Soccer", strLeagueAlternate: "Ligue 1 Uber Eats"),
        SportsDBLeague(idLeague: "4344", strLeague: "Primeira Liga", strSport: "Soccer", strLeagueAlternate: "Portuguese Liga"),
        SportsDBLeague(idLeague: "4337", strLeague: "Eredivisie", strSport: "Soccer", strLeagueAlternate: "Dutch Eredivisie"),
        SportsDBLeague(idLeague: "4401", strLeague: "UEFA Champions League", strSport: "Soccer", strLeagueAlternate: "UCL"),
        SportsDBLeague(idLeague: "4426", strLeague: "UEFA Europa League", strSport: "Soccer", strLeagueAlternate: "UEL"),
        
        // South American Soccer
        SportsDBLeague(idLeague: "4351", strLeague: "Brasileirao", strSport: "Soccer", strLeagueAlternate: "Campeonato Brasileiro"),
        SportsDBLeague(idLeague: "4354", strLeague: "Primera Division Argentina", strSport: "Soccer", strLeagueAlternate: "Argentine Primera"),
        
        // Motorsport
        SportsDBLeague(idLeague: "4370", strLeague: "Formula 1", strSport: "Motorsport", strLeagueAlternate: "F1"),
        SportsDBLeague(idLeague: "4432", strLeague: "MotoGP", strSport: "Motorsport", strLeagueAlternate: "Grand Prix Motorcycle Racing"),
        SportsDBLeague(idLeague: "4372", strLeague: "NASCAR Cup Series", strSport: "Motorsport", strLeagueAlternate: "NASCAR"),
        
        // Fighting
        SportsDBLeague(idLeague: "4443", strLeague: "UFC", strSport: "Fighting", strLeagueAlternate: "Ultimate Fighting Championship"),
        SportsDBLeague(idLeague: "4444", strLeague: "WWE", strSport: "Fighting", strLeagueAlternate: "World Wrestling Entertainment"),
        SportsDBLeague(idLeague: "4516", strLeague: "AEW", strSport: "Fighting", strLeagueAlternate: "All Elite Wrestling"),
        SportsDBLeague(idLeague: "4457", strLeague: "Boxing", strSport: "Fighting", strLeagueAlternate: "Professional Boxing"),

        // Basketball - International
        SportsDBLeague(idLeague: "4446", strLeague: "EuroLeague", strSport: "Basketball", strLeagueAlternate: "Turkish Airlines EuroLeague"),
        SportsDBLeague(idLeague: "4409", strLeague: "NBL", strSport: "Basketball", strLeagueAlternate: "Australian National Basketball League"),
        
        // Cricket
        SportsDBLeague(idLeague: "4458", strLeague: "Indian Premier League", strSport: "Cricket", strLeagueAlternate: "IPL"),
        SportsDBLeague(idLeague: "4545", strLeague: "ICC World Cup", strSport: "Cricket", strLeagueAlternate: "Cricket World Cup"),
        
        // Rugby
        SportsDBLeague(idLeague: "4414", strLeague: "Super Rugby", strSport: "Rugby", strLeagueAlternate: "Super Rugby Pacific"),
        SportsDBLeague(idLeague: "4340", strLeague: "Gallagher Premiership", strSport: "Rugby", strLeagueAlternate: "Premiership Rugby"),
        SportsDBLeague(idLeague: "4347", strLeague: "Six Nations", strSport: "Rugby", strLeagueAlternate: "Guinness Six Nations"),
        
        // Tennis
        SportsDBLeague(idLeague: "4464", strLeague: "ATP World Tour", strSport: "Tennis", strLeagueAlternate: "Association of Tennis Professionals"),
        SportsDBLeague(idLeague: "4465", strLeague: "WTA Tour", strSport: "Tennis", strLeagueAlternate: "Women's Tennis Association"),
        
        // Golf
        SportsDBLeague(idLeague: "4425", strLeague: "PGA Tour", strSport: "Golf", strLeagueAlternate: "Professional Golfers Association"),
        SportsDBLeague(idLeague: "4848", strLeague: "LIV Golf", strSport: "Golf", strLeagueAlternate: "LIV Golf Invitational Series"),
        
        // Other Popular
        SportsDBLeague(idLeague: "4356", strLeague: "Australian Football League", strSport: "Australian Football", strLeagueAlternate: "AFL"),
    ]
    
    func fetchEvents(for date: Date, trackedLeagueIds: [String]) async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: date)
        
        var newGroups: [LeagueEventsGroup] = []
        
        let leaguesToFetch = availableLeagues.filter { trackedLeagueIds.contains($0.idLeague) }
        
        for league in leaguesToFetch {
            // URL encode league name
            let leagueName = league.strLeague.replacingOccurrences(of: " ", with: "_")
            guard let url = URL(string: "\(baseURL)eventsday.php?d=\(dateStr)&l=\(leagueName)") else { continue }
            
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                // Decode
                if let response = try? JSONDecoder().decode(SportsDBEventsResponse.self, from: data),
                   let events = response.events {
                    let group = LeagueEventsGroup(leagueId: league.idLeague, leagueName: league.strLeague, events: events)
                    newGroups.append(group)
                }
            } catch {
                print("Error fetch events for \(league.strLeague): \(error)")
            }
        }
        
        self.leagueEvents = newGroups
    }

    func fetchUpcomingEvents(trackedLeagueIds: [String]) async {
        var newGroups: [LeagueEventsGroup] = []
        let leaguesToFetch = availableLeagues.filter { trackedLeagueIds.contains($0.idLeague) }
        
        for league in leaguesToFetch {
            guard let url = URL(string: "\(baseURL)eventsnextleague.php?id=\(league.idLeague)") else { continue }
            
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let response = try? JSONDecoder().decode(SportsDBEventsResponse.self, from: data),
                   let events = response.events {
                     // Filter to strictly future if needed, or just take the "next 15" provided by the API.
                     // The user asked for "next 10", the API gives 15. We can slice.
                     let limitedEvents = Array(events.prefix(10))
                    let group = LeagueEventsGroup(leagueId: league.idLeague, leagueName: league.strLeague, events: limitedEvents)
                    newGroups.append(group)
                }
            } catch {
                print("Error fetch upcoming events for \(league.strLeague): \(error)")
            }
        }
        
        self.leagueEvents = newGroups
        self.upcomingEvents = newGroups
    }
    
    func searchLeagues(query: String) -> [SportsDBLeague] {
        if query.isEmpty { return [] }
        return availableLeagues.filter {
            $0.strLeague.localizedCaseInsensitiveContains(query) ||
            ($0.strLeagueAlternate?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }
    
    func getStreamLink(matchId: String) async -> String? {
        // Not supported on free tier of TheSportsDB usually, or requires specialized lookup
        return nil
    }
}
