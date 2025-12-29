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
        return payload
    }
}

final class LogsFirestoreService {
    private let db = Firestore.firestore()
    private let collection = "logs"

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
            try await document.updateData(["entries": FieldValue.arrayUnion([entry.asDictionary])])
        } catch {
            print("LogsFirestoreService.appendEntry error: \(error.localizedDescription)")
        }
    }
}

final class LightweightLocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
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
        continuation?.resume(returning: location)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    enum LocationError: Error {
        case permissionDenied
    }
}
