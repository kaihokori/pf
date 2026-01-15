import SwiftUI
import TipKit
import MapKit

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
    @StateObject private var tripRecorder = TripRecorderManager()
    @State private var selectedGPSTrip: Trip?

    // Recording Confirmation
    @State private var showingStartConfirmation = false
    @State private var showingStopConfirmation = false
    @State private var recordingDistance: Double = 500

    // Multiple Trip Management
    @State private var selectedItineraryTripId: String?
    @State private var showingCreateTripSheet = false
    @State private var newTripTitle = ""
    @State private var editingTripId: String?

    var body: some View {
        ZStack {
            backgroundView
            ScrollView {
                VStack(spacing: 12) {
                    VStack(spacing: 12) {
                        HeaderComponent(showCalendar: $showCalendar, selectedDate: $selectedDate, onProfileTap: { showAccountsView = true }, isPro: isPro)
                            .environmentObject(account)
                        
                        VStack(spacing: 0) {
                            tripSelectionHeader
                            
                            if let binding = selectedTripBinding {
                                MapSection(events: binding.events)
                                    .padding(.horizontal, 18)
                                    .padding(.bottom, 24)
                                    .travelTip(.map, isEnabled: isPro)
                                
                                ItineraryTrackingSection(
                                    events: binding.wrappedValue.events,
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
                                .travelTip(.itineraryTracking, isEnabled: isPro)
                                
                                Spacer()
                                    .frame(height: 24)

                                recordingsSection
                                    .padding(.bottom, 24)
                            } else {
                                emptyTripsState
                                    .padding(.horizontal, 18)
                                    .padding(.bottom, 24)
                            }
                        }
                        .opacity(isPro ? 1 : 0.5)
                        .blur(radius: isPro ? 0 : 4)
                        .disabled(!isPro)
                        .overlay {
                            if !isPro {
                                ZStack {
                                    Color.black.opacity(0.001) // Capture taps
                                        .onTapGesture {
                                            // no-op capture
                                        }

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
                                                    .foregroundStyle(Color.white)
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

                                            Text("Upgrade to unlock Itinerary Features + More")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding()
                                        .glassEffect(in: .rect(cornerRadius: 16.0))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
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
        .sheet(isPresented: $showingCreateTripSheet) {
            createTripSheet
        }
        .sheet(isPresented: $showProSheet) {
            ProSubscriptionView()
        }
        .sheet(isPresented: $showingStartConfirmation) {
            recordingConfirmationSheet(isStarting: true)
        }
        .sheet(isPresented: $showingStopConfirmation) {
            recordingConfirmationSheet(isStarting: false)
        }
        .fullScreenCover(item: $selectedGPSTrip) { trip in
            if #available(iOS 17.0, *) {
                TripDetailView(trip: trip, recorder: tripRecorder)
            } else {
                VStack {
                    HStack {
                        Button(action: { selectedGPSTrip = nil }) {
                            ZStack {
                                Image(systemName: "chevron.backward")
                                    .foregroundStyle(currentAccent)
                                    .frame(width: 45, height: 45)
                                    .font(.system(size: 20))
                            }
                            .background(.thickMaterial, in: .rect(cornerRadius: 10))
                        }
                        .padding(.leading, 20)
                        Spacer()
                    }
                    .padding(.top, 12)
                    
                    Spacer()
                    Text("Requires iOS 17")
                    Spacer()
                }
            }
        }
        .onAppear {
            if account.itineraryTrips.isEmpty {
                let defaultTrip = ItineraryTrip(title: "My Trip")
                account.itineraryTrips.append(defaultTrip)
                selectedItineraryTripId = defaultTrip.id
            } else if selectedItineraryTripId == nil, let first = account.itineraryTrips.first {
                selectedItineraryTripId = first.id
            }
        }
        .onChange(of: account.itineraryTrips) { _, trips in
            if let id = selectedItineraryTripId, !trips.contains(where: { $0.id == id }) {
                selectedItineraryTripId = trips.first?.id
            } else if selectedItineraryTripId == nil, let first = trips.first {
                selectedItineraryTripId = first.id
            }
        }
        .onChange(of: tripRecorder.currentTrip) { _, newTrip in
            guard let newTrip = newTrip, let itineraryId = newTrip.itineraryTripId else { return }
            if let index = account.itineraryTrips.firstIndex(where: { $0.id == itineraryId }) {
                // Sync points from the GPS recorder to the main Account model
                account.itineraryTrips[index].points = newTrip.points
            }
        }
        .onChange(of: selectedItineraryTripId) { _, _ in
            if tripRecorder.isRecording {
                tripRecorder.stopTrip()
            }
        }
    }
}

private extension TravelTabView {
    @ViewBuilder
    var tripSelectionHeader: some View {
        HStack {
            Menu {
                ForEach(account.itineraryTrips.sorted(by: { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending })) { trip in
                    Button {
                        selectedItineraryTripId = trip.id
                    } label: {
                        Label(trip.title, systemImage: "suitcase")
                    }
                }
                
                Divider()
                
                if let id = selectedItineraryTripId {
                    Button {
                        if let trip = account.itineraryTrips.first(where: { $0.id == id }) {
                            editingTripId = id
                            newTripTitle = trip.title
                            showingCreateTripSheet = true
                        }
                    } label: {
                        Label("Edit Trip Details", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        if let index = account.itineraryTrips.firstIndex(where: { $0.id == id }) {
                            account.itineraryTrips.remove(at: index)
                            
                            if account.itineraryTrips.isEmpty {
                                let defaultTrip = ItineraryTrip(title: "My Trip")
                                account.itineraryTrips.append(defaultTrip)
                                selectedItineraryTripId = defaultTrip.id
                            } else {
                                selectedItineraryTripId = account.itineraryTrips.first?.id
                            }
                        }
                    } label: {
                        Label("Delete Current Trip", systemImage: "trash")
                    }
                }
                
                Divider()
                
                Button {
                    editingTripId = nil
                    newTripTitle = ""
                    showingCreateTripSheet = true
                } label: {
                    Label("Create New Trip", systemImage: "plus")
                }
            } label: {
                HStack(spacing: 6) {
                    Text(currentTripTitle)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.subheadline)
                }
            }
            .foregroundStyle(.primary)
            .tint(.primary)
            
            Spacer()
            
            if selectedItineraryTripId != nil {
                Button {
                    editorSeedDate = selectedDate
                    editingEvent = nil
                    isShowingEditor = true
                } label: {
                    Label("Add Event", systemImage: "plus")
                        .font(.callout)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassEffect(in: .rect(cornerRadius: 18.0))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    var recordingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Journey Recordings")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text("Track your exact path while you travel.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if tripRecorder.isRecording {
                    Button {
                        showingStopConfirmation = true
                    } label: {
                        Label("Stop", systemImage: "stop.circle.fill")
                            .font(.callout)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .glassEffect(in: .rect(cornerRadius: 18.0))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                } else {
                    Button {
                        showingStartConfirmation = true
                    } label: {
                        Label("Record", systemImage: "record.circle.fill")
                            .font(.callout)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .glassEffect(in: .rect(cornerRadius: 18.0))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 18)

            let tripRecordings: [Trip] = {
                var recordings = tripRecorder.pastTrips.filter { $0.itineraryTripId == selectedItineraryTripId }
                if let currentTrip = tripRecorder.currentTrip, currentTrip.itineraryTripId == selectedItineraryTripId {
                    recordings.removeAll(where: { $0.id == currentTrip.id })
                    recordings.insert(currentTrip, at: 0)
                }
                return recordings
            }()
            
            if tripRecordings.isEmpty && !tripRecorder.isRecording {
                 VStack(alignment: .leading, spacing: 8) {
                      Label("No recordings yet for this trip.", systemImage: "map")
                          .font(.headline.weight(.semibold))
                          .foregroundStyle(.primary)
                      Text("Start recording your journey by tapping the record button above.")
                          .font(.subheadline)
                          .foregroundStyle(.secondary)
                  }
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .padding(16)
                  .glassEffect(in: .rect(cornerRadius: 16.0))
                  .padding(.horizontal, 18)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                    ForEach(tripRecordings) { trip in
                        Button {
                            selectedGPSTrip = trip
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Map(initialPosition: (trip.points.isEmpty && trip.isActive) ? .userLocation(fallback: .automatic) : .region(trip.region), interactionModes: []) {
                                    if !trip.points.isEmpty {
                                        MapPolyline(coordinates: trip.points.map { $0.coordinate })
                                            .stroke(.blue, lineWidth: 3)
                                    }
                                }
                                .aspectRatio(1.5, contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(Color.secondary.opacity(0.1), lineWidth: 1)
                                    )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(trip.displayTitle(in: tripRecorder.pastTrips))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .lineLimit(1)
                                        .foregroundStyle(.primary)
                                    Text("\(trip.points.count) points")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(10)
                            .glassEffect(in: .rect(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
            }
        }
    }

    var currentAccent: Color {
        if themeManager.selectedTheme == .multiColour {
            return .accentColor
        }
        return themeManager.selectedTheme.accent(for: colorScheme)
    }
    
    var currentTripTitle: String {
        if let id = selectedItineraryTripId, let trip = account.itineraryTrips.first(where: { $0.id == id }) {
            return trip.title
        }
        return "No Trip Selected"
    }

    @ViewBuilder
    func recordingConfirmationSheet(isStarting: Bool) -> some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(isStarting ? Color.blue.opacity(0.1) : Color.red.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: isStarting ? "record.circle.fill" : "stop.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(isStarting ? .blue : .red)
            }
            .padding(.top, 40)
            
            VStack(spacing: 8) {
                Text(isStarting ? "Start Recording?" : "Stop Recording?")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(isStarting ? "This will track your location while you travel. You can stop it at any time." : "This will end your current journey recording and save it to your trip.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            if isStarting {
                VStack(spacing: 12) {
                    HStack {
                        Label("Update Frequency", systemImage: "timer")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(recordingDistance))m")
                            .font(.headline.bold())
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1), in: Capsule())
                    }
                    .padding(.horizontal, 24)
                    
                    Slider(value: $recordingDistance, in: 50...2000, step: 50)
                        .tint(.blue)
                        .padding(.horizontal, 24)
                    
                    Text("A point will be saved every \(Int(recordingDistance))m.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 24)
            }
            
            VStack(spacing: 12) {
                Button {
                    withAnimation {
                        if isStarting {
                            tripRecorder.startTrip(itineraryTripId: selectedItineraryTripId, distanceFilter: recordingDistance)
                            showingStartConfirmation = false
                        } else {
                            tripRecorder.stopTrip()
                            showingStopConfirmation = false
                        }
                    }
                } label: {
                    Text(isStarting ? "Start Recording" : "Stop Recording")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isStarting ? Color.blue : Color.red)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 24)
                
                Button("Cancel", role: .cancel) {
                    if isStarting {
                        showingStartConfirmation = false
                    } else {
                        showingStopConfirmation = false
                    }
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.bottom, 20)
            }
        }
        .presentationDetents(isStarting ? [.height(500)] : [.height(380)])
        .presentationDragIndicator(.visible)
    }

    var selectedTripBinding: Binding<ItineraryTrip>? {
        guard let id = selectedItineraryTripId,
              account.itineraryTrips.contains(where: { $0.id == id })
        else { return nil }
        
        return Binding(
            get: {
                if let trip = account.itineraryTrips.first(where: { $0.id == id }) {
                    return trip
                }
                return ItineraryTrip(id: "placeholder", title: "Unavailable", events: [], points: [])
            },
            set: { newTrip in
                var trips = account.itineraryTrips
                if let index = trips.firstIndex(where: { $0.id == id }) {
                    trips[index] = newTrip
                    account.itineraryTrips = trips
                }
            }
        )
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
    
    var emptyTripsState: some View {
        VStack(spacing: 8) {
            Image(systemName: "suitcase.fill")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No Trips Added Yet")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("Create a trip to start adding itinerary events.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                showingCreateTripSheet = true
            } label: {
                Text("Create Trip")
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .glassEffect(in: .rect(cornerRadius: 16))
    }
    
    var createTripSheet: some View {
        NavigationStack {
            Form {
                Section("Trip Details") {
                    TextField("Trip Title (e.g. Paris 2024)", text: $newTripTitle)
                }
            }
            .navigationTitle(editingTripId == nil ? "New Trip" : "Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingCreateTripSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editingTripId == nil ? "Create" : "Save") {
                        if let id = editingTripId, let index = account.itineraryTrips.firstIndex(where: { $0.id == id }) {
                            account.itineraryTrips[index].title = newTripTitle.isEmpty ? "Untitled Trip" : newTripTitle
                        } else {
                            let newTrip = ItineraryTrip(
                                title: newTripTitle.isEmpty ? "New Trip" : newTripTitle,
                                events: []
                            )
                            account.itineraryTrips.append(newTrip)
                            selectedItineraryTripId = newTrip.id
                        }
                        showingCreateTripSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func upsertEvent(_ event: ItineraryEvent) {
        guard let id = selectedItineraryTripId,
              let index = account.itineraryTrips.firstIndex(where: { $0.id == id })
        else { return }
        
        var updatedEvents = account.itineraryTrips[index].events
        if let idx = updatedEvents.firstIndex(where: { $0.id == event.id }) {
            updatedEvents[idx] = event
        } else {
            updatedEvents.append(event)
        }
        updatedEvents.sort { $0.date < $1.date }
        account.itineraryTrips[index].events = updatedEvents
        
        if UserDefaults.standard.object(forKey: "alerts.itineraryEnabled") as? Bool ?? true {
            NotificationsHelper.scheduleItineraryNotifications(updatedEvents)
        }
    }

    private func deleteEvent(_ event: ItineraryEvent) {
        guard let id = selectedItineraryTripId,
              let index = account.itineraryTrips.firstIndex(where: { $0.id == id })
        else { return }
        
        var updatedEvents = account.itineraryTrips[index].events
        updatedEvents.removeAll { $0.id == event.id }
        account.itineraryTrips[index].events = updatedEvents
        
        if UserDefaults.standard.object(forKey: "alerts.itineraryEnabled") as? Bool ?? true {
            NotificationsHelper.scheduleItineraryNotifications(updatedEvents)
        }
    }
}

// MARK: - Travel Tips

@available(iOS 17.0, *)
struct TravelTips {
    @Parameter
    static var currentStep: Int = 0

    struct MapTip: Tip {
        var title: Text { Text("Maps") }
        var message: Text? { Text("Tap any location in the map or tap the Add button to plan your itinerary.") }
        var image: Image? { Image(systemName: "map.fill") }
        
        var rules: [Rule] {
            #Rule(TravelTips.$currentStep) { $0 == 0 }
        }
        
        var actions: [Action] {
            Action(id: "next", title: "Next")
        }
    }

    struct ItineraryTrackingTip: Tip {
        var title: Text { Text("Itinerary") }
        var message: Text? { Text("Tap events to check details and get directions.") }
        var image: Image? { Image(systemName: "list.bullet.clipboard.fill") }
        
        var rules: [Rule] {
            #Rule(TravelTips.$currentStep) { $0 == 1 }
        }
        
        var actions: [Action] {
            Action(id: "finish", title: "Finish")
        }
    }

    struct JourneyRecordingGuidanceTip: Tip {
        var title: Text { Text("Capture Your Journey") }
        var message: Text? { Text("Move around to capture where you've gone on your trip! Points are recorded as you travel.") }
        var image: Image? { Image(systemName: "figure.walk") }
        
        var options: [Option] {
            MaxDisplayCount(9999)
            IgnoresDisplayFrequency(true)
        }
    }
}

enum TravelTipType {
    case map
    case itineraryTracking
    case recordingGuidance
}

extension View {
    @ViewBuilder
    func travelTip(_ type: TravelTipType, isEnabled: Bool = true, onStepChange: ((Int) -> Void)? = nil) -> some View {
        if #available(iOS 17.0, *), isEnabled {
            self.background {
                Color.clear
                    .applyTravelTip(type, onStepChange: onStepChange)
            }
        } else {
            self
        }
    }
}

@available(iOS 17.0, *)
extension View {
    @ViewBuilder
    func applyTravelTip(_ type: TravelTipType, onStepChange: ((Int) -> Void)? = nil) -> some View {
        switch type {
        case .map:
            self.popoverTip(TravelTips.MapTip()) { action in
                if action.id == "next" {
                    TravelTips.currentStep = 1
                    onStepChange?(1)
                }
            }
        case .itineraryTracking:
            self.popoverTip(TravelTips.ItineraryTrackingTip()) { action in
                if action.id == "finish" {
                    TravelTips.currentStep = 2
                    onStepChange?(2)
                }
            }
        case .recordingGuidance:
            // This tip is now displayed inline via TipView in TripDetailView
            // and no longer needs a popover modifier here, but we keep the case
            // to satisfy the enum switch if called elsewhere.
            EmptyView()
        }
    }
}

struct TripRowView: View {
    let trip: Trip
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text("\(trip.points.count) points")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .glassEffect(in: .rect(cornerRadius: 16.0))
    }
}

private extension Trip {
    var region: MKCoordinateRegion {
        guard !points.isEmpty else {
            // Fallback to a wider view of a sensible default if no points exist yet.
            // The grid map will try to use .userLocation if trip is active anyway.
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }
        
        let latitudes = points.map { $0.latitude }
        let longitudes = points.map { $0.longitude }
        
        let minLat = latitudes.min()!
        let maxLat = latitudes.max()!
        let minLon = longitudes.min()!
        let maxLon = longitudes.max()!
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        // Add 10% padding
        let latDelta = max(0.01, (maxLat - minLat) * 1.2)
        let lonDelta = max(0.01, (maxLon - minLon) * 1.2)
        
        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )
    }
}
