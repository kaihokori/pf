import SwiftUI
import MapKit
import CoreLocation
import Combine

struct MapSection: View {
    @Binding var events: [ItineraryEvent]
    @StateObject private var locationManager = TravelLocationManager()
    @State private var isShowingMap = false

    private var annotatedEvents: [ItineraryEvent] {
        events.filter { $0.coordinate != nil }
    }

    private func regionForEvents(_ events: [ItineraryEvent]) -> MKCoordinateRegion {
        let coords = events.compactMap { $0.coordinate }
        guard !coords.isEmpty else { return TravelLocationManager.defaultRegion }

        let lats = coords.map { $0.latitude }
        let lons = coords.map { $0.longitude }
        let minLat = lats.min() ?? coords.first!.latitude
        let maxLat = lats.max() ?? coords.first!.latitude
        let minLon = lons.min() ?? coords.first!.longitude
        let maxLon = lons.max() ?? coords.first!.longitude

        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2.0,
                                            longitude: (minLon + maxLon) / 2.0)

        // Add padding multiplier
        let latDelta = max((maxLat - minLat) * 1.4, 0.01)
        let lonDelta = max((maxLon - minLon) * 1.4, 0.01)

        let span = MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        return MKCoordinateRegion(center: center, span: span)
    }

    private var cameraBinding: Binding<MapCameraPosition> {
        Binding(
            get: { locationManager.cameraPosition },
            set: { locationManager.cameraPosition = $0 }
        )
    }

    var body: some View {
        ZStack {
            Map(position: cameraBinding) {
                ForEach(annotatedEvents) { event in
                    if let coordinate = event.coordinate {
                        Annotation(event.name, coordinate: coordinate) {
                            MapEventAnnotationView(event: event)
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .allowsHitTesting(false)
            .overlay(alignment: .topTrailing) {
                Button {
                    isShowingMap = true
                } label: {
                    Text("Tap to Expand")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(.thickMaterial, in: .rect(cornerRadius: 10))
                }
                .padding(8)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isShowingMap = true
        }
        .frame(height: 350)
        .onAppear {
            // If we have event coordinates, fit map to show them all initially
            // and ignore subsequent location updates so the camera remains
            // positioned on the annotation pins. Otherwise, center on the
            // user's location when available.
            if !annotatedEvents.isEmpty {
                let fit = regionForEvents(annotatedEvents)
                locationManager.cameraPosition = .region(fit)
                locationManager.ignoreLocationUpdates = true
                // Request authorization so the blue dot can appear; camera
                // updates will be ignored to prevent jumping.
                locationManager.requestLocation()
            } else {
                // No annotations: allow location updates to set initial camera
                // to the user's current position, and request location.
                locationManager.ignoreLocationUpdates = false
                locationManager.requestLocation()
            }
        }
        .fullScreenCover(isPresented: $isShowingMap) {
            FullScreenMapView(
                events: $events,
                locationManager: locationManager,
                isPresented: $isShowingMap
            )
        }
    }
}

private struct MapEventAnnotationView: View {
    let event: ItineraryEvent

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(event.category.color)
                .frame(width: 35, height: 35)
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 35, height: 35)
            Image(systemName: event.category.symbol)
                .foregroundStyle(.white)
        }
    }
}

private struct FullScreenMapView: View {
    @Binding var events: [ItineraryEvent]
    @ObservedObject var locationManager: TravelLocationManager
    @Binding var isPresented: Bool
    @State private var selectedEvent: ItineraryEvent?
    @State private var tappedPOI: POISelection?
    @State private var isShowingPOISheet = false
    @State private var isResolvingPOI = false
    @State private var editingEvent: ItineraryEvent?
    @State private var editorSeedDate = Date()

        private func regionForEvents(_ events: [ItineraryEvent]) -> MKCoordinateRegion {
            let coords = events.compactMap { $0.coordinate }
            guard !coords.isEmpty else { return TravelLocationManager.defaultRegion }

            let lats = coords.map { $0.latitude }
            let lons = coords.map { $0.longitude }
            let minLat = lats.min() ?? coords.first!.latitude
            let maxLat = lats.max() ?? coords.first!.latitude
            let minLon = lons.min() ?? coords.first!.longitude
            let maxLon = lons.max() ?? coords.first!.longitude

            let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2.0,
                                                longitude: (minLon + maxLon) / 2.0)

            // Add padding multiplier
            let latDelta = max((maxLat - minLat) * 1.4, 0.01)
            let lonDelta = max((maxLon - minLon) * 1.4, 0.01)

            let span = MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
            return MKCoordinateRegion(center: center, span: span)
        }

    private var filteredEvents: [ItineraryEvent] {
        events.filter { event in
            guard let coordinate = event.coordinate else { return false }
            return coordinate.latitude != 0 || coordinate.longitude != 0
        }
    }

    private var cameraBinding: Binding<MapCameraPosition> {
        Binding(
            get: { locationManager.cameraPosition },
            set: { locationManager.cameraPosition = $0 }
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MapReader { proxy in
                    Map(position: cameraBinding) {
                        ForEach(filteredEvents) { event in
                            if let coordinate = event.coordinate {
                                Annotation(event.name, coordinate: coordinate) {
                                    Button {
                                        selectedEvent = event
                                    } label: {
                                        MapEventAnnotationView(event: event)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .ignoresSafeArea()
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { gesture in
                                // Convert tap point to coordinate and resolve nearby POI
                                let tapPoint = gesture.location
                                if let coordinate = proxy.convert(tapPoint, from: .local) {
                                    resolvePOI(at: coordinate)
                                }
                            }
                    )
                }

                .onAppear {
                    // Ensure full-screen map initially frames only the annotation pins
                    // and ignores subsequent location updates so it doesn't include
                    // the user's current location unexpectedly.
                    let coords = filteredEvents.compactMap { $0.coordinate }
                    if !coords.isEmpty {
                        let region = regionForEvents(filteredEvents)
                        locationManager.ignoreLocationUpdates = true
                        locationManager.cameraPosition = .region(region)
                    } else {
                        // No annotations: center on default region but still ignore
                        // location-driven camera updates until user explicitly asks.
                        locationManager.ignoreLocationUpdates = true
                        locationManager.cameraPosition = .region(TravelLocationManager.defaultRegion)
                    }
                }

                VStack {
                    HStack {
                        Button(action: { isPresented = false }) {
                            ZStack {
                                Image(systemName: "chevron.backward")
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 45, height: 45)
                                    .font(.system(size: 20))
                            }
                            .background(.thickMaterial, in: .rect(cornerRadius: 10))
                        }

                        Spacer()

                        Button(action: {
                            // Fit map to show all annotation events (or default region)
                            let coords = filteredEvents.compactMap { $0.coordinate }
                            let region: MKCoordinateRegion
                            if coords.isEmpty {
                                region = TravelLocationManager.defaultRegion
                            } else {
                                let lats = coords.map { $0.latitude }
                                let lons = coords.map { $0.longitude }
                                let minLat = lats.min() ?? coords.first!.latitude
                                let maxLat = lats.max() ?? coords.first!.latitude
                                let minLon = lons.min() ?? coords.first!.longitude
                                let maxLon = lons.max() ?? coords.first!.longitude
                                let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2.0,
                                                                    longitude: (minLon + maxLon) / 2.0)
                                let latDelta = max((maxLat - minLat) * 1.4, 0.01)
                                let lonDelta = max((maxLon - minLon) * 1.4, 0.01)
                                region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta))
                            }
                            // Apply region to the shared location manager with animation
                            DispatchQueue.main.async {
                                locationManager.ignoreLocationUpdates = true
                                withAnimation(.easeInOut(duration: 0.6)) {
                                    locationManager.cameraPosition = .region(region)
                                }
                            }
                        }) {
                            ZStack {
                                Image(systemName: "scope")
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 45, height: 45)
                                    .font(.system(size: 18))
                            }
                            .background(.thickMaterial, in: .rect(cornerRadius: 10))
                        }

                        Button {
                            editorSeedDate = Date()
                            editingEvent = ItineraryEvent(name: "", notes: "", date: editorSeedDate)
                        } label: {
                            Text("Add")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 45, height: 45)
                                .background(.thickMaterial, in: .rect(cornerRadius: 10))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    Spacer()
                }
            }
            .sheet(isPresented: $isShowingPOISheet) {
                POIDetailSheet(selection: tappedPOI, isResolving: isResolvingPOI)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedEvent) { event in
                    ItineraryDetailView(event: event) { toEdit in
                    selectedEvent = toEdit
                    editingEvent = toEdit
                    editorSeedDate = toEdit.date
                }
            }
            .sheet(item: $editingEvent) { event in
                ItineraryEventEditorView(
                    event: event,
                    defaultDate: editorSeedDate,
                    onSave: { updated in
                        upsertEvent(updated)
                        selectedEvent = updated
                        editingEvent = nil
                    },
                    onCancel: {
                        editingEvent = nil
                    }
                )
            }
        }
    }

    private func upsertEvent(_ event: ItineraryEvent) {
        if let idx = events.firstIndex(where: { $0.id == event.id }) {
            events[idx] = event
        } else {
            events.append(event)
        }
    }

    private func resolvePOI(at coordinate: CLLocationCoordinate2D) {
        // Keep annotation buttons working: ignore taps if already loading or no coordinate
        isResolvingPOI = true
        tappedPOI = POISelection(name: "", subtitle: "", coordinate: coordinate)

        Task {
            let result = await lookupPOI(at: coordinate)
            await MainActor.run {
                let poi = result ?? POISelection(name: "Pinned Location", subtitle: formattedCoordinate(coordinate), coordinate: coordinate)

                // Prefill an ItineraryEvent with the POI information and open the editor
                let newEvent = ItineraryEvent(
                    name: "",
                    notes: "",
                    date: editorSeedDate,
                    locationAdministrativeArea: nil,
                    locationCountry: nil,
                    locationLatitude: poi.coordinate.latitude,
                    locationLocality: nil,
                    locationLongitude: poi.coordinate.longitude,
                    locationName: poi.name,
                    locationPostcode: nil,
                    locationSubThoroughfare: nil,
                    locationThoroughfare: poi.subtitle,
                    type: "activity"
                )

                editingEvent = newEvent
                editorSeedDate = Date()
                isResolvingPOI = false
                isShowingPOISheet = false
            }
        }
    }

    private func lookupPOI(at coordinate: CLLocationCoordinate2D) async -> POISelection? {
        // First try points of interest nearby
        let poiRequest = MKLocalPointsOfInterestRequest(center: coordinate, radius: 800)
        let search = MKLocalSearch(request: poiRequest)
        if let response = try? await search.start(), let poiResult = response.mapItems.first {
            let name = poiResult.name ?? "Unnamed Place"
            let subtitle: String

            if #available(iOS 26, *) {
                if let address = poiResult.address {
                    let full = address.fullAddress
                    if !full.isEmpty {
                        subtitle = full
                    } else {
                        let short = address.shortAddress ?? ""
                        subtitle = short.isEmpty ? "" : short
                    }
                } else {
                    let location = poiResult.location
                    subtitle = formattedCoordinate(location.coordinate)
                }
            } else {
                subtitle = poiResult.name ?? formattedCoordinate(coordinate)
            }
            return POISelection(name: name, subtitle: subtitle, coordinate: coordinate)
        }

        // Fallback: no POI found; use coordinate string
        return POISelection(name: "Pinned Location", subtitle: formattedCoordinate(coordinate), coordinate: coordinate)
    }

    private func formattedCoordinate(_ coordinate: CLLocationCoordinate2D) -> String {
        let lat = String(format: "%.4f", coordinate.latitude)
        let lon = String(format: "%.4f", coordinate.longitude)
        return "Lat \(lat), Lon \(lon)"
    }
}

private struct POISelection: Identifiable {
    let id = UUID()
    let name: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
}

private struct POIDetailSheet: View {
    let selection: POISelection?
    let isResolving: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isResolving {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Fetching place info...")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            } else if let selection {
                Text(selection.name)
                    .font(.headline)
                Text(selection.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("No place found")
                    .font(.headline)
            }

            Spacer()
        }
        .padding(20)
        .presentationDetents([.medium, .large])
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    // 
                }
                .disabled(isResolving || selection == nil)
            }
        }
    }
}

final class TravelLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var cameraPosition: MapCameraPosition = .region(TravelLocationManager.defaultRegion)

    /// When true, ignore location updates for the purpose of moving the map camera.
    var ignoreLocationUpdates: Bool = false

    private let manager = CLLocationManager()
    private var hasRequestedAuth = false

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestLocation() {
        if !hasRequestedAuth {
            hasRequestedAuth = true
            manager.requestWhenInUseAuthorization()
        }
        manager.requestLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if ignoreLocationUpdates { return }
        guard let location = locations.first else { return }
        let span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        let region = MKCoordinateRegion(center: location.coordinate, span: span)
        cameraPosition = .region(region)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Keep default region on failure
    }

    static let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -8.65, longitude: 115.136),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
}

struct ItineraryEventEditorView: View {
    @Environment(\.dismiss) private var dismiss

    var event: ItineraryEvent?
    var defaultDate: Date
    var onSave: (ItineraryEvent) -> Void
    var onCancel: () -> Void

    @State private var selectedCategory: ItineraryCategory
    @State private var name: String
    @State private var notes: String
    @State private var locationName: String
    @State private var address: String
    @State private var latitude: String
    @State private var longitude: String
    @State private var day: Date
    @State private var time: Date
    @State private var isShowingCalendar: Bool = false
    @State private var isShowingPlacePicker: Bool = false

    // Calendar picker state and helpers (used by the inline calendar selector)
    private let calendar = Calendar.current
    private let daysOfWeek = ["S", "M", "T", "W", "T", "F", "S"]

    @State private var currentMonth: Date = Date()
    @Namespace private var calendarAnim
    @State private var isVisible: Bool = false
    @State private var showMonthPicker: Bool = false
    @State private var showYearPicker: Bool = false

    private var title: String { event == nil ? "Add Event" : "Edit Event" }

    private var isValid: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }

        let latText = latitude.trimmingCharacters(in: .whitespacesAndNewlines)
        let lonText = longitude.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasLat = !latText.isEmpty
        let hasLon = !lonText.isEmpty

        if hasLat != hasLon { return false }
        if hasLat || hasLon {
            return Double(latText) != nil && Double(lonText) != nil
        }

        return true
    }

    init(event: ItineraryEvent?, defaultDate: Date = Date(), onSave: @escaping (ItineraryEvent) -> Void, onCancel: @escaping () -> Void) {
        self.event = event
        self.defaultDate = defaultDate
        self.onSave = onSave
        self.onCancel = onCancel

        let cal = Calendar.current
        let baseDate = cal.startOfDay(for: event?.date ?? defaultDate)
        let initialAddress = ItineraryEventEditorView.composedAddress(from: event)
        _selectedCategory = State(initialValue: event?.category ?? .activity)
        _name = State(initialValue: event?.name ?? "")
        _notes = State(initialValue: event?.notes ?? "")
        _locationName = State(initialValue: event?.locationName ?? "")
        _address = State(initialValue: initialAddress)
        _latitude = State(initialValue: event?.coordinate.map { String(format: "%.4f", $0.latitude) } ?? "")
        _longitude = State(initialValue: event?.coordinate.map { String(format: "%.4f", $0.longitude) } ?? "")
        _day = State(initialValue: baseDate)
        _time = State(initialValue: event?.date ?? defaultDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    categorySection
                    detailsSection
                    locationSection
                    notesSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                    .opacity(isValid ? 1 : 0.4)
                }
            }
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Category")
                .font(.subheadline.weight(.semibold))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 10) {
                ForEach(ItineraryCategory.allCases, id: \.self) { category in
                    let isSelected = category == selectedCategory
                    Button {
                        selectedCategory = category
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(category.color.opacity(0.6))
                                .frame(width: 14, height: 14)

                            Text(category.displayName)
                                .font(.footnote.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            (isSelected ? category.color.opacity(0.15) : Color.secondary.opacity(0.08)),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(category.color.opacity(isSelected ? 0.6 : 0.15), lineWidth: isSelected ? 1.2 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.subheadline.weight(.semibold))

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    TextField("Event name", text: $name)
                        .textInputAutocapitalization(.words)
                        .padding()
                        .textFieldStyle(.plain)
                        .background(
                          RoundedRectangle(cornerRadius: 14, style: .continuous)
                              .fill(Color.secondary.opacity(0.08))
                        )

                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.secondary.opacity(0.08))
                        )
                }

                // Date selector
                VStack(spacing: 0) {
                    // Month/Year Picker logic
                    HStack {
                        Button(action: {
                            withAnimation(.easeInOut) {
                                currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                            }
                        }) {
                            Image(systemName: "chevron.left")
                        }
                        .padding(.leading, 15)
                        Spacer()
                        Text(monthYearString(currentMonth))
                            .font(.headline)
                            .matchedGeometryEffect(id: "monthLabel", in: calendarAnim)
                        Spacer()
                        Button(action: {
                            withAnimation(.easeInOut) {
                                currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                            }
                        }) {
                            Image(systemName: "chevron.right")
                        }
                        .padding(.trailing, 15)
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 8)
                    .padding(.horizontal)
                    .padding(.top, 16)

                    if showYearPicker {
                        // Year Picker
                        let currentYear = calendar.component(.year, from: currentMonth)
                        let years = (currentYear-50...currentYear+10).map { $0 }
                        ScrollView {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                                ForEach(years, id: \.self) { year in
                                    Button(action: {
                                        var comps = calendar.dateComponents([.month, .day], from: currentMonth)
                                        comps.year = year
                                        if let newDate = calendar.date(from: comps) {
                                            currentMonth = newDate
                                        }
                                        showYearPicker = false
                                    }) {
                                        Text("\(year)")
                                            .font(.body)
                                            .frame(maxWidth: .infinity, minHeight: 32)
                                            .background(calendar.component(.year, from: currentMonth) == year ? Color.accentColor.opacity(0.2) : Color.clear)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                            .padding()
                        }
                        .frame(maxHeight: 340)
                    } else if showMonthPicker {
                        // Month Picker
                        let months = DateFormatter().monthSymbols ?? []
                        ScrollView {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                                ForEach(months.indices, id: \.self) { idx in
                                    Button(action: {
                                        var comps = calendar.dateComponents([.year, .day], from: currentMonth)
                                        comps.month = idx + 1
                                        if let newDate = calendar.date(from: comps) {
                                            currentMonth = newDate
                                        }
                                        showMonthPicker = false
                                    }) {
                                        Text(months[idx])
                                            .font(.body)
                                            .frame(maxWidth: .infinity, minHeight: 32)
                                            .background(calendar.component(.month, from: currentMonth) == idx + 1 ? Color.accentColor.opacity(0.2) : Color.clear)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                            .padding()
                        }
                        .frame(maxHeight: 340)
                    } else {
                        // Calendar Days
                        HStack {
                            ForEach(daysOfWeek, id: \.self) { dow in
                                Text(dow)
                                    .font(.caption)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                        .padding(.bottom, 12)
                        let days = daysInMonth(currentMonth)
                        let firstWeekday = calendar.component(.weekday, from: firstOfMonth(currentMonth)) - 1
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                            ForEach(0..<(days + firstWeekday), id: \.self) { i in
                                if i < firstWeekday {
                                    Color.clear.frame(height: 32)
                                } else {
                                    let dayNum = i - firstWeekday + 1
                                    let date = dateForDay(dayNum, in: currentMonth)
                                    Button(action: {
                                        withAnimation(.easeInOut) {
                                            day = date
                                            isVisible = false
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                            isShowingCalendar = false
                                        }
                                    }) {
                                        Text("\(dayNum)")
                                            .frame(maxWidth: .infinity, minHeight: 32)
                                            .background(calendar.isDate(date, inSameDayAs: day) ? Color.accentColor.opacity(0.2) : Color.clear)
                                            .clipShape(Circle())
                                    }
                                    .foregroundColor(calendar.isDate(date, inSameDayAs: day) ? .accentColor : .primary)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                )
                .padding(.vertical, 6)
            }
        }
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location")
                .font(.subheadline.weight(.semibold))

            VStack(spacing: 12) {
                Button(action: {
                    isShowingPlacePicker = true
                }) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(locationName.isEmpty ? "Place or venue" : locationName)
                                .foregroundStyle(locationName.isEmpty ? Color.secondary.opacity(0.8) : Color.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if !address.isEmpty {
                                Text(address)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        if !locationName.isEmpty {
                            Button(action: {
                                locationName = ""
                                address = ""
                                latitude = ""
                                longitude = ""
                            }) {
                                Text("Clear")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                                    .frame(minWidth: 44)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.secondary.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $isShowingPlacePicker) {
                    PlaceLookupView { mapItem, resolvedAddress in
                        if let name = mapItem.name, !name.isEmpty {
                            locationName = name
                        }
                        address = resolvedAddress

                        let coord: CLLocationCoordinate2D
                        if #available(iOS 26, *) {
                            coord = mapItem.location.coordinate
                        } else {
                            coord = mapItem.placemark.coordinate
                        }

                        latitude = String(format: "%.4f", coord.latitude)
                        longitude = String(format: "%.4f", coord.longitude)
                        isShowingPlacePicker = false
                    }
                }
            }
        }
    }

private struct PlaceLookupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    @State private var results: [MKMapItem] = []
    @FocusState private var isQueryFocused: Bool
    @State private var hasSearched: Bool = false
    var onSelect: (MKMapItem, String) -> Void

    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    TextField("Search places", text: $query)
                        .textInputAutocapitalization(.words)
                        .padding()
                        .textFieldStyle(.plain)
                        .background(
                          RoundedRectangle(cornerRadius: 14, style: .continuous)
                              .fill(Color.secondary.opacity(0.08))
                        )
                        .focused($isQueryFocused)
                        .submitLabel(.search)
                        .onSubmit {
                            Task { await performSearch() }
                        }

                    Button(action: {
                        Task { await performSearch() }
                    }) {
                        Image(systemName: "magnifyingglass")
                            .font(.title2.weight(.semibold))
                            .frame(minWidth: 64, minHeight: 44)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.secondary.opacity(0.08))
                            )
                    }
                    .buttonStyle(.plain)
                }
                .onAppear {
                    DispatchQueue.main.async { isQueryFocused = true }
                }
                .padding()
                .onChange(of: query) {
                    hasSearched = false
                    results = []
                }

                List {
                    // Custom top result: allow adding the typed name only
                    if hasSearched && !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button(action: {
                            // Create a map item with only the name (no coordinate)
                            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
                            if #available(iOS 26, *) {
                                let location = CLLocation(latitude: 0, longitude: 0)
                                let item = MKMapItem(location: location, address: nil)
                                item.name = trimmed
                                onSelect(item, "")
                            } else {
                                let coord = CLLocationCoordinate2D(latitude: 0, longitude: 0)
                                let placemark = MKPlacemark(coordinate: coord)
                                let item = MKMapItem(placemark: placemark)
                                item.name = trimmed
                                onSelect(item, "")
                            }
                            dismiss()
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "mappin")
                                    .frame(width: 20, height: 20)
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(Color.accentColor)
                                    .clipShape(Circle())

                                VStack(alignment: .leading) {
                                    Text("Can't find what you're looking for?")
                                        .font(.body)
                                    Text("Tap to add the name only")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }

                    ForEach(results.indices, id: \.self) { idx in
                        let item = results[idx]
                        Button(action: {
                            onSelect(item, subtitle(for: item))
                            dismiss()
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "mappin")
                                    .frame(width: 20, height: 20)
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(Color.accentColor)
                                    .clipShape(Circle())

                                VStack(alignment: .leading) {
                                    Text(item.name ?? "Unnamed Place")
                                        .font(.body)
                                    Text(subtitle(for: item))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
            .navigationTitle("Find a place")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func performSearch() async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            results = []
            return
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        // Leave region nil to search broadly; could be improved by passing a region

        let search = MKLocalSearch(request: request)
        do {
            let resp = try await search.start()
            results = resp.mapItems
            hasSearched = true
        } catch {
            results = []
            hasSearched = true
        }
    }

    private func formattedCoordinate(_ coordinate: CLLocationCoordinate2D) -> String {
        String(format: "Lat %.4f, Lon %.4f", coordinate.latitude, coordinate.longitude)
    }
    
    private func subtitle(for item: MKMapItem) -> String {
        if #available(iOS 26, *) {
            if let address = item.address {
                let full = address.fullAddress
                if !full.isEmpty { return full }

                let short = address.shortAddress ?? ""
                if !short.isEmpty { return short }
            }
            let loc = item.location
            return formattedCoordinate(loc.coordinate)
        } else {
            return item.placemark.title ?? item.name ?? ""
        }
    }
}

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.subheadline.weight(.semibold))

            ZStack(alignment: .topLeading) {
                TextEditor(text: $notes)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
                    .padding(16)

                if notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Add any reminders or details")
                        .foregroundStyle(.secondary.opacity(0.6))
                        .padding(.leading, 22)
                        .padding(.top, 23)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
            )
        }
    }

    private func save() {
        guard isValid else { return }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLocation = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let latValue = Double(latitude.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let lonValue = Double(longitude.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let finalDate = combinedDate(day: day, time: time)

        var updated = event ?? ItineraryEvent(
            name: trimmedName,
            notes: notes,
            date: finalDate,
            locationLatitude: latValue,
            locationLocality: nil,
            locationLongitude: lonValue,
            locationName: trimmedLocation,
            locationThoroughfare: address.isEmpty ? nil : address,
            type: selectedCategory.rawValue
        )

        updated.name = trimmedName
        updated.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.date = finalDate
        updated.locationName = trimmedLocation
        updated.locationLatitude = latValue
        updated.locationLongitude = lonValue
        updated.locationThoroughfare = address.isEmpty ? nil : address
        updated.type = selectedCategory.rawValue

        onSave(updated)
        dismiss()
    }

    private func formattedDay(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        return fmt.string(from: date)
    }

    private func combinedDate(day: Date, time: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute, .second], from: time)
        return cal.date(bySettingHour: comps.hour ?? 0, minute: comps.minute ?? 0, second: comps.second ?? 0, of: day) ?? day
    }

    private func monthYearString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func firstOfMonth(_ date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    private func daysInMonth(_ date: Date) -> Int {
        calendar.range(of: .day, in: .month, for: date)?.count ?? 30
    }

    private func dateForDay(_ day: Int, in month: Date) -> Date {
        var comps = calendar.dateComponents([.year, .month], from: month)
        comps.day = day
        return calendar.date(from: comps) ?? month
    }

    private static func composedAddress(from event: ItineraryEvent?) -> String {
        guard let event else { return "" }
        let parts = [
            event.locationThoroughfare,
            event.locationSubThoroughfare,
            event.locationLocality,
            event.locationAdministrativeArea,
            event.locationPostcode,
            event.locationCountry
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

        return parts.joined(separator: ", ")
    }
}
