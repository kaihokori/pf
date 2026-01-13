import Foundation
import CoreLocation

struct Trip: Identifiable, Codable, Hashable, Equatable {
    var id: String
    var userId: String
    var itineraryTripId: String?
    var name: String?
    var startDate: Date
    var endDate: Date?
    var points: [TripPoint]
    var isActive: Bool
    
    var title: String {
        if let name = name, !name.isEmpty {
            return name
        }
        
        let day = Calendar.current.component(.day, from: startDate)
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .ordinal
        let daySuffix = numberFormatter.string(from: NSNumber(value: day)) ?? "\(day)"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM, yyyy"
        
        return "\(daySuffix) \(dateFormatter.string(from: startDate))"
    }

    func displayTitle(in trips: [Trip]) -> String {
        return title
    }
}

struct TripPoint: Identifiable, Codable, Hashable, Equatable {
    var id: String
    var latitude: Double
    var longitude: Double
    var timestamp: Date
    var title: String?
    var imageURLs: [String]?
    var imagesData: [Data]? = nil
    
    enum CodingKeys: String, CodingKey {
        case id, latitude, longitude, timestamp, title, imageURLs
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
