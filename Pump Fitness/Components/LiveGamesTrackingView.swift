import SwiftUI

struct LiveGamesTrackingView: View {
    @AppStorage("trackedLiveSports") private var trackedSportsRaw: String = "basketball,football"
    @StateObject private var service = LiveSportsService.shared
    @State private var showEditor = false
    
    var trackedSports: [String] {
        trackedSportsRaw.split(separator: ",").map(String.init)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Live Games Tracking")
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
            .padding(.horizontal, 18)
            .padding(.top, 10)
            
            if trackedSports.isEmpty {
                Text("No games tracked. Tap Edit to add sports.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
            } else {
                VStack(spacing: 24) {
                    ForEach(trackedSports, id: \.self) { sportId in
                        LiveSportSection(sportId: sportId)
                    }
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            LiveGamesEditorSheet {
                showEditor = false
            }
        }
    }
}

struct LiveSportSection: View {
    let sportId: String
    @ObservedObject var service = LiveSportsService.shared
    @State var isExpanded = true
    
    var games: [LeagueGroup] {
        service.matches[sportId] ?? []
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack {
                    Text(service.availableSports.first(where: { $0.id == sportId })?.name ?? sportId.capitalized)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 18)
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                if games.isEmpty {
                    Text("No live or upcoming games found.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 4)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(games) { group in
                                ForEach(group.matches) { match in
                                    GameCard(match: match)
                                }
                            }
                        }
                        .padding(.horizontal, 18)
                    }
                }
            }
        }
        .task {
            if service.availableSports.isEmpty {
                 await service.fetchSports()
            }
            await service.fetchMatches(for: sportId)
        }
    }
}

struct GameCard: View {
    let match: LiveMatch
    @State private var streamURL: URL?
    @State private var showSafari = false
    @State private var isLoadingStream = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 10) {
            // ... (rest of the card content)
            // Header: League & Status
            HStack {
                Text(match.status == "inprogress" ? "LIVE" : (match.status == "finished" ? "ENDED" : "UPCOMING"))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(match.status == "inprogress" ? .red : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(match.status == "inprogress" ? Color.red.opacity(0.15) : Color.secondary.opacity(0.15))
                    )
                
                Spacer()
                
                if let scoreDisplay = match.score?.display {
                     Text(scoreDisplay)
                        .font(.system(size: 12, weight: .bold))
                        .monospacedDigit()
                }
            }
            
            // Teams
            HStack(alignment: .center, spacing: 8) {
                // Home
                VStack(spacing: 4) {
                   AsyncImage(url: URL(string: match.teams.home.badge ?? "")) { img in
                       img.resizable().scaledToFit()
                   } placeholder: {
                       Circle().fill(Color.secondary.opacity(0.2))
                   }
                   .frame(width: 36, height: 36)
                   
                    Text(match.teams.home.code ?? String(match.teams.home.name.prefix(3)).uppercased())
                       .font(.system(size: 11, weight: .bold))
                       .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                
                Text(match.startTime.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                
                // Away
                 VStack(spacing: 4) {
                   AsyncImage(url: URL(string: match.teams.away.badge ?? "")) { img in
                       img.resizable().scaledToFit()
                   } placeholder: {
                       Circle().fill(Color.secondary.opacity(0.2))
                   }
                   .frame(width: 36, height: 36)
                   
                     Text(match.teams.away.code ?? String(match.teams.away.name.prefix(3)).uppercased())
                       .font(.system(size: 11, weight: .bold))
                       .lineLimit(1)
                }
                 .frame(maxWidth: .infinity)
            }
            
            // Watch Button
            // if match.status == "inprogress" {
            //     Button {
            //         Task {
            //             isLoadingStream = true
            //             if let link = await LiveSportsService.shared.getStreamLink(matchId: match.id),
            //                let url = URL(string: link) {
            //                 streamURL = url
            //                 showSafari = true
            //             } else {
            //                 errorMessage = "Streaming link not found for this match yet."
            //                 showError = true
            //             }
            //             isLoadingStream = false
            //         }
            //     } label: {
            //         if isLoadingStream {
            //             ProgressView().controlSize(.mini)
            //         } else {
            //             Label("Watch Live", systemImage: "play.tv.fill")
            //                 .font(.system(size: 12, weight: .semibold))
            //         }
            //     }
            //     .buttonStyle(.borderedProminent)
            //     .controlSize(.small)
            //     .tint(.red)
            // }
        }
        .padding(12)
        .frame(width: 180)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .alert("No Stream", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showSafari) {
            if let url = streamURL {
                SafariView(url: url)
            }
        }
    }
}
