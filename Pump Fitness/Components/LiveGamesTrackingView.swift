import SwiftUI

struct LiveGamesTrackingView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("trackedLeagueIds") private var trackedLeagueIdsRaw: String = "4387,4328" // Default NBA, EPL
    @StateObject private var service = LiveSportsService.shared
    @State private var showEditor = false
    @Binding var selectedDate: Date
    @State private var isLoading = false
    @State private var selectedGame: SportsDBEvent?
    
    private var themeAccent: Color? {
        themeManager.selectedTheme == .multiColour ? nil : themeManager.selectedTheme.accent(for: colorScheme)
    }
    
    var trackedIds: [String] {
        trackedLeagueIdsRaw.split(separator: ",").map(String.init)
    }
    
    private var isVisible: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: selectedDate)
        return target >= today
    }

    var body: some View {
        if isVisible {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text(Calendar.current.isDateInToday(selectedDate) ? "Upcoming Games" : "Sports Schedule")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

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
                        } else if isLoading {
                            ProgressView()
                                .padding(.top, 50)
                        } else if (Calendar.current.isDateInToday(selectedDate) ? service.upcomingEvents : service.leagueEvents).isEmpty {
                            ContentUnavailableView(
                                "No Games Scheduled",
                                systemImage: "calendar.badge.exclamationmark",
                                description: Text(Calendar.current.isDateInToday(selectedDate) ? "No events found for your followed leagues today." : "No events found for your followed leagues on this day.")
                            )
                            .padding(.top, 40)
                        } else {
                            ForEach(Calendar.current.isDateInToday(selectedDate) ? service.upcomingEvents : service.leagueEvents) { group in
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(group.leagueName)
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 18)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(group.events) { event in
                                                SportsGameCard(event: event, accent: themeAccent, showDate: Calendar.current.isDateInToday(selectedDate))
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
                    .padding(.bottom, 20)
                }
            }
            .task {
                // Only trigger load if it's a different date OR if not yet initialized today
                if !Calendar.current.isDateInToday(selectedDate) {
                    await loadData()
                } else if !service.isLoaded {
                    await loadData()
                }
            }
            .onChange(of: trackedLeagueIdsRaw) {
                Task { await loadData() }
            }
            .onChange(of: selectedDate) {
                Task { 
                    if !Calendar.current.isDateInToday(selectedDate) || !service.isLoaded {
                        await loadData() 
                    }
                }
            }
            .sheet(isPresented: $showEditor) {
                LiveGamesEditorSheet {
                    showEditor = false
                }
            }
            .sheet(item: $selectedGame) { game in
                GameDetailSheet(event: game, accent: themeAccent)
                    .presentationDetents([.fraction(0.4), .medium])
            }
        }
    }
    
    func loadData() async {
        isLoading = true
        if Calendar.current.isDateInToday(selectedDate) {
            await service.fetchUpcomingEvents(trackedLeagueIds: trackedIds)
        } else {
            await service.fetchEvents(for: selectedDate, trackedLeagueIds: trackedIds)
        }
        isLoading = false
    }
}

// MARK: - Components

struct SportsGameCard: View {
    let event: SportsDBEvent
    let accent: Color?
    var showDate: Bool = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Status Tag
            HStack {
                if let status = event.strStatus, status == "Match Finished" {
                     Text("FINAL")
                        .font(.SystemBold(10))
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        if showDate, let date = event.dateEvent {
                            Text(formatDate(date))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        
                        if let time = event.strTime {
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
                HStack {
                    // Badge would go here if fetched separately, for now just text or generic icon
                    Circle().fill(Color.gray.opacity(0.2)).frame(width: 24, height: 24)
                        .overlay(Text(String(event.strHomeTeam?.prefix(1) ?? "")).font(.caption))
                    
                    Text(event.strHomeTeam ?? "Home")
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                }
                
                HStack {
                    Circle().fill(Color.gray.opacity(0.2)).frame(width: 24, height: 24)
                        .overlay(Text(String(event.strAwayTeam?.prefix(1) ?? "")).font(.caption))
                    
                    Text(event.strAwayTeam ?? "Away")
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
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
    
    private func formatDate(_ dateStr: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        
        guard let date = inputFormatter.date(from: dateStr) else { return dateStr }
        
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
}

struct GameDetailSheet: View {
    let event: SportsDBEvent
    let accent: Color?
    
    var body: some View {
        VStack(spacing: 20) {
            Text(event.strLeague ?? "Match Details")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.top, 20)
            
            HStack(alignment: .center, spacing: 30) {
                // Home
                VStack {
                    Circle().fill((accent ?? .blue).opacity(0.1)).frame(width: 60, height: 60)
                        .overlay(Text(String(event.strHomeTeam?.prefix(1) ?? "")).font(.title2))
                    Text(event.strHomeTeam ?? "")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                
                VStack {
                    if let home = event.intHomeScore, let away = event.intAwayScore {
                        Text("\(home) : \(away)")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .monospacedDigit()
                    } else {
                        Text("VS")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(event.strStatus ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                
                // Away
                VStack {
                    Circle().fill((accent ?? .red).opacity(0.1)).frame(width: 60, height: 60)
                        .overlay(Text(String(event.strAwayTeam?.prefix(1) ?? "")).font(.title2))
                    Text(event.strAwayTeam ?? "")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
            
            if let date = event.dateEvent {
                HStack {
                    Image(systemName: "calendar")
                    Text(date)
                    if let time = event.strTime {
                        Text("•")
                        Text(String(time.prefix(5)))
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .background(Color(UIColor.systemBackground))
    }
}

extension Font {
    static func SystemBold(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold)
    }
}
