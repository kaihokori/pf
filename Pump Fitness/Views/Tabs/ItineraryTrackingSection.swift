import SwiftUI
import CoreLocation

private struct DotYPreferenceKey: PreferenceKey {
    static var defaultValue: [CGFloat] = []
    static func reduce(value: inout [CGFloat], nextValue: () -> [CGFloat]) {
        value.append(contentsOf: nextValue())
    }

}

private struct ItineraryGroupView: View {
        let date: Date
        let items: [ItineraryEvent]

        @State private var dotYs: [CGFloat] = []

        var body: some View {
            // unique coordinate space per group so measurements don't collide
            let csName = "group_\(Int(date.timeIntervalSince1970))"

            ZStack(alignment: .topLeading) {
                // draw single connector when we have measurements
                if let minY = dotYs.min(), let maxY = dotYs.max(), maxY > minY {
                    // rectangle width centered within the 22pt left column
                    let rectWidth: CGFloat = 2
                    Rectangle()
                        .fill(Color.secondary.opacity(0.6))
                        .frame(width: rectWidth, height: maxY - minY)
                        .offset(x: (22 - rectWidth) / 2, y: minY)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(ItineraryTrackingSection.dateFormatter.string(from: date))
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    ForEach(Array(items.enumerated()), id: \.element.id) { index, event in
                        NavigationLink {
                            ItineraryDetailView(event: event)
                        } label: {
                            ItineraryTrackingSection.itineraryRow(for: event, isFirst: index == 0, isLast: index == items.count - 1, coordinateSpaceName: csName)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .coordinateSpace(name: csName)
                .onPreferenceChange(DotYPreferenceKey.self) { values in
                    // preference supplies each dot center Y; keep them for drawing
                    dotYs = values
                }
            }
        }
    }

struct ItineraryTrackingSection: View {
    var events: [ItineraryEvent] = ItineraryEvent.mockEvents

    private var groupedEvents: [(date: Date, items: [ItineraryEvent])] {
        let grouped = Dictionary(grouping: events) { Calendar.current.startOfDay(for: $0.date) }
        return grouped
            .map { (date: $0.key, items: $0.value.sorted { $0.date < $1.date }) }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if events.isEmpty {
                emptyState
            } else {
                ForEach(groupedEvents, id: \.date) { date, items in
                    ItineraryGroupView(date: date, items: items)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("No itinerary events yet", systemImage: "airplane")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
            Text("Add a new event with the plus icon to start planning your travel timeline.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 16.0))
    }

    static func itineraryRow(for event: ItineraryEvent, isFirst: Bool, isLast: Bool, coordinateSpaceName: String? = nil) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack {
                Circle()
                    .fill(event.category.color)
                    .frame(width: 12, height: 12)
                    .shadow(color: event.category.color.opacity(0.35), radius: 4, y: 2)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: DotYPreferenceKey.self, value: [geo.frame(in: coordinateSpaceName == nil ? .global : .named(coordinateSpaceName!)).midY])
                        }
                    )
            }
            .frame(width: 22)

            VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(event.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(event.timeWindowLabel)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.thinMaterial, in: .capsule)
                        .foregroundStyle(.secondary)
                }

                if let locName = event.locationName, !locName.isEmpty {
                    Text(locName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .glassEffect(in: .rect(cornerRadius: 16.0))
        }
    }

    static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEEE, d MMM"
        return df
    }()
}

struct ItineraryEvent: Identifiable, Hashable {
    var id: UUID
    var name: String
    var notes: String
    var date: Date
    var locationAdministrativeArea: String?
    var locationCountry: String?
    var locationLatitude: Double
    var locationLocality: String?
    var locationLongitude: Double
    var locationName: String?
    var locationPostcode: String?
    var locationSubThoroughfare: String?
    var locationThoroughfare: String?
    var type: String

    init(
        id: UUID = UUID(),
        name: String,
        notes: String = "",
        date: Date,
        locationAdministrativeArea: String? = nil,
        locationCountry: String? = nil,
        locationLatitude: Double = 0.0,
        locationLocality: String? = nil,
        locationLongitude: Double = 0.0,
        locationName: String? = nil,
        locationPostcode: String? = nil,
        locationSubThoroughfare: String? = nil,
        locationThoroughfare: String? = nil,
        type: String = "other"
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.date = date
        self.locationAdministrativeArea = locationAdministrativeArea
        self.locationCountry = locationCountry
        self.locationLatitude = locationLatitude
        self.locationLocality = locationLocality
        self.locationLongitude = locationLongitude
        self.locationName = locationName
        self.locationPostcode = locationPostcode
        self.locationSubThoroughfare = locationSubThoroughfare
        self.locationThoroughfare = locationThoroughfare
        self.type = type
    }

    var timeWindowLabel: String {
        ItineraryEvent.timeFormatter.string(from: date)
    }

    private static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "h:mm a"
        return df
    }()

    // MARK: - Equatable & Hashable
    static func == (lhs: ItineraryEvent, rhs: ItineraryEvent) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var category: ItineraryCategory {
        ItineraryCategory(rawValue: type) ?? .other
    }

    var coordinate: CLLocationCoordinate2D? {
        if locationLatitude == 0 && locationLongitude == 0 { return nil }
        return CLLocationCoordinate2D(latitude: locationLatitude, longitude: locationLongitude)
    }

    static var mockEvents: [ItineraryEvent] {
        let calendar = Calendar.current

        // Use explicit dates in Dec 2025 per user's request
        func dateFor(day: Int, hour: Int, minute: Int) -> Date {
            var comps = DateComponents()
            comps.year = 2025
            comps.month = 12
            comps.day = day
            comps.hour = hour
            comps.minute = minute
            return calendar.date(from: comps) ?? Date()
        }

        return [
            // 19th Dec, 2025
            ItineraryEvent(
                id: UUID(),
                name: "Car Pickup",
                notes: "Collect compact SUV from Avia Car Rental. Bring driving license and booking confirmation.",
                date: dateFor(day: 19, hour: 12, minute: 30),
                locationAdministrativeArea: "Bali",
                locationCountry: "ID",
                locationLatitude: -8.65,
                locationLocality: "Seminyak",
                locationLongitude: 115.136,
                locationName: "Avia Car Rental",
                locationPostcode: "80361",
                locationSubThoroughfare: "12",
                locationThoroughfare: "Jalan Raya Seminyak",
                type: "travel"
            ),
            ItineraryEvent(
                id: UUID(),
                name: "Check‑in",
                notes: "Early check-in requested; confirm room preference at reception.",
                date: dateFor(day: 19, hour: 14, minute: 0),
                locationAdministrativeArea: "Bali",
                locationCountry: "ID",
                locationLatitude: -8.6485,
                locationLocality: "Seminyak",
                locationLongitude: 115.1385,
                locationName: "Tuscany Boutique Hotel",
                locationPostcode: "80361",
                locationSubThoroughfare: "5",
                locationThoroughfare: "Jalan Kayu Aya",
                type: "stay"
            ),
            ItineraryEvent(
                id: UUID(),
                name: "Shopping Spree",
                notes: "Pick up a local SIM card and grab sunscreen before heading to the beach.",
                date: dateFor(day: 19, hour: 16, minute: 0),
                locationAdministrativeArea: "Bali",
                locationCountry: "ID",
                locationLatitude: -8.6520,
                locationLocality: "Seminyak",
                locationLongitude: 115.1340,
                locationName: "Seminyak Square",
                locationPostcode: "80361",
                locationSubThoroughfare: "2",
                locationThoroughfare: "Jalan Oberoi",
                type: "activity"
            ),
            ItineraryEvent(
                id: UUID(),
                name: "Lunch with Damian",
                notes: "$15 lunch special - try the pescado tacos.",
                date: dateFor(day: 19, hour: 17, minute: 30),
                locationAdministrativeArea: "Bali",
                locationCountry: "ID",
                locationLatitude: -8.6470,
                locationLocality: "Seminyak",
                locationLongitude: 115.1390,
                locationName: "La Taqueria",
                locationPostcode: "80361",
                locationSubThoroughfare: "8",
                locationThoroughfare: "Jalan Laksmana",
                type: "food"
            ),

            // 20th Dec, 2025
            ItineraryEvent(
                id: UUID(),
                name: "Morning Markets",
                notes: "Local market for breakfast and fresh fruit. Meet tour guide here.",
                date: dateFor(day: 20, hour: 9, minute: 30),
                locationAdministrativeArea: "Bali",
                locationCountry: "ID",
                locationLatitude: -8.6490,
                locationLocality: "Seminyak",
                locationLongitude: 115.1370,
                locationName: "Kayu Aya Market",
                locationPostcode: "80361",
                locationSubThoroughfare: "20",
                locationThoroughfare: "Jalan Kayu Aya",
                type: "activity"
            ),
            ItineraryEvent(
                id: UUID(),
                name: "Coffee",
                notes: "Quick coffee and meet with the day’s walking tour leader.",
                date: dateFor(day: 20, hour: 10, minute: 30),
                locationAdministrativeArea: "Bali",
                locationCountry: "ID",
                locationLatitude: -8.6510,
                locationLocality: "Seminyak",
                locationLongitude: 115.1355,
                locationName: "Vessel Cafe",
                locationPostcode: "80361",
                locationSubThoroughfare: "7",
                locationThoroughfare: "Jalan Kayu Aya",
                type: "activity"
            ),
            ItineraryEvent(
                id: UUID(),
                name: "Hot Dogs",
                notes: "Casual lunch spot - local favorite. Try the special.",
                date: dateFor(day: 20, hour: 12, minute: 30),
                locationAdministrativeArea: "Bali",
                locationCountry: "ID",
                locationLatitude: -8.6505,
                locationLocality: "Seminyak",
                locationLongitude: 115.1365,
                locationName: "Vinnie’s Hot Dogs",
                locationPostcode: "80361",
                locationSubThoroughfare: "3",
                locationThoroughfare: "Jalan Kayu Aya",
                type: "food"
            )
        ]
    }
}

enum ItineraryCategory: String, CaseIterable, Hashable {
    case activity
    case food
    case stay
    case travel
    case other

    var displayName: String {
        switch self {
        case .activity: return "Activity"
        case .food: return "Food"
        case .stay: return "Stay"
        case .travel: return "Travel"
        case .other: return "Other"
        }
    }

    var color: Color {
        switch self {
        case .activity: return Color(hex: "#4CAF6A") ?? .green
        case .food: return Color(hex: "#E39A3B") ?? .yellow
        case .stay: return Color(hex: "#D84A4A") ?? .red
        case .travel: return Color(hex: "#7A5FD1") ?? .purple
        case .other: return Color(hex: "#8E8E93") ?? .gray
        }
    }

    var symbol: String {
        switch self {
        case .activity: return "figure.play"
        case .food: return "fork.knife"
        case .stay: return "bed.double.fill"
        case .travel: return "figure.wave"
        case .other: return "aqi.medium"
        }
    }
}

#if DEBUG
struct ItineraryTrackingSection_Previews: PreviewProvider {
    static var previews: some View {
        ItineraryTrackingSection()
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
#endif
