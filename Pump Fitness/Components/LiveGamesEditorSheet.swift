import SwiftUI

struct LiveGamesEditorSheet: View {
    @AppStorage("trackedLiveSports") private var trackedSportsRaw: String = "basketball,football" 
    @StateObject private var service = LiveSportsService.shared
    
    var onDismiss: () -> Void

    private var trackedSports: [String] {
        trackedSportsRaw.split(separator: ",").map(String.init)
    }
    
    private var availableSports: [SportDefinition] {
        service.availableSports.filter { !trackedSports.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    
                    // Tracked Categories
                    if !trackedSports.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            LiveGamesEditorHeader(title: "Tracked Categories")

                            VStack(spacing: 12) {
                                ForEach(trackedSports, id: \.self) { sportId in
                                    let sportName = service.availableSports.first(where: { $0.id == sportId })?.name ?? sportId.capitalized
                                    
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(Color.accentColor.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                            .overlay(
                                                Image(systemName: "sportscourt.fill")
                                                    .foregroundStyle(Color.accentColor)
                                            )

                                        Text(sportName)
                                            .font(.subheadline.weight(.semibold))

                                        Spacer()

                                        Button(role: .destructive) {
                                            removeSport(sportId)
                                        } label: {
                                            Image(systemName: "trash")
                                                .foregroundStyle(.red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding()
                                    .surfaceCard(16)
                                }
                            }
                        }
                    }

                    // Quick Add
                    if !availableSports.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            LiveGamesEditorHeader(title: "Quick Add")

                            VStack(spacing: 12) {
                                ForEach(availableSports) { sport in
                                    HStack(spacing: 14) {
                                        Circle()
                                            .fill(Color.accentColor.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                            .overlay(
                                                Image(systemName: "sportscourt.fill")
                                                    .foregroundStyle(Color.accentColor)
                                            )

                                        VStack(alignment: .leading) {
                                            Text(sport.name)
                                                .font(.subheadline.weight(.semibold))
                                        }

                                        Spacer()

                                        Button {
                                            addSport(sport.id)
                                        } label: {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 24, weight: .semibold))
                                                .foregroundStyle(Color.accentColor)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .surfaceCard(18)
                                }
                            }
                        }
                    } else if service.availableSports.isEmpty {
                         ProgressView()
                             .padding()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("Live Games")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .task {
                await service.fetchSports()
            }
        }
    }
    
    private func addSport(_ id: String) {
        var current = trackedSports
        if !current.contains(id) {
            current.append(id)
            trackedSportsRaw = current.joined(separator: ",")
        }
    }
    
    private func removeSport(_ id: String) {
        var current = trackedSports
        current.removeAll(where: { $0 == id })
        trackedSportsRaw = current.joined(separator: ",")
    }
}

private struct LiveGamesEditorHeader: View {
    var title: String

    var body: some View {
        Text(title.uppercased())
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
    }
}
