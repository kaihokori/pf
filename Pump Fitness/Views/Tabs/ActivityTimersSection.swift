import SwiftUI

struct ActivityTimerItem: Identifiable, Equatable {
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

    private static let timeFormatter: DateFormatter = {
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

    var body: some View {
        Group {
            if timers.isEmpty {
                placeholder
            } else {
                HStack(spacing: 12) {
                    ForEach(timers.prefix(2)) { timer in
                        ActivityTimerCard(
                            accentColorOverride: accentColorOverride,
                            item: timer
                        )
                        .frame(maxWidth: .infinity)
                    }

                    if timers.count == 1 {
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
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

private struct ActivityTimerCard: View {
    var accentColorOverride: Color?
    var item: ActivityTimerItem

    private var tint: Color { accentColorOverride ?? item.color }
    private var statusTitle: String { Date() < item.startTime ? "Starts In" : "Time Left" }
    private var progress: Double { min(max(item.progress, 0), 1) }

    private func formattedTimeString(for seconds: TimeInterval) -> String {
        let totalSeconds = max(0, Int(seconds))
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
                    Text(formattedTimeString(for: item.countdownInterval))
                        .font(.system(size: 18, weight: .semibold))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)

            VStack(alignment: .center) {
                Text(item.nextLabel)
                    .font(.headline)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            Button {
                // TODO: wire start/stop behavior
            } label: {
                Text("Stop")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(.white)
                    .glassEffect(in: .rect(cornerRadius: 16.0))
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
