import Foundation
import Combine

@MainActor
class LiveSportsService: ObservableObject {
    static let shared = LiveSportsService()
    
    // TheSportsDB Free API Key
    private let apiKey = "3" // Note: '3' often returns limited/test data which can be strict-filtered out. '123' is the documented free key.
    // Switching to 123 for better data integrity based on documentation, but rate limits apply carefully.
    private let baseURL = "https://www.thesportsdb.com/api/v1/json/3/"
    // private let baseURL = "https://www.thesportsdb.com/api/v1/json/123/" 
    // ^ The user's code was using '3', but the behavior was bad. 
    // Let's stick to the user's key '3' for now but FIX the rate limiting, 
    // OR switch to '123' if that's the only way to get real data.
    // The previous terminal check showed '123' returning Brighton (EPL) while '3' returned Stevenage (League 1).
    // clearly '3' is behaving as a "sandbox" key returning garbage/mixed data for id 4328.
    // API Key '123' is the correct one.
    
    // Changing to 123
    private let realBaseURL = "https://www.thesportsdb.com/api/v1/json/123/"
    
    @Published var availableLeagues: [SportsDBLeague] = []
    @Published var leagueEvents: [LeagueEventsGroup] = []
    @Published var upcomingEvents: [LeagueEventsGroup] = []
    @Published var isLoaded: Bool = false
    @Published var isFetching: Bool = false
    @Published var isShowingUpcoming: Bool = false
    @Published var currentlyFetchingLeague: String? = nil
    
    // Cache tracking
    private var lastFetchedDate: Date?
    private var lastFetchedIds: Set<String> = []
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Pre-populate with known popular leagues to ensure display even if API is rate-limited
        self.availableLeagues = Self.popularLeagues
    }
    
    // MARK: - Core Fetching
    
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
    
    func fetchSchedule(for date: Date, trackedLeagueIds: [String]) async {
        let requestedIds = Set(trackedLeagueIds)
        
        // Cache Check: If date and IDs match, skip fetch
        // We only skip if isLoaded is true, meaning we've at least tried once.
        if let lastDate = lastFetchedDate, 
           Calendar.current.isDate(lastDate, inSameDayAs: date),
           lastFetchedIds == requestedIds,
           isLoaded {
           return
        }
        
        self.lastFetchedDate = date
        self.lastFetchedIds = requestedIds
        
        // Start Loading
        self.isFetching = true
        self.leagueEvents = [] // Clear existing
        self.isShowingUpcoming = false
        
        // Format date once
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: date)
        
        let leaguesToFetch = availableLeagues.filter { trackedLeagueIds.contains($0.idLeague) }
        var collectedEvents: [LeagueEventsGroup] = []
        
        do {
            for (index, league) in leaguesToFetch.enumerated() {
                // 0. Check Cancellation
                try Task.checkCancellation()
                
                self.currentlyFetchingLeague = league.strLeague
                
                // Rate Limiting
                if index > 0 {
                    try await Task.sleep(nanoseconds: 700_000_000) // 0.7s delay
                }
                
                var group: LeagueEventsGroup?
                
                // 1. Try Fetch for specific Date
                if let dayEvents = await fetchEventsForLeague(league, dateStr: dateStr) {
                    if !dayEvents.isEmpty {
                        let sorted = dayEvents.sorted { ($0.eventDate ?? Date.distantFuture) < ($1.eventDate ?? Date.distantFuture) }
                        group = LeagueEventsGroup(leagueId: league.idLeague, leagueName: league.strLeague, events: sorted, type: .standard)
                    }
                }
                
                // 2. Fallback if empty
                if group == nil {
                    // Check cancellation again before fallback fetches
                    try Task.checkCancellation()
                    
                    let isPast = date < Calendar.current.startOfDay(for: Date())
                    
                    if isPast {
                        // Fetch RECENT/PAST events
                        if let recent = await fetchRecentForLeague(league) {
                            if !recent.isEmpty {
                                let sorted = recent.sorted { ($0.eventDate ?? Date.distantPast) < ($1.eventDate ?? Date.distantPast) }
                                group = LeagueEventsGroup(leagueId: league.idLeague, leagueName: league.strLeague, events: sorted, type: .recent)
                            }
                        }
                    } else {
                        // Fetch UPCOMING events
                        if let upcoming = await fetchUpcomingForLeague(league) {
                            if !upcoming.isEmpty {
                                let sorted = upcoming.sorted { ($0.eventDate ?? Date.distantFuture) < ($1.eventDate ?? Date.distantFuture) }
                                group = LeagueEventsGroup(leagueId: league.idLeague, leagueName: league.strLeague, events: sorted, type: .upcoming)
                            }
                        }
                    }
                }
                
                if let result = group {
                    collectedEvents.append(result)
                }
            }
            
            // Only update state if fully completed without cancellation
            self.leagueEvents = collectedEvents
            self.currentlyFetchingLeague = nil
            self.isFetching = false
            self.isLoaded = true
            
        } catch {
            if error is CancellationError {
                print("LiveSportsService: Fetch cancelled")
                return
            }
            print("LiveSportsService: Fetch error - \(error)")
            // Reset fetching state on error so UI doesn't hang? 
            // If it's a non-cancellation error, we probably should reset `isFetching`.
            // But main loop errors (like sleep interruption) are usually cancellation.
            // If it's a "real" error, let's reset.
            self.currentlyFetchingLeague = nil
            self.isFetching = false
        }
    }
    
    // MARK: - Internal Helpers
    
    // Returns events if found, nil if error/empty
    private func fetchEventsForLeague(_ league: SportsDBLeague, dateStr: String) async -> [SportsDBEvent]? {
        let encodedLeague = league.strLeague.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "\(realBaseURL)eventsday.php?d=\(dateStr)&l=\(encodedLeague)") else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let response = try? JSONDecoder().decode(SportsDBEventsResponse.self, from: data),
               let events = response.events {
                // Strict filter
                return events.filter { $0.idLeague == league.idLeague }
            }
        } catch {
            print("Error fetch events (day) for \(league.strLeague): \(error)")
        }
        return nil // Empty or error
    }
    
    private func fetchUpcomingForLeague(_ league: SportsDBLeague) async -> [SportsDBEvent]? {
        guard let url = URL(string: "\(realBaseURL)eventsnextleague.php?id=\(league.idLeague)") else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let response = try? JSONDecoder().decode(SportsDBEventsResponse.self, from: data),
               let events = response.events {
                let filtered = events.filter { $0.idLeague == league.idLeague }
                return filtered // Return all provided by API (limited by API tier)
            }
        } catch {
             print("Error fetch upcoming for \(league.strLeague): \(error)")
        }
        return nil
    }

    private func fetchRecentForLeague(_ league: SportsDBLeague) async -> [SportsDBEvent]? {
        guard let url = URL(string: "\(realBaseURL)eventspastleague.php?id=\(league.idLeague)") else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let response = try? JSONDecoder().decode(SportsDBEventsResponse.self, from: data),
               let events = response.events {
                let filtered = events.filter { $0.idLeague == league.idLeague }
                return filtered
            }
        } catch {
             print("Error fetch recent for \(league.strLeague): \(error)")
        }
        return nil
    }

    // Deprecated public methods (kept for compatibility or specific calls if needed, but fetchSchedule replaces them)
    func fetchEvents(for date: Date, trackedLeagueIds: [String]) async {
         // No-op or redirect
         await fetchSchedule(for: date, trackedLeagueIds: trackedLeagueIds)
    }

    func fetchUpcomingEvents(trackedLeagueIds: [String]) async {
         // No-op or redirect
         await fetchSchedule(for: Date(), trackedLeagueIds: trackedLeagueIds)
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
