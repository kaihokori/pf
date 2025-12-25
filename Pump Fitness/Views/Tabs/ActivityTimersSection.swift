import SwiftUI
import Combine
import FirebaseFirestore

struct ActivityTimerItem: Identifiable, Equatable, Codable {
    let id: String
    var name: String
    var startTime: Date
    var durationMinutes: Int
    var colorHex: String

    init(id: String = UUID().uuidString, name: String, startTime: Date, durationMinutes: Int, colorHex: String = "#4CAF6A") {
        self.id = id
        self.name = name
        self.startTime = startTime
        self.durationMinutes = durationMinutes
        self.colorHex = colorHex
    }

    init?(dictionary: [String: Any]) {
        guard let name = dictionary["name"] as? String else { return nil }
        let id = dictionary["id"] as? String ?? UUID().uuidString
        let duration = (dictionary["durationMinutes"] as? NSNumber)?.intValue ?? dictionary["durationMinutes"] as? Int ?? 0
        let colorHex = dictionary["colorHex"] as? String ?? "#4CAF6A"

        let rawDate = dictionary["startTime"] as? Date
        let tsDate = (dictionary["startTime"] as? Timestamp)?.dateValue()
        let start = rawDate ?? tsDate ?? Date()

        self.init(id: id, name: name, startTime: start, durationMinutes: duration, colorHex: colorHex)
    }

    var asDictionary: [String: Any] {
        [
            "id": id,
            "name": name,
            "startTime": startTime,
            "durationMinutes": durationMinutes,
            "colorHex": colorHex
        ]
    }

    var color: Color { Color(hex: colorHex) ?? .accentColor }

    var endTime: Date {
        Calendar.current.date(byAdding: .minute, value: durationMinutes, to: startTime) ?? startTime
    }

    var progress: Double {
        let now = Date()
        let total = endTime.timeIntervalSince(startTime)
        guard total > 0 else { return 0 }
        if now <= startTime { return 0 }
        if now >= endTime { return 1 }
        return now.timeIntervalSince(startTime) / total
    }

    var countdownInterval: TimeInterval {
        let now = Date()
        if now < startTime {
            return max(0, startTime.timeIntervalSince(now))
        }
        return max(0, endTime.timeIntervalSince(now))
    }

    var timeLeftLabel: String {
        ActivityTimerItem.durationFormatter.string(from: countdownInterval) ?? "0m"
    }

    var nextLabel: String {
        let formatter = ActivityTimerItem.timeFormatter
        return Date() < startTime ? "Starts \(formatter.string(from: startTime))" : "Ends \(formatter.string(from: endTime))"
    }

    static func startDate(hour: Int, minute: Int) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = hour
        comps.minute = minute
        return Calendar.current.date(from: comps) ?? Date()
    }

    static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "h:mm a"
        return df
    }()

    private static let durationFormatter: DateComponentsFormatter = {
        let df = DateComponentsFormatter()
        df.allowedUnits = [.hour, .minute]
        df.unitsStyle = .abbreviated
        df.zeroFormattingBehavior = [.pad]
        return df
    }()

    static let defaultTimers: [ActivityTimerItem] = [
        ActivityTimerItem(
            name: "Workout",
            startTime: Date(),
            durationMinutes: 60,
            colorHex: "#E39A3B"
        ),
        ActivityTimerItem(
            name: "Evening Walk",
            startTime: Date(),
            durationMinutes: 45,
            colorHex: "#4FB6C6"
        )
    ]
}

// Two-column activity timers section styled like the FastingTimerCard
struct ActivityTimersSection: View {
    var accentColorOverride: Color?
    var timers: [ActivityTimerItem]

    @AppStorage("activityTimers.runStates.json") private var storedRunStates: String = ""
    @AppStorage("alerts.activityTimersEnabled") private var activityTimersAlertsEnabled: Bool = false
    @State private var runStates: [String: Date] = [:]
    @State private var now: Date = Date()

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let columns: [GridItem] = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var renderedTimers: [RenderedTimer] {
        timers.map { timer in
            let duration = max(1, Double(timer.durationMinutes * 60))
            let endDate = runStates[timer.id]
            let remaining = endDate.map { max(0, $0.timeIntervalSince(now)) } ?? duration
            let isRunning = endDate != nil && remaining > 0
            let progress = 1 - min(1, remaining / duration)
            let nextLabel: String = {
                let fmt = ActivityTimerItem.timeFormatter
                if isRunning, let endDate {
                    return "Ends \(fmt.string(from: endDate))"
                }
                return "Duration \(timer.durationMinutes)m"
            }()

            return RenderedTimer(
                item: timer,
                remaining: remaining,
                isRunning: isRunning,
                progress: progress,
                nextLabel: nextLabel
            )
        }
    }

    private func toggleTimer(_ item: ActivityTimerItem) {
        if let endDate = runStates[item.id], endDate > now {
            runStates[item.id] = nil
            NotificationsHelper.removeActivityTimerNotification(id: item.id)
        } else {
            let end = Date().addingTimeInterval(Double(item.durationMinutes * 60))
            runStates[item.id] = end
            if activityTimersAlertsEnabled {
                NotificationsHelper.scheduleActivityTimerNotification(id: item.id, name: item.name, endDate: end)
            }
        }
        persistRunStates()
    }

    private func restoreRunStates() {
        guard !storedRunStates.isEmpty, let data = storedRunStates.data(using: .utf8) else { return }
        if let decoded = try? JSONDecoder().decode([String: Double].self, from: data) {
            let mapped = decoded.compactMapValues { epoch -> Date? in
                let date = Date(timeIntervalSince1970: epoch)
                return date > Date() ? date : nil
            }
            runStates = mapped
        }
        trimRunStatesToCurrentTimers()
    }

    private func persistRunStates() {
        let epochs = runStates.mapValues { $0.timeIntervalSince1970 }
        if let data = try? JSONEncoder().encode(epochs), let json = String(data: data, encoding: .utf8) {
            storedRunStates = json
        }
    }

    private func removeExpiredTimers() {
        let now = Date()
        let beforeCount = runStates.count
        runStates = runStates.filter { _, end in end > now }
        if runStates.count != beforeCount { persistRunStates() }
    }

    private func trimRunStatesToCurrentTimers() {
        let validIds = Set(timers.map { $0.id })
        let filtered = runStates.filter { validIds.contains($0.key) }
        if filtered.count != runStates.count {
            runStates = filtered
            persistRunStates()
        }
    }

    var body: some View {
        Group {
            if timers.isEmpty {
                placeholder
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(renderedTimers) { timer in
                        ActivityTimerCard(
                            accentColorOverride: accentColorOverride,
                            item: timer.item,
                            remaining: timer.remaining,
                            isRunning: timer.isRunning,
                            progress: timer.progress,
                            nextLabel: timer.nextLabel,
                            onToggle: { toggleTimer(timer.item) }
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .onAppear(perform: restoreRunStates)
        .onChange(of: timers) { _, _ in trimRunStatesToCurrentTimers() }
        .onReceive(ticker) { value in
            now = value
            removeExpiredTimers()
        }
        .onChange(of: activityTimersAlertsEnabled) { _, enabled in
            if enabled {
                for (id, endDate) in runStates {
                    if endDate > now, let timer = timers.first(where: { $0.id == id }) {
                        NotificationsHelper.scheduleActivityTimerNotification(id: id, name: timer.name, endDate: endDate)
                    }
                }
            } else {
                for (id, _) in runStates {
                    NotificationsHelper.removeActivityTimerNotification(id: id)
                }
            }
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(.secondary.opacity(0.18), lineWidth: 1)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
            )
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "timer")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Add an activity timer")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("Use the Edit button to configure timers.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            )
    }
}

private struct RenderedTimer: Identifiable, Equatable {
    let id: String
    var item: ActivityTimerItem
    var remaining: TimeInterval
    var isRunning: Bool
    var progress: Double
    var nextLabel: String

    init(item: ActivityTimerItem, remaining: TimeInterval, isRunning: Bool, progress: Double, nextLabel: String) {
        self.id = item.id
        self.item = item
        self.remaining = remaining
        self.isRunning = isRunning
        self.progress = progress
        self.nextLabel = nextLabel
    }
}

private struct ActivityTimerCard: View {
    var accentColorOverride: Color?
    var item: ActivityTimerItem
    var remaining: TimeInterval
    var isRunning: Bool
    var progress: Double
    var nextLabel: String
    var onToggle: () -> Void

    private var tint: Color { accentColorOverride ?? item.color }
    private var statusTitle: String { isRunning ? "Time Left" : "Ready" }
    private var buttonTitle: String { isRunning ? "Stop" : "Start" }

    private func formattedTimeString(for seconds: TimeInterval) -> String {
        let totalSeconds = max(0, Int(seconds.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        return String(format: "%02dh %02dm", hours, minutes)
    }

    var body: some View {
        VStack(alignment: .center, spacing: 14) {
            Text(item.name)
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            ZStack {
                Circle()
                    .stroke(tint.opacity(0.12), lineWidth: 10)
                    .frame(width: 120, height: 120)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(tint, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 120, height: 120)
                VStack(spacing: 4) {
                    Text(statusTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text(formattedTimeString(for: remaining))
                        .font(.system(size: 18, weight: .semibold))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)

            VStack(alignment: .center) {
                Text(nextLabel)
                    .font(.headline)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            Button(action: onToggle) {
                Text(buttonTitle)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(.white)
                    .glassEffect(.regular.tint(tint), in: .rect(cornerRadius: 16.0))
            }
        }
        .padding(20)
        .glassEffect(in: .rect(cornerRadius: 16.0))
    }
}

#if DEBUG
struct ActivityTimersSection_Previews: PreviewProvider {
    static var previews: some View {
        ActivityTimersSection(accentColorOverride: .orange, timers: ActivityTimerItem.defaultTimers)
            .previewLayout(.sizeThatFits)
    }
}
#endif
