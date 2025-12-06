import SwiftUI
import Combine

// Models
struct StatItem: Identifiable, Equatable {
    let id: UUID
    var name: String
    var isTimeBased: Bool
    var previousValue: String
    var currentValue: String

    init(id: UUID = UUID(), name: String, isTimeBased: Bool = false, previousValue: String = "", currentValue: String = "") {
        self.id = id
        self.name = name
        self.isTimeBased = isTimeBased
        self.previousValue = previousValue
        self.currentValue = currentValue
    }
}

struct Sport: Identifiable {
    let id: UUID
    var name: String
    var items: [StatItem]

    init(id: UUID = UUID(), name: String, items: [StatItem] = []) {
        self.id = id
        self.name = name
        self.items = items
    }
}

// ViewModel
final class SportsViewModel: ObservableObject {
    @Published var sports: [Sport] = []

    // Stopwatch state
    private var startDates: [UUID: Date] = [:]
    private var initialSeconds: [UUID: Int] = [:]
    @Published var updatingFromTimer: Bool = false

    // Timer publisher
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    func addSport(name: String) {
        let s = Sport(name: name)
        sports.append(s)
    }

    func addItem(to sportId: UUID, item: StatItem) {
        guard let idx = sports.firstIndex(where: { $0.id == sportId }) else { return }
        sports[idx].items.append(item)
    }

    func updateItem(_ item: StatItem, in sportId: UUID) {
        guard let sIdx = sports.firstIndex(where: { $0.id == sportId }) else { return }
        guard let iIdx = sports[sIdx].items.firstIndex(where: { $0.id == item.id }) else { return }
        sports[sIdx].items[iIdx] = item
    }

    func removeItem(_ itemId: UUID, in sportId: UUID) {
        guard let sIdx = sports.firstIndex(where: { $0.id == sportId }) else { return }
        sports[sIdx].items.removeAll { $0.id == itemId }
    }

    // Stopwatch control
    func startStopwatch(for itemId: UUID, sportId: UUID) {
        guard startDates[itemId] == nil else { return }
        // parse current value to seconds
        let secs = Self.parseTimeStringToSeconds(findItem(itemId, in: sportId)?.currentValue ?? "")
        initialSeconds[itemId] = secs
        startDates[itemId] = Date()
    }

    func stopStopwatch(for itemId: UUID) {
        startDates[itemId] = nil
        initialSeconds[itemId] = nil
    }

    func isRunning(itemId: UUID) -> Bool {
        return startDates[itemId] != nil
    }

    func tick() {
        guard !startDates.isEmpty else { return }
        updatingFromTimer = true
        let now = Date()
        for (itemId, start) in startDates {
            guard let initSec = initialSeconds[itemId] else { continue }
            let elapsed = Int(now.timeIntervalSince(start)) + initSec
            // update item value in sports array
            updateCurrentValue(for: itemId, to: Self.formatSecondsToTime(elapsed))
        }
        updatingFromTimer = false
    }

    func findItem(_ itemId: UUID, in sportId: UUID) -> StatItem? {
        guard let sIdx = sports.firstIndex(where: { $0.id == sportId }) else { return nil }
        return sports[sIdx].items.first(where: { $0.id == itemId })
    }

    private func updateCurrentValue(for itemId: UUID, to newValue: String) {
        for sIdx in sports.indices {
            if let iIdx = sports[sIdx].items.firstIndex(where: { $0.id == itemId }) {
                sports[sIdx].items[iIdx].currentValue = newValue
                return
            }
        }
    }

    static func parseTimeStringToSeconds(_ s: String) -> Int {
        // Accept formats: H:mm:ss, mm:ss, ss, or numeric
        let parts = s.split(separator: ":").map { String($0) }
        if parts.count == 3, let h = Int(parts[0]), let m = Int(parts[1]), let sec = Int(parts[2]) {
            return h * 3600 + m * 60 + sec
        } else if parts.count == 2, let m = Int(parts[0]), let sec = Int(parts[1]) {
            return m * 60 + sec
        } else if let v = Int(s.trimmingCharacters(in: .whitespaces)) {
            return v
        }
        return 0
    }

    static func formatSecondsToTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%d:%02d", m, s)
        }
    }
}

// MARK: - View
struct SportsTrackingSection: View {
    @StateObject private var vm = SportsViewModel()

    @State private var showAddSport = false
    @State private var addSportName: String = ""

    @State private var addingToSport: Sport? = nil
    @State private var newItemName: String = ""
    @State private var newItemIsTime: Bool = false
    @State private var newItemPrevious: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sports Tracking")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    showAddSport = true
                } label: {
                    Image(systemName: "plus")
                        .font(.headline)
                }
                .buttonStyle(.plain)
            }

            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(vm.sports) { sport in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(sport.name)
                                    .font(.headline)
                                Spacer()
                                                Button {
                                                    addingToSport = sport
                                                } label: {
                                    Image(systemName: "plus.circle")
                                }
                                .buttonStyle(.plain)
                            }

                            VStack(spacing: 8) {
                                ForEach(sport.items) { item in
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.name)
                                                .font(.subheadline.weight(.semibold))
                                            Text("Previous: \(item.previousValue)")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        // editable current value
                                        TextField("Value", text: binding(for: item, in: sport))
                                            .multilineTextAlignment(.trailing)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: 110)
                                            .onChange(of: binding(for: item, in: sport).wrappedValue) {
                                                // stop stopwatch when user edits manually
                                                if !vm.updatingFromTimer {
                                                    vm.stopStopwatch(for: item.id)
                                                }
                                            }

                                        if item.isTimeBased {
                                            Button {
                                                if vm.isRunning(itemId: item.id) {
                                                    vm.stopStopwatch(for: item.id)
                                                } else {
                                                    vm.startStopwatch(for: item.id, sportId: sport.id)
                                                }
                                            } label: {
                                                Image(systemName: vm.isRunning(itemId: item.id) ? "stop.fill" : "arrowtriangle.right.circle")
                                                    .font(.title3)
                                                    .foregroundStyle(vm.isRunning(itemId: item.id) ? .red : .primary)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .glassEffect(in: .rect(cornerRadius: 12.0))
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .onReceive(vm.timer) { _ in
            vm.tick()
        }
        .sheet(isPresented: $showAddSport) {
            NavigationStack {
                Form {
                    Section("Sport") {
                        TextField("Name", text: $addSportName)
                    }
                }
                .navigationTitle("New Sport")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            if !addSportName.trimmingCharacters(in: .whitespaces).isEmpty {
                                vm.addSport(name: addSportName.trimmingCharacters(in: .whitespaces))
                                addSportName = ""
                                showAddSport = false
                            }
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showAddSport = false }
                    }
                }
            }
        }
        .sheet(item: $addingToSport) { sport in
            NavigationStack {
                Form {
                    Section("New Item") {
                        TextField("Name", text: $newItemName)
                        Toggle("Time-based (stopwatch)", isOn: $newItemIsTime)
                        TextField("Previous value", text: $newItemPrevious)
                    }
                }
                .navigationTitle("Add Item")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            guard !newItemName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            let item = StatItem(name: newItemName.trimmingCharacters(in: .whitespaces), isTimeBased: newItemIsTime, previousValue: newItemPrevious, currentValue: newItemIsTime ? "0:00" : "")
                            vm.addItem(to: sport.id, item: item)
                            newItemName = ""
                            newItemPrevious = ""
                            newItemIsTime = false
                            addingToSport = nil
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { addingToSport = nil }
                    }
                }
            }
        }
    }

    private func binding(for item: StatItem, in sport: Sport) -> Binding<String> {
        Binding<String>(
            get: {
                vm.findItem(item.id, in: sport.id)?.currentValue ?? ""
            },
            set: { new in
                var updated = item
                updated.currentValue = new
                vm.updateItem(updated, in: sport.id)
            }
        )
    }
}

#if DEBUG
struct SportsTrackingSection_Previews: PreviewProvider {
    static var previews: some View {
        SportsTrackingSection()
            .previewLayout(.sizeThatFits)
    }
}
#endif
