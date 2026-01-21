//
//  MusicSourcesSheet.swift
//  Pump Fitness
//
//  Created for Trackerio.
//

import SwiftUI
import MusicKit

struct MusicSourcesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var musicService = MusicService.shared
    @ObservedObject private var spotifyService = SpotifyService.shared
    
    @State private var isConnectingSpotify = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "applelogo")
                            .font(.title2)
                            .frame(width: 32)
                        
                        VStack(alignment: .leading) {
                            Text("Apple Music")
                                .font(.headline)
                            if musicService.isAuthorized {
                                Text("Connected")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            } else {
                                Text("Not Connected")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $musicService.isAppleMusicEnabled)
                            .labelsHidden()
                            .onChange(of: musicService.isAppleMusicEnabled) { _, newValue in
                                if newValue && !musicService.isAuthorized {
                                    Task { await musicService.requestAuthorization() }
                                }
                            }
                    }
                    .padding(.vertical, 4)
                    
                    HStack {
                        Image(systemName: "music.note") // Placeholder for Spotify logo
                            .font(.title2)
                            .foregroundStyle(.green)
                            .frame(width: 32)
                        
                        VStack(alignment: .leading) {
                            Text("Spotify")
                                .font(.headline)
                            if spotifyService.isConnected {
                                Text("Connected as User")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            } else {
                                Text("Connect Account")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $musicService.isSpotifyEnabled)
                            .labelsHidden()
                            .onChange(of: musicService.isSpotifyEnabled) { _, newValue in
                                if newValue && !spotifyService.isConnected {
                                    connectSpotify()
                                }
                            }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Music Sources")
                } footer: {
                    Text("Enable sources to track your listening history and generate combined stats across platforms.")
                }
                
                if musicService.isSpotifyEnabled && !spotifyService.isConnected {
                    Section {
                        Button {
                            connectSpotify()
                        } label: {
                            if isConnectingSpotify {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Connect to Spotify")
                                    .frame(maxWidth: .infinity)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                }
                
                if spotifyService.isConnected {
                    Section {
                        Button("Disconnect Spotify", role: .destructive) {
                            spotifyService.disconnect()
                            // If we disconnect, we might optionally disable the toggle, 
                            // keep it enabled but show "Not Connected"
                        }
                    }
                }
            }
            .navigationTitle("Music Services")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func connectSpotify() {
        guard !isConnectingSpotify else { return }
        isConnectingSpotify = true
        Task {
            let success = await spotifyService.connect()
            DispatchQueue.main.async {
                isConnectingSpotify = false
                if success {
                    // Refresh main service data
                    Task { await musicService.fetchData() }
                }
            }
        }
    }
}
