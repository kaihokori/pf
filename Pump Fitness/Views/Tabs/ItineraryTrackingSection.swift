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
    let onEdit: (ItineraryEvent) -> Void
    let onDelete: (ItineraryEvent) -> Void

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
                            ItineraryDetailView(event: event, onEdit: { updated in onEdit(updated) }, onDelete: { deleted in onDelete(deleted) })
                        } label: {
                            ItineraryTrackingSection.itineraryRow(for: event, isFirst: index == 0, isLast: index == items.count - 1, coordinateSpaceName: csName)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                onEdit(event)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                onDelete(event)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
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
    var onEdit: (ItineraryEvent) -> Void = { _ in }
    var onDelete: (ItineraryEvent) -> Void = { _ in }

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
                ForEach(groupedEvents, id: \.date) { group in
                    ItineraryGroupView(date: group.date, items: group.items, onEdit: onEdit, onDelete: onDelete)
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

#if DEBUG
struct ItineraryTrackingSection_Previews: PreviewProvider {
    static var previews: some View {
        ItineraryTrackingSection()
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
#endif
