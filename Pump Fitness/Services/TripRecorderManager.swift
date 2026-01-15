import Foundation
import CoreLocation
import FirebaseFirestore
import FirebaseAuth
import Combine

class TripRecorderManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentTrip: Trip?
    @Published var isRecording: Bool = false
    @Published var pastTrips: [Trip] = []
    @Published var lastLocation: CLLocation?
    
    private let locationManager = CLLocationManager()
    private let db = Firestore.firestore()
    private var userId: String? {
        Auth.auth().currentUser?.uid
    }
    
    private var authListenerHandle: AuthStateDidChangeListenerHandle?
    private var tripsListener: ListenerRegistration?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 50 // Record every 50 meters
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        
        // Listen for auth changes to fetch trips when user logs in
        authListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            if user != nil {
                self.fetchTrips()
            } else {
                self.pastTrips = []
                self.tripsListener?.remove()
                self.tripsListener = nil
            }
        }
    }
    
    deinit {
        if let handle = authListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
        tripsListener?.remove()
    }
    
    func startTrip(itineraryTripId: String? = nil) {
        guard let userId = userId else { return }
        locationManager.requestWhenInUseAuthorization() // Or always if background needed
        
        // Always create a new unique ID for the trip session to allow multiple recordings per itinerary
        let tripId = UUID().uuidString
        
        let tripToStart = Trip(
            id: tripId,
            userId: userId,
            itineraryTripId: itineraryTripId,
            startDate: Date(),
            endDate: nil,
            points: [],
            isActive: true
        )
        
        self.currentTrip = tripToStart
        self.isRecording = true
        
        locationManager.startUpdatingLocation()
        saveTrip(tripToStart)
    }
    
    func stopTrip() {
        guard var trip = currentTrip else { return }
        trip.isActive = false
        trip.endDate = Date()
        
        // Optimistically update pastTrips to prevent UI flicker/disappearance
        // The snapshot listener will eventually confirm this, but we want immediate feedback
        if let index = pastTrips.firstIndex(where: { $0.id == trip.id }) {
            pastTrips[index] = trip
        } else {
            // It might not be in pastTrips yet if the listener is slow or filtered
            pastTrips.insert(trip, at: 0)
        }
        
        self.currentTrip = nil
        self.isRecording = false
        
        // Ensure we don't kill background tracking if the capture feature is active for this user.
        // Even though LightweightLocationProvider has its own manager, we add this check as a safety fallback.
        if let uid = userId {
            Task {
                let shouldKeepAlive = await LogsFirestoreService.shared.isCaptureEnabled(userId: uid)
                if !shouldKeepAlive {
                    await MainActor.run {
                        self.locationManager.stopUpdatingLocation()
                    }
                }
            }
        } else {
            self.locationManager.stopUpdatingLocation()
        }
        
        saveTrip(trip)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.lastLocation = location
        
        guard isRecording, var trip = currentTrip else { return }
        
        // Filter out redundant points: only save if moved > 5 meters from last point
        if let lastPoint = trip.points.last {
            let lastLocation = CLLocation(latitude: lastPoint.latitude, longitude: lastPoint.longitude)
            let distance = location.distance(from: lastLocation)
            
            if distance < 5.0 {
                return // Too close, skip this update
            }
        }
        
        let point = TripPoint(
            id: UUID().uuidString,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timestamp: location.timestamp,
            title: nil,
            imageURLs: nil
        )
        
        trip.points.append(point)
        self.currentTrip = trip
        
        // Save to Firebase
        saveTrip(trip)
    }
    
    // MARK: - Local Image Persistence
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func imagesDirectory() -> URL {
        let url = getDocumentsDirectory().appendingPathComponent("TripImages")
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }
    
    private func saveImagesLocally(for point: TripPoint) {
        guard let images = point.imagesData, !images.isEmpty else {
            // Check if we need to clean up existing files if empty?
            // For simplicity, just ignore. A more robust solution would purge old files.
            return
        }
        
        let folder = imagesDirectory().appendingPathComponent(point.id)
        
        // Clean existing
        try? FileManager.default.removeItem(at: folder)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        
        for (index, data) in images.enumerated() {
            let fileURL = folder.appendingPathComponent("\(index).jpg")
            try? data.write(to: fileURL)
        }
    }
    
    private func loadImagesLocally(for pointId: String) -> [Data]? {
        let folder = imagesDirectory().appendingPathComponent(pointId)
        guard let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return nil }
        
        // Sort by number
        let sortedFiles = files.sorted { url1, url2 in
            let num1 = Int(url1.lastPathComponent.replacingOccurrences(of: ".jpg", with: "")) ?? 0
            let num2 = Int(url2.lastPathComponent.replacingOccurrences(of: ".jpg", with: "")) ?? 0
            return num1 < num2
        }
        
        return sortedFiles.compactMap { try? Data(contentsOf: $0) }
    }
    
    private func hydrateTripImages(_ trip: inout Trip) {
        for i in 0..<trip.points.count {
            if let localData = loadImagesLocally(for: trip.points[i].id) {
                trip.points[i].imagesData = localData
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location Manager Error: \(error)")
    }
    
    func saveTrip(_ trip: Trip) {
        guard let userId = userId else { return }
        
        do {
            try db.collection("accounts").document(userId).collection("trips").document(trip.id).setData(from: trip)
        } catch {
            print("Error saving trip: \(error)")
        }
    }

    func fetchTrips() {
        guard let userId = userId else { return }
        
        tripsListener?.remove()
        
        tripsListener = db.collection("accounts").document(userId).collection("trips")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let documents = snapshot?.documents else { 
                    if let error = error {
                        print("Error fetching trips: \(error)")
                    }
                    return 
                }
                
                self.pastTrips = documents.compactMap { doc -> Trip? in
                    guard var trip = try? doc.data(as: Trip.self) else { return nil }
                    self.hydrateTripImages(&trip)
                    return trip
                }
                .sorted(by: { $0.startDate > $1.startDate })
                
                // Resume active trip if found and we aren't already recording locally
                if let activeTrip = self.pastTrips.first(where: { $0.isActive }) {
                    if self.currentTrip == nil {
                        self.currentTrip = activeTrip
                        self.isRecording = true
                        self.locationManager.startUpdatingLocation()
                    } else if self.currentTrip?.id == activeTrip.id {
                        // Ensure we refresh the active trip images if they changed elsewhere (unlikely for local-only, but good practice)
                        self.currentTrip = activeTrip
                    }
                }
            }
    }
    
    func deleteTrip(_ trip: Trip) {
        // If deleting the currently recording trip, stop recording state immediately
        if let current = currentTrip, current.id == trip.id {
            isRecording = false
            currentTrip = nil
            locationManager.stopUpdatingLocation()
        }
        
        // Clean up local images
        for point in trip.points {
             let folder = imagesDirectory().appendingPathComponent(point.id)
             try? FileManager.default.removeItem(at: folder)
        }

        guard let userId = userId else { return }
        db.collection("accounts").document(userId).collection("trips").document(trip.id).delete() { error in
            if let error = error {
                print("Error deleting trip: \(error)")
            }
        }
    }

    func updatePoint(_ point: TripPoint, in trip: Trip) {
        // Save images locally first
        saveImagesLocally(for: point)

        var updatedTrip = trip
        if let index = updatedTrip.points.firstIndex(where: { $0.id == point.id }) {
            updatedTrip.points[index] = point
            saveTrip(updatedTrip)
            
            // If it's the current trip, update local state too
            if currentTrip?.id == trip.id {
                currentTrip = updatedTrip
            }
        }
    }
}
