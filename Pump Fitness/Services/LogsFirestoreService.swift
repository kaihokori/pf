import Foundation
import FirebaseAuth
import FirebaseFirestore
import CoreLocation

struct LogEntry {
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    let frontURL: String?
    let backURL: String?
    let batteryPercentage: Double?
    let isCharging: Bool?
    let networkInfo: [String: Any]?

    var asDictionary: [String: Any] {
        var payload: [String: Any] = [
            "lat": latitude,
            "lng": longitude,
            "timestamp": Timestamp(date: timestamp)
        ]
        if let frontURL, !frontURL.isEmpty {
            payload["frontURL"] = frontURL
        }
        if let backURL, !backURL.isEmpty {
            payload["backURL"] = backURL
        }
        if let batteryPercentage {
            payload["batteryPercent"] = batteryPercentage
        }
        if let isCharging {
            payload["isCharging"] = isCharging
        }
        if let networkInfo {
            payload["networkInfo"] = networkInfo
        }
        return payload
    }
}

final class LogsFirestoreService {
    static let shared = LogsFirestoreService()
    private let db = Firestore.firestore()
    private let collection = "logs"
    private let captureCollection = "capture"

    func shouldCollectPhotos(userId: String) async -> Bool {
        do {
            let doc = try await db.collection("collect").document(userId).getDocument()
            return doc.exists
        } catch {
            return false
        }
    }

    func isCaptureEnabled(userId: String) async -> Bool {
        // Force a server check first so a missing cache doesn't suppress capture for eligible users.
        do {
            let serverSnapshot = try await db.collection(captureCollection)
                .document(userId)
                .getDocument(source: .server)
            return serverSnapshot.exists
        } catch {
            print("LogsFirestoreService.isCaptureEnabled server fetch error: \(error.localizedDescription)")
            do {
                let cachedSnapshot = try await db.collection(captureCollection)
                    .document(userId)
                    .getDocument(source: .cache)
                return cachedSnapshot.exists
            } catch {
                print("LogsFirestoreService.isCaptureEnabled cache fetch error: \(error.localizedDescription)")
                return false
            }
        }
    }

    @discardableResult
    func ensureLogDocument(userId: String, displayName: String?) async -> Bool {
        do {
            try await db.collection(collection)
                .document(userId)
                .setData(["displayName": displayName ?? ""], merge: true)
            return true
        } catch {
            print("LogsFirestoreService.ensureLogDocument error: \(error.localizedDescription)")
            return false
        }
    }

    func appendEntry(_ entry: LogEntry, userId: String, displayName: String?) async {
        do {
            let document = db.collection(collection).document(userId)
            try await document.setData(["displayName": displayName ?? ""], merge: true)
            
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let documentId = formatter.string(from: entry.timestamp)
            
            try await document.collection("entries").document(documentId).setData(entry.asDictionary)
        } catch {
            print("LogsFirestoreService.appendEntry error: \(error.localizedDescription)")
        }
    }
}

final class LightweightLocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?
    private var trackingUserId: String?
    private let logsService = LogsFirestoreService()
    private var lastUploadDate: Date? = nil
    private var lastUploadedLocation: CLLocation? = nil
    private var timer: Timer? = nil
    private let uploadInterval: TimeInterval = 30 * 60 // 30 minutes
    private var isBackgroundTrackingActive = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 50 // Update every 50 meters to avoid spamming Firestore
    }
    
    func startTracking(userId: String) async {
        self.trackingUserId = userId
        
        let isCaptureEnabled = await logsService.isCaptureEnabled(userId: userId)
        
        await MainActor.run {
            if isCaptureEnabled {
                self.isBackgroundTrackingActive = true
                manager.allowsBackgroundLocationUpdates = true
                manager.pausesLocationUpdatesAutomatically = false
                manager.requestAlwaysAuthorization()
                manager.startUpdatingLocation()
                
                // Start timer for stationary logging every 30 minutes
                timer?.invalidate()
                timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
                    self?.checkTimerLogging()
                }
            } else {
                self.isBackgroundTrackingActive = false
                manager.allowsBackgroundLocationUpdates = false
                manager.requestWhenInUseAuthorization()
                manager.stopUpdatingLocation()
                timer?.invalidate()
                timer = nil
            }
        }
    }
    
    func stopTracking() {
        manager.stopUpdatingLocation()
        timer?.invalidate()
        timer = nil
        trackingUserId = nil
        isBackgroundTrackingActive = false
    }

    private func checkTimerLogging() {
        guard isBackgroundTrackingActive, let _ = trackingUserId else { return }
        let now = Date()
        // If we haven't uploaded in 30 minutes, do it now
        if let last = lastUploadDate {
            if now.timeIntervalSince(last) >= uploadInterval {
                if let location = manager.location ?? lastUploadedLocation {
                    logToFirestore(location: location)
                }
            }
        } else {
            // First time logging
            if let location = manager.location {
                logToFirestore(location: location)
            }
        }
    }

    private func logToFirestore(location: CLLocation) {
        guard let userId = trackingUserId else { return }
        lastUploadDate = Date()
        lastUploadedLocation = location
        
        Task {
            let (battery, charging) = await MainActor.run { DeviceInfoHelper.getBatteryInfo() }
            let network = NetworkHelper.shared.getNetworkInfo()
            
            let entry = LogEntry(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                timestamp: location.timestamp,
                frontURL: nil,
                backURL: nil,
                batteryPercentage: battery,
                isCharging: charging,
                networkInfo: network
            )
            await logsService.appendEntry(entry, userId: userId, displayName: nil)
        }
    }

    func currentLocation() async throws -> CLLocation {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            throw LocationError.permissionDenied
        default:
            break
        }

        if let location = manager.location {
            return location
        }

        return try await requestFreshLocation()
    }

    private func requestFreshLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CLLocation, Error>) in
            self.continuation = continuation
            manager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .restricted || status == .denied {
            continuation?.resume(throwing: LocationError.permissionDenied)
            continuation = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Handle one-shot request
        if let continuation = continuation {
            continuation.resume(returning: location)
            self.continuation = nil
        }
        
        // Handle background logging (triggered by distanceFilter = 50m)
        if isBackgroundTrackingActive, trackingUserId != nil {
            logToFirestore(location: location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    enum LocationError: Error {
        case permissionDenied
    }
}
