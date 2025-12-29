import SwiftUI

struct TravelTabView: View {
    @Binding var account: Account
    @Binding var itineraryEvents: [ItineraryEvent]
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var showCalendar = false
    @Binding var selectedDate: Date
    var isPro: Bool
    @State private var showAccountsView = false
    @State private var showProSheet = false
    @State private var isShowingEditor = false
    @State private var editorSeedDate: Date = Date()
    @State private var editingEvent: ItineraryEvent? = nil

    var body: some View {
        ZStack {
            backgroundView
            ScrollView {
                VStack(spacing: 12) {
                    HeaderComponent(showCalendar: $showCalendar, selectedDate: $selectedDate, onProfileTap: { showAccountsView = true }, isPro: isPro)
                        .environmentObject(account)

                    VStack(spacing: 12) {
                        HStack {
                            Text("Itinerary Tracking")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)

                        Spacer()

                        Button {
                            editorSeedDate = selectedDate
                            editingEvent = nil
                            isShowingEditor = true
                        } label: {
                            Label("Add", systemImage: "plus")
                                .font(.callout)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .glassEffect(in: .rect(cornerRadius: 18.0))
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.top, 38)
                    .padding(.bottom, 8)

                    MapSection(events: $itineraryEvents)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 24)

                    ItineraryTrackingSection(
                        events: itineraryEvents,
                        onEdit: { event in
                            editingEvent = event
                            editorSeedDate = event.date
                            isShowingEditor = true
                        },
                        onDelete: { event in
                            deleteEvent(event)
                        }
                    )
                        .padding(.horizontal, 18)
                    }
                    .opacity(isPro ? 1 : 0.5)
                    .blur(radius: isPro ? 0 : 4)
                    .disabled(!isPro)
                }
                .padding(.bottom, 24)
            }
            .overlay {
                if !isPro {
                    ZStack {
                        Color.black.opacity(0.001)
                            .onTapGesture {}

                        Button {
                            showProSheet = true
                        } label: {
                            VStack(spacing: 8) {
                                HStack {
                                    let accent = themeManager.selectedTheme == .multiColour ? nil : themeManager.selectedTheme.accent(for: colorScheme)

                                    if let accent {
                                        Image("logo")
                                            .resizable()
                                            .renderingMode(.template)
                                            .foregroundStyle(accent)
                                            .aspectRatio(contentMode: .fit)
                                            .frame(height: 40)
                                            .padding(.leading, 4)
                                            .offset(y: 6)
                                    } else {
                                        Image("logo")
                                            .resizable()
                                            .renderingMode(.original)
                                            .aspectRatio(contentMode: .fit)
                                            .frame(height: 40)
                                            .padding(.leading, 4)
                                            .offset(y: 6)
                                    }
                                    
                                    Text("PRO")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(accent ?? Color.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                .fill(
                                                    accent.map {
                                                        LinearGradient(
                                                            gradient: Gradient(colors: [$0, $0.opacity(0.85)]),
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                    } ?? LinearGradient(
                                                        gradient: Gradient(colors: [
                                                            Color(red: 0.74, green: 0.43, blue: 0.97),
                                                            Color(red: 0.83, green: 0.99, blue: 0.94)
                                                        ]),
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                        )
                                        .offset(y: 6)
                                }
                                .padding(.bottom, 5)

                                Text("Trackerio Pro")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                
                                Text("Upgrade to unlock the Travel tab + More")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .glassEffect(in: .rect(cornerRadius: 16.0))
                        }
                        .buttonStyle(.plain)
                        .sheet(isPresented: $showProSheet) {
                            ProSubscriptionView()
                        }
                    }
                }
            }

            if showCalendar {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture { showCalendar = false }
                CalendarComponent(selectedDate: $selectedDate, showCalendar: $showCalendar)
            }
        }
        .navigationDestination(isPresented: $showAccountsView) {
            AccountsView(account: $account)
        }
        .sheet(isPresented: $isShowingEditor) {
            ItineraryEventEditorView(
                event: editingEvent,
                defaultDate: editorSeedDate,
                onSave: { newEvent in
                    upsertEvent(newEvent)
                    editingEvent = nil
                    isShowingEditor = false
                },
                onCancel: {
                    editingEvent = nil
                    isShowingEditor = false
                }
            )
        }
    }
}

private extension TravelTabView {
    var currentAccent: Color {
        if themeManager.selectedTheme == .multiColour {
            return .accentColor
        }
        return themeManager.selectedTheme.accent(for: colorScheme)
    }

    @ViewBuilder
    var backgroundView: some View {
        if themeManager.selectedTheme == .multiColour {
            GradientBackground(theme: .travel)
        } else {
            themeManager.selectedTheme.background(for: colorScheme)
                .ignoresSafeArea()
        }
    }

    private func upsertEvent(_ event: ItineraryEvent) {
        var updated = itineraryEvents
        if let idx = updated.firstIndex(where: { $0.id == event.id }) {
            updated[idx] = event
        } else {
            updated.append(event)
        }
        updated.sort { $0.date < $1.date }
        itineraryEvents = updated
    }

    private func deleteEvent(_ event: ItineraryEvent) {
        itineraryEvents.removeAll { $0.id == event.id }
    }
}
