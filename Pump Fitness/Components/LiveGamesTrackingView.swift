import SwiftUI

struct LiveGamesTrackingView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("trackedLeagueIds") private var trackedLeagueIdsRaw: String = "4387,4328" // Default NBA, EPL
    @StateObject private var service = LiveSportsService.shared
    @State private var showEditor = false
    @Binding var selectedDate: Date
    // Removed @State private var isLoading = false
    @State private var selectedGame: SportsDBEvent?
    
    private var themeAccent: Color? {
        themeManager.selectedTheme == .multiColour ? nil : themeManager.selectedTheme.accent(for: colorScheme)
    }
    
    var trackedIds: [String] {
        trackedLeagueIdsRaw.split(separator: ",").map(String.init)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Match Tracking")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }

                Spacer()

                Button {
                    showEditor = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .font(.callout)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassEffect(in: .rect(cornerRadius: 18.0))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 48)
            .padding(.horizontal, 18)
            
            // Content
            ScrollView {
                VStack(spacing: 24) {
                    if trackedIds.isEmpty {
                        ContentUnavailableView(
                            "No Leagues Followed",
                            systemImage: "trophy",
                            description: Text("Tap Manage to search and follow leagues like NBA, Premier League, etc.")
                        )
                        .padding(.top, 40)
                    } else if service.isFetching {
                        VStack(spacing: 12) {
                            PulsingDotsIndicator(accentColor: themeAccent)
                            
                            if let fetching = service.currentlyFetchingLeague {
                                Text("Fetching \(fetching)...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                    } else if service.leagueEvents.isEmpty {
                        ContentUnavailableView(
                            "No Games Found",
                            systemImage: "calendar.badge.exclamationmark",
                            description: Text("No events found for your followed leagues.")
                        )
                        .padding(.top, 40)
                    } else {
                        ForEach(service.leagueEvents) { group in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(group.leagueName)
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 18)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(group.events) { event in
                                            SportsGameCard(event: event, accent: themeAccent, showDate: group.type != .standard || !Calendar.current.isDateInToday(selectedDate))
                                                .onTapGesture {
                                                    selectedGame = event
                                                }
                                        }
                                    }
                                    .padding(.horizontal, 18)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .glassEffect(in: .rect(cornerRadius: 16.0))
                .padding(.vertical, 20)
                .padding(.horizontal, 18)
            }
        }
        .task(id: trackedLeagueIdsRaw + selectedDate.description) {
            await loadData()
        }
        .sheet(isPresented: $showEditor) {
            LiveGamesEditorSheet {
                showEditor = false
            }
        }
        .sheet(item: $selectedGame) { game in
            NavigationStack {
                GameDetailSheet(event: game, accent: themeAccent)
            }
            .presentationDetents([.fraction(0.7), .fraction(1.0)])
        }
    }
    
    func loadData() async {
        // isLoading = true  <-- Removed, driven by service.isFetching
        await service.fetchSchedule(for: selectedDate, trackedLeagueIds: trackedIds)
        // isLoading = false <-- Removed
    }
}

// MARK: - Components

struct SportsGameCard: View {
    let event: SportsDBEvent
    let accent: Color?
    var showDate: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status Tag
            HStack {
                if let status = event.strStatus, status == "Match Finished" {
                     Text("FINAL")
                        .font(.SystemBold(10))
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        if showDate, let date = event.eventDate {
                            let userDateStr = formatDate(date)
                            if let gameDateLocal = event.dateEvent, formatDateShort(date) != gameDateLocal {
                                let gDateFormatted = formatDateShortOrdinal(gameDateLocal)
                                Text("\(userDateStr) (\(gDateFormatted) local)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(userDateStr)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        // Time Display: User Local (Game Local)
                        if let date = event.eventDate {
                             let userTime = formatTime(date)
                             if let gameTimeLocal = event.strTimeLocal, let gameDateLocal = event.dateEvent {
                                // Extract hour/minute from gameTimeLocal (likely HH:mm:ss)
                                let gameTimeTrimmed = String(gameTimeLocal.prefix(5))
                                
                                // Local date check
                                let userDateStr = formatDateShort(date)
                                
                                // Only show brackets if time OR date is different
                                if userTime != gameTimeTrimmed || userDateStr != gameDateLocal {
                                    if userDateStr != gameDateLocal {
                                        Text("\(userTime) (\(gameTimeTrimmed) local)")
                                            .font(.SystemBold(10))
                                            .foregroundStyle(accent ?? .blue)
                                    } else {
                                        Text("\(userTime) (\(gameTimeTrimmed) local)")
                                            .font(.SystemBold(10))
                                            .foregroundStyle(accent ?? .blue)
                                    }
                                } else {
                                    Text(userTime)
                                        .font(.SystemBold(10))
                                        .foregroundStyle(accent ?? .blue)
                                }
                             } else {
                                Text(userTime)
                                    .font(.SystemBold(10))
                                    .foregroundStyle(accent ?? .blue)
                             }
                        } else if let time = event.strTime {
                            // Fallback if date parsing failed but time string exists
                            Text(String(time.prefix(5)))
                                .font(.SystemBold(10))
                                .foregroundStyle(accent ?? .blue)
                        }
                    }
                }
                
                Spacer()
                
                // Show score if available
                if let home = event.intHomeScore, let away = event.intAwayScore {
                     Text("\(home) - \(away)")
                        .font(.SystemBold(12))
                }
            }
            .padding(.bottom, 2)

            // Teams
            VStack(alignment: .leading, spacing: 10) {
                if let home = event.strHomeTeam, !home.isEmpty, home != "Home" {
                    HStack {
                        Circle().fill(Color.gray.opacity(0.2)).frame(width: 24, height: 24)
                            .overlay(Text(String(home.prefix(1))).font(.caption))
                        
                        Text(home)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                    }
                }
                
                if let away = event.strAwayTeam, !away.isEmpty, away != "Away" {
                    HStack {
                        Circle().fill(Color.gray.opacity(0.2)).frame(width: 24, height: 24)
                            .overlay(Text(String(away.prefix(1))).font(.caption))
                        
                        Text(away)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 160)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        
        if Calendar.current.isDateInToday(date) {
            return "TODAY"
        } else if Calendar.current.isDateInTomorrow(date) {
            return "TOMORROW"
        } else {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "MMM d"
            return outputFormatter.string(from: date).uppercased()
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func formatDateShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func formatDateShortAPI(_ dateStr: String) -> String {
        // API dateEvent is already yyyy-MM-dd
        return dateStr
    }

    private func formatDateShortOrdinal(_ dateStr: String) -> String {
        guard let date = parseAPIDate(dateStr) else { return "" }
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        
        let suffix: String
        switch day {
        case 1, 21, 31: suffix = "st"
        case 2, 22: suffix = "nd"
        case 3, 23: suffix = "rd"
        default: suffix = "th"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return "\(day)\(suffix) \(formatter.string(from: date))"
    }

    private func parseAPIDate(_ dateStr: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateStr)
    }
}

struct GameDetailSheet: View {
    let event: SportsDBEvent
    let accent: Color?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header Image
                if let thumb = event.strThumb ?? event.strPoster, let url = URL(string: thumb) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 200)
                                .clipped()
                                .overlay(Color.black.opacity(0.4))
                        default:
                            LinearGradient(colors: [(accent ?? .blue).opacity(0.3), (accent ?? .blue).opacity(0.1)], startPoint: .top, endPoint: .bottom)
                                .frame(height: 140)
                        }
                    }
                } else {
                    LinearGradient(colors: [(accent ?? .blue).opacity(0.3), (accent ?? .blue).opacity(0.1)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 100)
                }
                
                VStack(spacing: 24) {
                    // League & Round
                    VStack(spacing: 4) {
                        Text(event.strLeague ?? "Match Details")
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        
                        if let round = event.strRound, let season = event.strSeason {
                            Text("Round \(round) • \(season)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 20)
                    
                    if let home = event.strHomeTeam {
                        if !home.isEmpty, home != "Home" {
                            // Scoreboard
                            HStack(alignment: .center, spacing: 10) {
                                // Home
                                VStack(spacing: 8) {
                                    TeamLogo(name: home, accent: accent)
                                    Text(home)
                                        .font(.headline)
                                        .multilineTextAlignment(.center)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity)
                                
                                // Score
                                VStack(spacing: 4) {
                                    if let homeScore = event.intHomeScore, let awayScore = event.intAwayScore {
                                        Text("\(homeScore) : \(awayScore)")
                                            .font(.system(size: 36, weight: .bold, design: .rounded))
                                    } else {
                                        Text("VS")
                                            .font(.system(size: 24, weight: .bold, design: .rounded))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(width: 100) 
                                
                                // Away
                                if let away = event.strAwayTeam {
                                    VStack(spacing: 8) {
                                        TeamLogo(name: away, accent: .red)
                                        Text(away)
                                            .font(.headline)
                                            .multilineTextAlignment(.center)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .frame(maxWidth: .infinity)
                                } else {
                                    Spacer().frame(maxWidth: .infinity)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    Divider()
                    
                    // Game Info Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                        if let date = event.eventDate {
                            let userDate = formatDateWithSuffix(date)
                            if let gameDateStr = event.dateEvent, let gameDate = parseAPIDate(gameDateStr) {
                                let gDateFormatted = formatDateWithSuffix(gameDate)
                                if userDate != gDateFormatted {
                                    HStack(spacing: 10) {
                                        Image(systemName: "calendar")
                                            .font(.body)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 20)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Date")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text(userDate)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            Text("\(gDateFormatted) (local)")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                } else {
                                    InfoItem(icon: "calendar", title: "Date", value: userDate)
                                }
                            } else {
                                InfoItem(icon: "calendar", title: "Date", value: userDate)
                            }
                        }
                        
                        if let date = event.eventDate {
                            let userTime = formatTime24(date)
                            if let gameTimeLocal = event.strTimeLocal {
                                let gameTimeTrimmed = String(gameTimeLocal.prefix(5))
                                if userTime != gameTimeTrimmed {
                                    HStack(spacing: 10) {
                                        Image(systemName: "clock")
                                            .font(.body)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 20)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Time")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text(userTime)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            Text("\(gameTimeTrimmed) (local)")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                } else {
                                    InfoItem(icon: "clock", title: "Time", value: userTime)
                                }
                            } else {
                                InfoItem(icon: "clock", title: "Time", value: userTime)
                            }
                        }
                        
                        if let venue = event.strVenue, !venue.trimmingCharacters(in: .whitespaces).isEmpty {
                            InfoItem(icon: "mappin.and.ellipse", title: "Venue", value: venue)
                        }
                        
                        let location = formatLocation(city: event.strCity, country: event.strCountry)
                        if !location.isEmpty {
                            InfoItem(icon: "map", title: "Location", value: location)
                        }
                        
                        if let spec = event.intSpectators, !spec.isEmpty {
                             InfoItem(icon: "person.2", title: "Attendance", value: spec)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Goal Details
                    let hGoalText = event.strHomeGoalDetails ?? ""
                    let aGoalText = event.strAwayGoalDetails ?? ""
                    if !hGoalText.trimmingCharacters(in: .whitespaces).isEmpty || !aGoalText.trimmingCharacters(in: .whitespaces).isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Goal Summary")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            HStack(alignment: .top, spacing: 0) {
                                // Home Goals
                                VStack(alignment: .leading, spacing: 4) {
                                    if !hGoalText.trimmingCharacters(in: .whitespaces).isEmpty {
                                        ForEach(hGoalText.split(separator: ";").map(String.init), id: \.self) { goal in
                                            Text("⚽️ \(goal)")
                                                .font(.callout)
                                                .foregroundStyle(.secondary)
                                        }
                                    } else {
                                        Text("-").font(.caption).foregroundStyle(.tertiary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Divider()
                                
                                // Away Goals
                                VStack(alignment: .trailing, spacing: 4) {
                                    if !aGoalText.trimmingCharacters(in: .whitespaces).isEmpty {
                                        ForEach(aGoalText.split(separator: ";").map(String.init), id: \.self) { goal in
                                            Text("\(goal) ⚽️")
                                                .font(.callout)
                                                .foregroundStyle(.secondary)
                                        }
                                    } else {
                                        Text("-").font(.caption).foregroundStyle(.tertiary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .padding()
                            .background(Color.secondary.opacity(0.05))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }

                    // Card Details (Yellow/Red)
                    let hYellow = event.strHomeYellowCards ?? ""
                    let hRed = event.strHomeRedCards ?? ""
                    let aYellow = event.strAwayYellowCards ?? ""
                    let aRed = event.strAwayRedCards ?? ""
                    
                    if !hYellow.trimmingCharacters(in: .whitespaces).isEmpty || !hRed.trimmingCharacters(in: .whitespaces).isEmpty || 
                       !aYellow.trimmingCharacters(in: .whitespaces).isEmpty || !aRed.trimmingCharacters(in: .whitespaces).isEmpty {
                         VStack(alignment: .leading, spacing: 12) {
                            Text("Discipline")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            HStack(alignment: .top, spacing: 0) {
                                // Home Cards
                                VStack(alignment: .leading, spacing: 4) {
                                    CardList(yellow: hYellow, red: hRed)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Divider()
                                
                                // Away Cards
                                VStack(alignment: .trailing, spacing: 4) {
                                    CardList(yellow: aYellow, red: aRed)
                                }
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .padding()
                            .background(Color.secondary.opacity(0.05))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.bottom, 20)
            }
        }
        .background(Color(UIColor.systemBackground))
        .ignoresSafeArea(edges: .top)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
    
    private func formatTime24(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func formatDateWithSuffix(_ date: Date?) -> String {
        guard let date = date else { return "-" }
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        
        let suffix: String
        switch day {
        case 1, 21, 31: suffix = "st"
        case 2, 22: suffix = "nd"
        case 3, 23: suffix = "rd"
        default: suffix = "th"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM, yyyy"
        return "\(day)\(suffix) \(formatter.string(from: date))"
    }
    
    private func formatLocation(city: String?, country: String?) -> String {
        let cityPart = city?.trimmingCharacters(in: .init(charactersIn: ", ")) ?? ""
        let countryPart = country?.trimmingCharacters(in: .init(charactersIn: ", ")) ?? ""
        
        if !cityPart.isEmpty && !countryPart.isEmpty {
            return "\(cityPart), \(countryPart)"
        }
        return !cityPart.isEmpty ? cityPart : countryPart
    }

    private func parseAPIDate(_ dateStr: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateStr)
    }
}

struct TeamLogo: View {
    let name: String?
    let accent: Color?
    
    var body: some View {
        Circle()
            .fill((accent ?? .blue).opacity(0.1))
            .frame(width: 64, height: 64)
            .overlay(
                Text(String(name?.prefix(1) ?? ""))
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(accent ?? .primary)
            )
    }
}

struct InfoItem: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CardList: View {
    let yellow: String?
    let red: String?
    
    var body: some View {
        if let y = yellow, !y.isEmpty {
           ForEach(y.split(separator: ";").map(String.init), id: \.self) { card in
               Text("🟨 \(card)").font(.caption).foregroundStyle(.secondary)
           }
        }
        if let r = red, !r.isEmpty {
           ForEach(r.split(separator: ";").map(String.init), id: \.self) { card in
               Text("🟥 \(card)").font(.caption).foregroundStyle(.secondary)
           }
        }
    }
}

struct PulsingDotsIndicator: View {
    let accentColor: Color?
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { idx in
                Circle()
                    .fill((accentColor ?? .primary).opacity(0.9))
                    .frame(width: 8, height: 8)
                    .scaleEffect(isAnimating ? 1.0 : 0.4)
                    .opacity(isAnimating ? 1.0 : 0.35)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(idx) * 0.12),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

extension Font {
    static func SystemBold(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold)
    }
}
