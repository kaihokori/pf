import SwiftUI

struct LiveGamesEditorSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("trackedLeagueIds") private var trackedLeagueIdsRaw: String = "4387,4328"
    @StateObject private var service = LiveSportsService.shared
    
    var onDismiss: () -> Void

    private var themeAccent: Color? {
        themeManager.selectedTheme == .multiColour ? nil : themeManager.selectedTheme.accent(for: colorScheme)
    }

    private var trackedIds: [String] {
        trackedLeagueIdsRaw.split(separator: ",").map(String.init)
    }
    
    private var displayedLeagues: [SportsDBLeague] {
        service.availableLeagues
    }
    
    // Grouping by Sport
    private var leaguesBySport: [String: [SportsDBLeague]] {
        Dictionary(grouping: displayedLeagues, by: { $0.strSport ?? "Other" })
    }
    
    // Sort sports alphabetically, but keep "Other" last if needed
    private var sortedSports: [String] {
        leaguesBySport.keys.sorted().filter { $0 != "Other" } + (leaguesBySport.keys.contains("Other") ? ["Other"] : [])
    }
    
    // Tracked league objects (resolved from IDs)
    private var trackedLeagues: [SportsDBLeague] {
        service.availableLeagues.filter { trackedIds.contains($0.idLeague) }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    
                    // MARK: - Tracked Section
                    if !trackedLeagues.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionTitle("Tracked Leagues")
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 4)
                            
                            VStack(spacing: 12) {
                                ForEach(trackedLeagues) { league in
                                    LeagueCard(league: league, isTracked: true, color: themeAccent ?? color(for: league.strSport)) {
                                        toggleLeague(league.idLeague)
                                    }
                                }
                            }
                        }
                    }
                    
                    // MARK: - Browse Section
                    VStack(alignment: .leading, spacing: 20) {
                        SectionTitle(trackedLeagues.isEmpty ? "All Leagues" : "Quick Add")
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 4)

                        // Browse by Sport
                        ForEach(sortedSports, id: \.self) { sport in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(sport)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 4)
                                    .textCase(.uppercase)
                                
                                VStack(spacing: 12) {
                                    ForEach(leaguesBySport[sport] ?? []) { league in
                                        // Show only untracked in Quick Add style
                                        if !trackedIds.contains(league.idLeague) {
                                            LeagueCard(league: league, isTracked: false, color: themeAccent ?? color(for: sport)) {
                                                toggleLeague(league.idLeague)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("Manage Leagues")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .task {
             if service.availableLeagues.count < 15 {
                await service.fetchAllLeagues()
            }
        }
    }
    
    private func toggleLeague(_ id: String) {
        var current = trackedIds
        if let idx = current.firstIndex(of: id) {
            current.remove(at: idx)
        } else {
            current.append(id)
        }
        trackedLeagueIdsRaw = current.joined(separator: ",")
    }
    
    private func color(for sport: String?) -> Color {
        switch sport?.lowercased() {
        case "soccer": return .green
        case "basketball": return .orange
        case "american football": return .brown
        case "baseball": return .red
        case "motorsport": return .purple
        case "fighting": return .red
        case "ice hockey": return .cyan
        case "golf": return .green
        case "tennis": return .yellow
        default: return .blue
        }
    }
    
    struct LeagueCard: View {
        let league: SportsDBLeague
        let isTracked: Bool
        let color: Color
        let onAction: () -> Void
        
        var iconName: String {
             switch league.strSport?.lowercased() {
                case "soccer": return "soccerball"
                case "basketball": return "basketball.fill"
                case "american football": return "football.fill"
                case "baseball": return "baseball.fill"
                case "tennis": return "tennis.racket"
                case "rugby": return "figure.rugby"
                case "motorsport": return "flag.checkered"
                case "fighting": return "figure.boxing"
                case "ice hockey": return "hockey.puck.fill"
                case "golf": return "figure.golf"
                default: return "trophy.fill"
            }
        }
        
        var body: some View {
            HStack(spacing: 14) {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: iconName)
                            .foregroundStyle(color)
                    )

                VStack(alignment: .leading) {
                    Text(league.strLeague)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    if let alt = league.strLeagueAlternate, !alt.isEmpty {
                        Text(alt)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else if let sport = league.strSport {
                         Text(sport)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button(action: onAction) {
                    if isTracked {
                        Image(systemName: "trash")
                            .font(.system(size: 18))
                            .foregroundStyle(.red)
                            .frame(width: 32, height: 32)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(color)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(18)
        }
    }
}
