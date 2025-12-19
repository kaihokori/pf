import SwiftUI
import MapKit
import CoreLocation
import Combine

struct MapSection: View {
    var events: [ItineraryEvent]
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
                events: annotatedEvents,
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
    let events: [ItineraryEvent]
    @ObservedObject var locationManager: TravelLocationManager
    @Binding var isPresented: Bool
    @State private var selectedEvent: ItineraryEvent?

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
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    Spacer()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedEvent) { event in
                ItineraryDetailView(event: event)
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
