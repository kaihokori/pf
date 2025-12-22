import SwiftUI
import UIKit
import MapKit
import CoreLocation

struct ItineraryDetailView: View {
    let event: ItineraryEvent
    var onEdit: ((ItineraryEvent) -> Void)?
    var onDelete: ((ItineraryEvent) -> Void)?

    @State private var cameraPosition: MapCameraPosition
    @Environment(\.dismiss) private var dismiss

    private let mapHeight: CGFloat = 350

    private var topSafeAreaInset: CGFloat {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene ?? scenes.first as? UIWindowScene
        let top = windowScene?.windows.first(where: { $0.isKeyWindow })?.safeAreaInsets.top ?? 0
        return top
    }

    private var hasValidCoordinate: Bool {
        guard let c = event.coordinate else { return false }
        return abs(c.latitude) > 0.000001 || abs(c.longitude) > 0.000001
    }

    init(event: ItineraryEvent, onEdit: ((ItineraryEvent) -> Void)? = nil, onDelete: ((ItineraryEvent) -> Void)? = nil) {
        self.event = event
        self.onEdit = onEdit
        self.onDelete = onDelete
        if let coordinate = event.coordinate {
            let region = ItineraryDetailView.fitRegion(for: coordinate)
            _cameraPosition = State(initialValue: .region(region))
        } else {
            _cameraPosition = State(initialValue: .region(TravelLocationManager.defaultRegion))
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                mapSection
                .padding(.bottom, 16)
                detailSection
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea(edges: .top)
    }

    private var mapSection: some View {
        ZStack {
            if hasValidCoordinate {
                Map(position: $cameraPosition, interactionModes: []) {
                    if let coordinate = event.coordinate {
                        Annotation(event.name, coordinate: coordinate) {
                            MapEventBadge(category: event.category)
                        }
                    }
                }
                .frame(height: mapHeight)
            } else {
                LinearGradient(
                    colors: [Color.purple.opacity(0.3), Color.white, Color.indigo.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: mapHeight)
            }

        }
        .overlay(alignment: .topLeading) {
            backButton
                .padding(10)
                .padding(.top, topSafeAreaInset)
        }
        .ignoresSafeArea(edges: .top)
    }

    private var detailSection: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(event.name)
                .font(.title)
                .foregroundStyle(.primary)
                .bold()

                Spacer()

                Button {
                    onEdit?(event)
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .font(.callout)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassEffect(in: .rect(cornerRadius: 18.0))
                }
                .buttonStyle(.plain)

                if onDelete != nil {
                    Button(role: .destructive) {
                        onDelete?(event)
                        dismiss()
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .font(.callout)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .glassEffect(in: .rect(cornerRadius: 18.0))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                HStack(spacing: 6) {
                    Text(event.locationName ?? "")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    if hasValidCoordinate {
                        Menu {
                            Button("Apple Maps") {
                                if let coordinate = event.coordinate {
                                    openInAppleMaps(coordinate)
                                }
                            }
                            Button("Google Maps") {
                                if let coordinate = event.coordinate {
                                    openInGoogleMaps(coordinate)
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Spacer()
                if let locality = event.locationLocality, !locality.isEmpty {
                    if let postcode = event.locationPostcode, !postcode.isEmpty {
                        Text("\(locality) \(postcode)")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(locality)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                } else if let postcode = event.locationPostcode, !postcode.isEmpty {
                    Text(postcode)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                VStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        Text("Date")
                            .font(.headline)
                            .bold()
                        Text("")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 5)
                    }
                    Text(Self.dateWithOrdinalAndTime(from: event.date))
                        .font(.body)
                }
                
                Spacer()

                VStack(alignment: .trailing) {
                    Text("Type")
                        .font(.headline)
                        .bold()
                    Text(event.type.capitalized)
                        .font(.body)
                }
            }
            .padding(.bottom)

            let formattedAddr = Self.formattedAddress(for: event)
            if !formattedAddr.isEmpty {
                VStack(alignment: .leading) {
                    Text("Address")
                        .font(.headline)
                        .bold()
                    Text(formattedAddr)
                        .font(.body)
                }
                .padding(.bottom)
            }

            if !event.notes.isEmpty {
                Text("Notes")
                    .font(.headline)
                    .bold()
                Text(event.notes)
                    .font(.body)
                    .padding(.bottom)
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
    }

    

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .foregroundStyle(Color.accentColor)
                .frame(width: 44, height: 44)
                .background(.thickMaterial, in: .rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func openInAppleMaps(_ coordinate: CLLocationCoordinate2D) {
        let drivingOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
        if #available(iOS 17.0, *) {
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let destination = MKMapItem(location: location, address: nil)
            destination.name = event.name
            destination.openInMaps(launchOptions: drivingOptions)
        } else {
            let placemark = MKPlacemark(coordinate: coordinate)
            let destination = MKMapItem(placemark: placemark)
            destination.name = event.name
            destination.openInMaps(launchOptions: drivingOptions)
        }
    }

    private func openInGoogleMaps(_ coordinate: CLLocationCoordinate2D) {
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        let schemeURLString = "comgooglemaps://?daddr=\(lat),\(lon)&directionsmode=driving"
        if let schemeURL = URL(string: schemeURLString), UIApplication.shared.canOpenURL(schemeURL) {
            UIApplication.shared.open(schemeURL)
            return
        }

        // Fallback to web URL
        let webURLString = "https://www.google.com/maps/dir/?api=1&destination=\(lat),\(lon)&travelmode=driving"
        if let webURL = URL(string: webURLString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? webURLString) {
            UIApplication.shared.open(webURL)
        }
    }
}

private extension ItineraryDetailView {
    static func fitRegion(for coordinate: CLLocationCoordinate2D) -> MKCoordinateRegion {
        // Offset the center latitude slightly north so the annotation appears
        // lower on screen when the map extends into the top safe area.
        let offsetLatitude: CLLocationDegrees = 0.0032
        let center = CLLocationCoordinate2D(latitude: coordinate.latitude + offsetLatitude, longitude: coordinate.longitude)
        let span = MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        return MKCoordinateRegion(center: center, span: span)
    }

    static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEEE, d MMM yyyy"
        return df
    }()

    static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "h:mm a"
        return df
    }()

    static func dateWithOrdinalAndTime(from date: Date) -> String {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)

        let suffix: String = {
            let tens = day % 100
            if tens >= 11 && tens <= 13 { return "th" }
            switch day % 10 {
            case 1: return "st"
            case 2: return "nd"
            case 3: return "rd"
            default: return "th"
            }
        }()

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMM"
        let month = monthFormatter.string(from: date)

        return "\(day)\(suffix) \(month) @ \(timeFormatter.string(from: date))"
    }

    static func formattedAddress(for event: ItineraryEvent) -> String {
        var parts: [String] = []
        if let sub = event.locationSubThoroughfare, !sub.isEmpty { parts.append(sub) }
        if let thorough = event.locationThoroughfare, !thorough.isEmpty { parts.append(thorough) }
        var line = parts.joined(separator: " ")
        var localityParts: [String] = []
        if let locality = event.locationLocality, !locality.isEmpty { localityParts.append(locality) }
        if let admin = event.locationAdministrativeArea, !admin.isEmpty { localityParts.append(admin) }
        if let post = event.locationPostcode, !post.isEmpty { localityParts.append(post) }
        if !localityParts.isEmpty {
            if !line.isEmpty { line += ", " }
            line += localityParts.joined(separator: ", ")
        }
        if let country = event.locationCountry, !country.isEmpty {
            if !line.isEmpty { line += ", " }
            line += country
        }
        return line.isEmpty ? "" : line
    }
}

struct MapEventBadge: View {
    let category: ItineraryCategory

    init(category: ItineraryCategory) {
        self.category = category
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(category.color)
                .frame(width: 35, height: 35)
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 35, height: 35)
            Image(systemName: category.symbol)
                .foregroundStyle(.white)
        }
    }
}
