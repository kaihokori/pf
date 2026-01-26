//
//  EntertainmentTrackingSection.swift
//  Pump Fitness
//
//  Created for Trackerio.
//

import SwiftUI
import MusicKit

// MARK: - Music Tracking Section

struct MusicTrackingSection: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var musicService = MusicService.shared
    @State private var isConnecting = false
    @State private var showHistorySheet = false
    @State private var isSongsExpanded = false

    var body: some View {
        if musicService.isAuthorized {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - Top Songs
                if !musicService.topSongs.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        MusicSectionHeader(title: "Top Songs", icon: "music.note.list")
                        
                        VStack(spacing: 12) {
                            // Top 3 always shown
                            ForEach(Array(musicService.topSongs.prefix(3).enumerated()), id: \.element.id) { index, song in
                                SongRowView(index: index, song: song) {
                                    openMusicSearch(term: "\(song.title) \(song.artist)")
                                }
                            }
                            
                            // Collapsible section for 4-10
                            if musicService.topSongs.count > 3 {
                                if isSongsExpanded {
                                    ForEach(Array(musicService.topSongs.dropFirst(3).prefix(7).enumerated()), id: \.element.id) { offset, song in
                                        SongRowView(index: offset + 3, song: song) {
                                            openMusicSearch(term: "\(song.title) \(song.artist)")
                                        }
                                    }
                                }
                                
                                Button {
                                    withAnimation {
                                        isSongsExpanded.toggle()
                                    }
                                } label: {
                                    HStack {
                                        Text(isSongsExpanded ? "Show Less" : "Show More")
                                        Image(systemName: isSongsExpanded ? "chevron.up" : "chevron.down")
                                    }
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(Color.accentColor)
                                    .padding(.top, 4)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // MARK: - Top Artists
                if !musicService.topArtists.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        MusicSectionHeader(title: "Top Artists", icon: "mic")
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 16) {
                                ForEach(musicService.topArtists.prefix(5)) { artist in
                                    VStack(alignment: .center, spacing: 8) {
                                        if let uiImage = artist.artworkUIImage {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 80, height: 80)
                                                .clipShape(Circle())
                                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                        } else {
                                            ZStack {
                                                Circle()
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [.purple.opacity(0.1), .blue.opacity(0.1)],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                    )
                                                    .frame(width: 80, height: 80)
                                                
                                                Image(systemName: "music.mic")
                                                    .font(.system(size: 30))
                                                    .foregroundStyle(
                                                        LinearGradient(
                                                            colors: [.purple, .blue],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                    )
                                            }
                                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                                        }
                                        
                                        VStack(spacing: 2) {
                                            Text(artist.name)
                                                .font(.system(size: 13, weight: .medium))
                                                .lineLimit(1)
                                                .foregroundStyle(.primary)
                                            
                                            Text("\(artist.playCount) plays")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        .frame(width: 90)
                                    }
                                    .onTapGesture {
                                        openMusicSearch(term: artist.name)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                // MARK: - Top Albums
                if !musicService.topAlbums.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        MusicSectionHeader(title: "Top Albums", icon: "square.stack")
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 16) {
                                ForEach(musicService.topAlbums.prefix(5)) { album in
                                    VStack(alignment: .leading, spacing: 8) {
                                        if let uiImage = album.artworkUIImage {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 120, height: 120)
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                                .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
                                        } else {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.secondary.opacity(0.1))
                                                .frame(width: 120, height: 120)
                                                .overlay(
                                                    Image(systemName: "opticaldisc")
                                                        .font(.largeTitle)
                                                        .foregroundStyle(.secondary)
                                                )
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(album.title)
                                                .font(.system(size: 13, weight: .semibold))
                                                .lineLimit(1)
                                                .foregroundStyle(.primary)
                                            
                                            Text(album.artist)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                            
                                            Text("\(album.playCount) plays")
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundStyle(Color.accentColor)
                                                .padding(.top, 2)
                                        }
                                        .frame(width: 120, alignment: .leading)
                                    }
                                    .onTapGesture {
                                        openMusicSearch(term: "\(album.title) \(album.artist)")
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                Divider()
                    .padding(.horizontal)
                    .opacity(0.5)

                // MARK: - Genre Breakdown
                VStack(alignment: .leading, spacing: 12) {
                    MusicSectionHeader(title: "Genre Breakdown", icon: "chart.pie.fill")
                    
                    if musicService.genreDistribution.isEmpty {
                        Text("Not enough data")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    } else {
                        GenrePieChart(items: musicService.genreDistribution)
                    }
                }
                .padding(.bottom, 8)

                // Footer
                HStack {
                    Image(systemName: "applelogo")
                        .font(.caption)
                    Text("Apple Music Library")
                        .font(.caption2)
                        .fontWeight(.medium)
                    
                    Spacer()
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 4)
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 8)
            .glassEffect(in: .rect(cornerRadius: 16.0))
            .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 5)
            .task {
                await musicService.fetchData()
            }
            .sheet(isPresented: $showHistorySheet) {
                MusicHistorySheet(songs: musicService.topSongs)
            }
        } else if musicService.isDenied {
            VStack(spacing: 12) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(themeManager.selectedTheme == .multiColour ? Color.orange : themeManager.selectedTheme.accent(for: colorScheme))
                    .padding(.bottom, 4)
                
                Text("Access Denied")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text("To view your music stats, please enable Media & Apple Music access in your iPhone Settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("Open Settings", systemImage: "1.circle.fill")
                    Label("Tap Trackerio", systemImage: "2.circle.fill")
                    Label("Enable Media & Apple Music", systemImage: "3.circle.fill")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Open Settings")
                        .fontWeight(.medium)
                        .frame(minWidth: 140)
                }
                .buttonStyle(.bordered)
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .glassEffect(in: .rect(cornerRadius: 16))
            .transition(.opacity)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "music.note.house.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
                
                Text("Connect Music Services")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text("Connect to Apple Music to view summary information about your listening habits.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                if isConnecting {
                    ProgressView()
                        .padding(.top, 8)
                } else {
                    Button {
                        connect()
                    } label: {
                        Text("Connect Apple Music")
                            .fontWeight(.medium)
                            .frame(minWidth: 140)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .glassEffect(in: .rect(cornerRadius: 16))
            .transition(.opacity)
        }
    }
    
    private func connect() {
        withAnimation {
            isConnecting = true
        }
        
        Task {
            await musicService.requestAuthorization()
            withAnimation {
                isConnecting = false
            }
        }
    }
    
    private func openMusicSearch(term: String) {
        let cleaned = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        // Use music:// scheme to open the Music app directly
        if let url = URL(string: "music://music.apple.com/us/search?term=\(cleaned)") {
             openURL(url)
        } else if let webUrl = URL(string: "https://music.apple.com/us/search?term=\(cleaned)") {
             openURL(webUrl)
        }
    }
}

// MARK: - Music Subcomponents

private struct MusicSectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .font(.subheadline)
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.horizontal)
    }
}

struct MusicHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    let songs: [SongModel]
    
    var body: some View {
        NavigationStack {
            List {
                if songs.isEmpty {
                    Text("No history available")
                        .foregroundStyle(.secondary)
                }
                
                ForEach(songs) { song in
                    HStack(spacing: 12) {
                        if let artwork = song.artwork {
                            ArtworkImage(artwork, width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else if let uiImage = song.artworkUIImage {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.1))
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(Image(systemName: "music.note").foregroundStyle(.secondary))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(song.title)
                                .font(.body)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            Text(song.artist)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        // Detailed Stats
                        VStack(alignment: .trailing, spacing: 2) {
                            if song.playCount > 0 {
                                Text("\(song.playCount) plays")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .navigationTitle("Top Songs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct GenrePieChart: View {
    let items: [(String, Double)]
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    private var palette: [Color] {
        if themeManager.selectedTheme == .multiColour {
            return [.purple, .pink, .orange, .blue, .cyan, .green, .indigo, .mint]
        } else {
            let accent = themeManager.selectedTheme.accent(for: colorScheme)
            return [
                accent,
                accent.opacity(0.85),
                accent.opacity(0.7),
                accent.opacity(0.55),
                accent.opacity(0.4),
                accent.opacity(0.25),
                accent.opacity(0.12),
                accent.opacity(0.08)
            ]
        }
    }

    var body: some View {
        HStack(spacing: 24) {
            // Determines the displayed segments (Top 5 + 'Other' potentially, but effectively taking top 5)
            let displayItems = Array(items.prefix(5))
            
            // The Donut Chart
            ZStack {
                // Background track
                Circle()
                    .stroke(Color.secondary.opacity(0.1), lineWidth: 16)
                
                // Segments
                ForEach(Array(displayItems.enumerated()), id: \.offset) { index, item in
                    let start = calculateStart(items: displayItems, index: index)
                    let end = start + item.1
                    
                    // Only draw if significant enough to see
                    if item.1 > 0.02 {
                        Circle()
                            .trim(from: start, to: end - 0.02) // subtle gap
                            .stroke(
                                palette[index % palette.count],
                                style: StrokeStyle(lineWidth: 16, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .zIndex(Double(displayItems.count - index)) // stacked correctly
                    }
                }
            }
            .frame(width: 110, height: 110)
            .padding(.leading, 8)
            
            // The Legend
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(displayItems.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(palette[index % palette.count])
                            .frame(width: 8, height: 8)
                        
                        Text(item.0)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .foregroundStyle(.primary)
                            .layoutPriority(1)

                        Spacer(minLength: 8)
                        
                        Text("\(Int(item.1 * 100))%")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private func calculateStart(items: [(String, Double)], index: Int) -> Double {
        var total = 0.0
        for i in 0..<index {
            total += items[i].1
        }
        return total
    }
}

private struct SongRowView: View {
    let index: Int
    let song: SongModel
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank
            Text("\(index + 1)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(index < 3 ? Color.accentColor : Color.secondary)
                .frame(width: 24)
            
            // Artwork
            if let uiImage = song.artworkUIImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 48, height: 48)
                    .overlay(Image(systemName: "music.note").foregroundStyle(.secondary))
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                
                Text(song.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Play Count Badge
            VStack(alignment: .trailing) {
                Text("\(song.playCount)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("plays")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Entertainment Tracking Section

struct EntertainmentTrackingSection: View {
    @Binding var watchedItems: [WatchedEntertainmentItem]
    @State private var viewingType: EntertainmentType?
    @State private var editingItem: WatchedEntertainmentItem?
    
    enum EntertainmentType: String, Identifiable {
        case movie = "Movies"
        case tv = "TV Shows"
        var id: String { rawValue }
    }
    
    private var movies: [WatchedEntertainmentItem] {
        watchedItems.filter { $0.mediaType == "movie" }
    }
    
    private var tvShows: [WatchedEntertainmentItem] {
        watchedItems.filter { $0.mediaType == "tv" }
    }
    
    private let movieGenres = [
        28: "Action", 12: "Adventure", 16: "Animation", 35: "Comedy", 80: "Crime",
        99: "Documentary", 18: "Drama", 10751: "Family", 14: "Fantasy", 36: "History",
        27: "Horror", 10402: "Music", 9648: "Mystery", 10749: "Romance", 878: "Sci-Fi",
        10770: "TV Movie", 53: "Thriller", 10752: "War", 37: "Western"
    ]
    
    private let tvGenres = [
        10759: "Action & Adventure", 16: "Animation", 35: "Comedy", 80: "Crime",
        99: "Documentary", 18: "Drama", 10751: "Family", 10762: "Kids", 9648: "Mystery",
        10763: "News", 10764: "Reality", 10765: "Sci-Fi & Fantasy", 10766: "Soap",
        10767: "Talk", 10768: "War & Politics", 37: "Western"
    ]
    
    private var genreDistribution: [(String, Double)] {
        var counts: [String: Int] = [:]
        var totalCount = 0
        
        for item in watchedItems {
            let mapping = item.mediaType == "movie" ? movieGenres : tvGenres
            for genreId in item.genreIds {
                if let name = mapping[genreId] {
                    counts[name, default: 0] += 1
                    totalCount += 1
                }
            }
        }
        
        guard totalCount > 0 else { return [] }
        
        return counts.map { ($0.key, Double($0.value) / Double(totalCount)) }
            .sorted { $0.1 > $1.1 }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            if watchedItems.isEmpty {
                EmptyStateView()
            } else {
                if !movies.isEmpty {
                    EntertainmentRow(
                        title: "Movies",
                        icon: "film",
                        items: movies,
                        onShowMore: { viewingType = .movie },
                        onItemTap: { editingItem = $0 }
                    )
                }
                
                if !tvShows.isEmpty {
                    EntertainmentRow(
                        title: "TV Shows",
                        icon: "tv",
                        items: tvShows,
                        onShowMore: { viewingType = .tv },
                        onItemTap: { editingItem = $0 }
                    )
                }
                
                Divider()
                    .padding(.horizontal, 18)
                    .opacity(0.5)

                // MARK: - Genre Breakdown
                VStack(alignment: .leading, spacing: 12) {
                    MusicSectionHeader(title: "Genre Breakdown", icon: "chart.pie.fill")
                    
                    if genreDistribution.isEmpty {
                        Text("Not enough data")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    } else {
                        GenrePieChart(items: genreDistribution)
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .sheet(item: $viewingType) { type in
            AllEntertainmentSheet(
                title: type.rawValue,
                items: type == .movie ? movies : tvShows,
                onItemTap: { item in
                    editingItem = item
                }
            )
        }
        .sheet(item: $editingItem) { item in
            LogWatchedSheet(
                isPresented: Binding(
                    get: { editingItem != nil },
                    set: { if !$0 { editingItem = nil } }
                ),
                existingItem: item,
                onAdd: { _ in },
                onUpdate: { updatedItem in
                    if let index = watchedItems.firstIndex(where: { $0.id == item.id }) {
                        watchedItems[index] = updatedItem
                    }
                },
                onDelete: {
                    if let index = watchedItems.firstIndex(where: { $0.id == item.id }) {
                        watchedItems.remove(at: index)
                    }
                }
            )
        }
    }
    
    private struct EntertainmentRow: View {
        let title: String
        let icon: String
        let items: [WatchedEntertainmentItem]
        let onShowMore: () -> Void
        let onItemTap: (WatchedEntertainmentItem) -> Void
        
        var body: some View {
            let rowItems = Array(items.sorted(by: { $0.dateWatched > $1.dateWatched }).prefix(5))
            let hasAnyDescription = rowItems.contains { !$0.comment.isEmpty }
            let cardHeight: CGFloat = 200 + (hasAnyDescription ? 120 : 85)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .foregroundStyle(Color.accentColor)
                        .font(.subheadline)
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 18)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(rowItems) { item in
                            WatchedItemCard(item: item, hasAnyDescription: hasAnyDescription)
                                .onTapGesture {
                                    onItemTap(item)
                                }
                        }
                        
                        if items.count > 5 {
                            Button(action: onShowMore) {
                                VStack(spacing: 8) {
                                    Circle()
                                        .fill(Color.secondary.opacity(0.1))
                                        .frame(width: 48, height: 48)
                                        .overlay(
                                            Image(systemName: "arrow.right")
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                        )
                                    
                                    Text("Show More")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                }
                                .frame(width: 140, height: cardHeight)
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 18)
                }
            }
        }
    }
    
    private struct EmptyStateView: View {
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Label("No entertainment items yet", systemImage: "popcorn")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Add a new tv show or movie with the Log Watched button to start tracking.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
    }
}

private struct WatchedItemCard: View {
    let item: WatchedEntertainmentItem
    let hasAnyDescription: Bool
    
    private var infoHeight: CGFloat {
        hasAnyDescription ? 120 : 85
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Poster/Image area
            AsyncImage(url: item.fullPosterUrl) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    ZStack {
                        Color.gray.opacity(0.3)
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                    }
                case .empty:
                    ZStack {
                        Color.gray.opacity(0.3)
                        ProgressView()
                    }
                @unknown default:
                    Color.gray.opacity(0.3)
                }
            }
            .frame(width: 140, height: 200)
            .clipped()
            
            // Info area
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { index in
                        let starValue = Double(index)
                        if starValue <= item.rating {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                        } else if starValue - 0.5 <= item.rating {
                            Image(systemName: "star.leadinghalf.filled")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                        } else {
                            Image(systemName: "star")
                                .font(.caption2)
                                .foregroundStyle(.secondary.opacity(0.3))
                        }
                    }
                }
                
                Text(item.dateWatched.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                if !item.comment.isEmpty {
                    Text(item.comment)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else if hasAnyDescription {
                    // Hidden spacer-like text to ensure consistent height if property is true
                    Text(" ")
                        .font(.caption2)
                        .lineLimit(2)
                }
                
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(width: 140, height: infoHeight, alignment: .topLeading)
            .background(.regularMaterial)
        }
        .frame(width: 140, height: 200 + infoHeight)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

private struct AllEntertainmentSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let items: [WatchedEntertainmentItem]
    let onItemTap: (WatchedEntertainmentItem) -> Void
    
    @State private var sortOption: SortOption = .rating
    
    enum SortOption: String, CaseIterable, Identifiable {
        case rating = "Rating"
        case date = "Date Watched"
        case alpha = "Title"
        var id: String { rawValue }
    }
    
    var sortedItems: [WatchedEntertainmentItem] {
        switch sortOption {
        case .rating:
            return items.sorted {
                if $0.rating == $1.rating {
                    return $0.dateWatched > $1.dateWatched
                }
                return $0.rating > $1.rating
            }
        case .date:
            return items.sorted { $0.dateWatched > $1.dateWatched }
        case .alpha:
            return items.sorted { $0.title < $1.title }
        }
    }
    
    var body: some View {
        let hasAnyDescription = sortedItems.contains { !$0.comment.isEmpty }
        
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 16)], spacing: 20) {
                    ForEach(sortedItems) { item in
                        WatchedItemCard(item: item, hasAnyDescription: hasAnyDescription)
                            .onTapGesture {
                                onItemTap(item)
                            }
                    }
                }
                .padding()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        ForEach(SortOption.allCases) { option in
                            Button {
                                sortOption = option
                            } label: {
                                if sortOption == option {
                                    Label(option.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(option.rawValue)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle")
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct LogWatchedSheet: View {
    @Binding var isPresented: Bool
    var existingItem: WatchedEntertainmentItem? = nil
    var onAdd: (WatchedEntertainmentItem) -> Void
    var onUpdate: ((WatchedEntertainmentItem) -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    
    @State private var query = ""
    @State private var searchResults: [TMDBItem] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var selectedItem: TMDBItem?
    
    // Form state
    @State private var rating: Double = 0
    @State private var comment = ""
    @State private var dateWatched = Date()
    @State private var showCalendar = false
    @State private var showDeleteConfirmation = false
    @FocusState private var isCommentFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    if selectedItem == nil && existingItem == nil {
                        // Search Mode
                        searchView
                    } else {
                        // Entry Mode
                        entryFormView
                    }
                }
                
                if showCalendar {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation {
                                showCalendar = false
                            }
                        }
                    
                    CalendarComponent(selectedDate: $dateWatched, showCalendar: $showCalendar)
                        .transition(.opacity)
                        .zIndex(1)
                }
                
                SimpleKeyboardDismissBar(
                    isVisible: isCommentFocused,
                    tint: Color.accentColor,
                    onDismiss: { isCommentFocused = false }
                )
            }
            .navigationTitle(existingItem != nil ? "Edit Details" : (selectedItem == nil ? "Log Watched" : "Add Details"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                
                if selectedItem != nil || existingItem != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            saveEntry()
                        }
                        .disabled(rating == 0)
                    }
                }
            }
            .onAppear {
                if let existing = existingItem {
                    // Pre-populate
                    rating = existing.rating
                    comment = existing.comment
                    dateWatched = existing.dateWatched
                    
                    // Reconstruct TMDBItem for display
                    selectedItem = TMDBItem(
                        id: existing.tmdbId,
                        title: existing.mediaType == "movie" ? existing.title : nil,
                        name: existing.mediaType == "tv" ? existing.title : nil,
                        overview: existing.overview,
                        posterPath: existing.posterPath,
                        backdropPath: nil,
                        releaseDate: nil,
                        firstAirDate: nil,
                        mediaType: existing.mediaType,
                        genreIds: existing.genreIds
                    )
                }
            }
            .alert("Delete Entry?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    onDelete?()
                    isPresented = false
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this entry? This actions cannot be undone.")
            }
        }
    }
    
    private var searchView: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search movies & TV shows...", text: $query)
                    .submitLabel(.search)
                    .onChange(of: query) { _, newValue in
                        Task {
                            guard !newValue.isEmpty else {
                                searchResults = []
                                hasSearched = false
                                return
                            }
                            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s debounce
                            if !Task.isCancelled && query == newValue {
                                performSearch()
                            }
                        }
                    }
                
                if !query.isEmpty {
                    Button {
                        query = ""
                        searchResults = []
                        hasSearched = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding()

            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Link(destination: URL(string: "https://www.themoviedb.org/")!) {
                    Text("Data sourced from The Movie Database (TMDB)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            
            if isSearching {
                ProgressView()
                    .padding(.top, 40)
                Spacer()
            } else if hasSearched && searchResults.isEmpty && !query.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                List(searchResults) { item in
                    Button {
                        withAnimation {
                            selectedItem = item
                        }
                    } label: {
                        HStack(spacing: 12) {
                            AsyncImage(url: item.fullPosterUrl) { phase in
                                if let image = phase.image {
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else {
                                    Color.gray.opacity(0.3)
                                }
                            }
                            .frame(width: 48, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.displayTitle)
                                    .font(.system(.body, design: .rounded, weight: .semibold))
                                    .foregroundStyle(.primary)
                                
                                HStack {
                                    Text(item.mediaType == "movie" ? "Movie" : "TV Show")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.secondary.opacity(0.1), in: Capsule())
                                    
                                    if !item.displayDate.isEmpty {
                                        Text(item.displayDate)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        }
    }
    
    private var entryFormView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack(spacing: 16) {
                    AsyncImage(url: selectedItem?.fullPosterUrl) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fit)
                        } else {
                            Color.gray.opacity(0.3)
                        }
                    }
                    .frame(width: 100, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 5)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(selectedItem?.displayTitle ?? "")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(selectedItem?.overview ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(5)
                    }
                }
                .padding()
                
                Divider()
                
                // Rating
                VStack(spacing: 12) {
                    Text("Your Rating")
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        ForEach(1...5, id: \.self) { index in
                            let starValue = Double(index)
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    if rating == starValue - 0.5 {
                                        rating = starValue
                                    } else if rating == starValue {
                                        rating = starValue - 0.5
                                    } else {
                                        rating = starValue - 0.5
                                    }
                                }
                            } label: {
                                Image(systemName: starValue <= rating ? "star.fill" : (starValue - 0.5 <= rating ? "star.leadinghalf.filled" : "star"))
                                    .font(.system(size: 32))
                                    .foregroundStyle(starValue - 0.5 <= rating ? Color.yellow : Color.secondary.opacity(0.3))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Divider()
                
                // Details
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date Watched")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Button {
                            withAnimation {
                                showCalendar = true
                            }
                        } label: {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundStyle(Color.accentColor)
                                Text(dateWatched.formatted(date: .long, time: .omitted))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Comments")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TextField("What did you think?", text: $comment, axis: .vertical)
                            .focused($isCommentFocused)
                            .lineLimit(3...6)
                            .padding(12)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal)
                
                if existingItem != nil {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Text("Delete Entry")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.red)
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                }
                
                Color.clear.frame(height: 20)
            }
            .padding(.vertical)
        }
    }
    
    private func performSearch() {
        guard !query.isEmpty else { return }
        isSearching = true
        // Keep hasSearched false until done
        Task {
            do {
                let results = try await TMDBService.shared.search(query: query)
                await MainActor.run {
                    self.searchResults = results
                    self.isSearching = false
                    self.hasSearched = true
                }
            } catch {
                print("Error searching: \(error)")
                await MainActor.run {
                    self.isSearching = false
                    self.hasSearched = true
                }
            }
        }
    }
    
    private func saveEntry() {
        guard let item = selectedItem else { return }
        
        // Preserve original ID if editing, else new UUID
        let newEntry = WatchedEntertainmentItem(
            id: existingItem?.id ?? UUID(),
            tmdbId: item.id,
            title: item.displayTitle,
            overview: item.overview,
            posterPath: item.posterPath,
            rating: rating,
            comment: comment,
            dateWatched: dateWatched,
            mediaType: item.mediaType ?? "movie",
            genreIds: item.genreIds ?? []
        )
        
        if existingItem != nil {
            onUpdate?(newEntry)
        } else {
            onAdd(newEntry)
        }
        isPresented = false
    }
}

private struct SimpleKeyboardDismissBar: View {
    var isVisible: Bool
    var tint: Color
    var onDismiss: () -> Void

    var body: some View {
        VStack {
            Spacer()
            if isVisible {
                HStack {
                    Spacer()

                    Button(action: onDismiss) {
                        Label("Dismiss", systemImage: "keyboard.chevron.compact.down")
                            .font(.callout.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: Capsule())
                            .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
                            .foregroundStyle(tint)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

