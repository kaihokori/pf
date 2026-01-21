//
//  EntertainmentTrackingSection.swift
//  Pump Fitness
//
//  Created for Trackerio.
//

import SwiftUI
import MusicKit

struct EntertainmentTrackingSection: View {
    @Environment(\.openURL) private var openURL
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
            .background(.thinMaterial) // Cleaner glass look
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 5)
            .task {
                await musicService.fetchData()
            }
            .sheet(isPresented: $showHistorySheet) {
                MusicHistorySheet(songs: musicService.topSongs)
            }
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
                    
                    Button {
                        // Placeholder for learn more
                    } label: {
                        Text("Learn more about integration")
                            .font(.subheadline)
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
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

// MARK: - Subcomponents

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
    // Modern, vibrant palette
    private let palette: [Color] = [
        .purple, .pink, .orange, .blue, 
        .cyan, .green, .indigo, .mint
    ]
    
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

