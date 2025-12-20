import SwiftUI

struct TravelTabView: View {
    @Binding var account: Account
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var showCalendar = false
    @Binding var selectedDate: Date
    @State private var showAccountsView = false
    @State private var isShowingEditor = false
    @State private var editorSeedDate: Date = Date()
    @State private var itineraryEvents: [ItineraryEvent] = ItineraryEvent.mockEvents

    var body: some View {
        ZStack {
            backgroundView
            ScrollView {
                VStack(spacing: 12) {
                    HeaderComponent(showCalendar: $showCalendar, selectedDate: $selectedDate, onProfileTap: { showAccountsView = true })
                        .environmentObject(account)

                    HStack {
                        Text("Itinerary Tracking")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)

                        Spacer()

                        Button {
                            editorSeedDate = selectedDate
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
                    .padding(.top, 48)
                    .padding(.bottom, 8)

                    MapSection(events: $itineraryEvents)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 24)

                    ItineraryTrackingSection(events: itineraryEvents)
                        .padding(.horizontal, 18)
                }
                .padding(.bottom, 24)
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
                event: nil,
                defaultDate: editorSeedDate,
                onSave: { newEvent in
                    itineraryEvents.append(newEvent)
                    isShowingEditor = false
                },
                onCancel: {
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
}
