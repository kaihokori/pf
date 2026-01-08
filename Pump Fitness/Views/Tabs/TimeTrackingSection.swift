import SwiftUI
import Combine
import UserNotifications
import TipKit

struct TimeTrackingConfig: Equatable, Codable {
    var stopwatchName: String
    var stopwatchTargetMinutes: Int
    var timerName: String
    var timerDurationMinutes: Int
    var stopwatchColorHex: String = "#E39A3B"
    var timerColorHex: String = "#4FB6C6"

    static let defaultConfig = TimeTrackingConfig(
        stopwatchName: "Stopwatch",
        stopwatchTargetMinutes: 45,
        timerName: "Countdown",
        timerDurationMinutes: 25,
        stopwatchColorHex: "#E39A3B",
        timerColorHex: "#4FB6C6"
    )
}

struct TimeTrackingSection: View {
    var accentColorOverride: Color?
    @Binding var config: TimeTrackingConfig
    @AppStorage("timetracking.stopwatchStart") private var storedStopwatchStart: Double = 0
    @AppStorage("timetracking.stopwatchAccum") private var storedStopwatchAccum: Double = 0
    @AppStorage("timetracking.timerEnd") private var storedTimerEnd: Double = 0
    @AppStorage("alerts.timeTrackingEnabled") private var timeTrackingAlertsEnabled: Bool = true

    @State private var stopwatchStart: Date?
    @State private var stopwatchAccumulated: TimeInterval = 0
    @State private var timerEndDate: Date?
    @State private var now = Date()
    @State private var hasRestoredState = false

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var tint: Color { accentColorOverride ?? .accentColor }
    private var stopwatchTint: Color { Color(hex: config.stopwatchColorHex) ?? tint }
    private var timerTint: Color { Color(hex: config.timerColorHex) ?? tint }

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    private var baseTint: Color { accentColorOverride ?? .accentColor }
    private var effectiveTint: Color {
        if themeManager.selectedTheme == .multiColour { return baseTint }
        return themeManager.selectedTheme.accent(for: colorScheme)
    }

    private var effectiveStopwatchTint: Color {
        if themeManager.selectedTheme == .multiColour {
            return Color(hex: config.stopwatchColorHex) ?? baseTint
        }
        return themeManager.selectedTheme.accent(for: colorScheme)
    }

    private var effectiveTimerTint: Color {
        if themeManager.selectedTheme == .multiColour {
            return Color(hex: config.timerColorHex) ?? baseTint
        }
        return themeManager.selectedTheme.accent(for: colorScheme)
    }

    private var stopwatchTargetSeconds: Double {
        max(1, Double(config.stopwatchTargetMinutes * 60))
    }

    private var stopwatchElapsed: TimeInterval {
        let runningTime = stopwatchStart.map { max(0, now.timeIntervalSince($0)) } ?? 0
        return stopwatchAccumulated + runningTime
    }

    private var stopwatchProgress: Double {
        min(1, stopwatchElapsed / stopwatchTargetSeconds)
    }

    private var timerTotalSeconds: Double {
        max(1, Double(config.timerDurationMinutes * 60))
    }

    private var timerRemaining: TimeInterval {
        guard let end = timerEndDate else { return timerTotalSeconds }
        return max(0, end.timeIntervalSince(now))
    }

    private var timerProgress: Double {
        1 - min(1, timerRemaining / timerTotalSeconds)
    }

    private var timerIsRunning: Bool {
        timerEndDate != nil && timerRemaining > 0
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                TimeTrackingCard(
                    title: config.stopwatchName,
                    statusTitle: stopwatchStart == nil ? "Not Started" : "Started",
                    timeLabel: formatHMS(stopwatchElapsed),
                    nextLabel: stopwatchStart.map { "Started \(timeString(from: $0))" } ?? "",
                    progress: stopwatchProgress,
                    tint: effectiveStopwatchTint,
                    primaryButtonTitle: stopwatchStart == nil ? "Start" : "Pause",
                    primaryButtonAction: toggleStopwatch,
                    secondaryButtonTitle: "Reset",
                    secondaryButtonAction: resetStopwatch,
                    statusEmphasis: "Time Passed",
                    showSecondaryButton: stopwatchStart == nil
                )

                TimeTrackingCard(
                    title: config.timerName,
                    statusTitle: timerIsRunning ? "Time Left" : "Ready",
                    timeLabel: formatMMSS(timerRemaining),
                    nextLabel: timerIsRunning ? "Ends \(timeString(from: timerEndDate ?? now))" : "",
                    progress: timerProgress,
                    tint: effectiveTimerTint,
                    primaryButtonTitle: timerIsRunning ? "Stop" : "Start",
                    primaryButtonAction: toggleTimer,
                    secondaryButtonTitle: "Reset",
                    secondaryButtonAction: resetTimer,
                    statusEmphasis: nil,
                    showSecondaryButton: !timerIsRunning
                )
            }
        }
        .padding(.vertical, 12)
        .onAppear(perform: restorePersistedTimeTracking)
        .onReceive(ticker) { value in
            now = value
            if timerEndDate != nil && timerRemaining <= 0 {
                timerEndDate = nil
                storedTimerEnd = 0
            }
        }
        .onChange(of: timeTrackingAlertsEnabled) { _, enabled in
            if enabled {
                // Schedule if running
                if let start = stopwatchStart {
                    let remaining = stopwatchTargetSeconds - (stopwatchAccumulated + now.timeIntervalSince(start))
                    if remaining > 0 {
                        let finishDate = now.addingTimeInterval(remaining)
                        NotificationsHelper.scheduleTimeTrackingNotification(
                            id: "stopwatch",
                            title: "\(config.stopwatchName) Target Reached",
                            body: "You've reached your target of \(config.stopwatchTargetMinutes) minutes!",
                            endDate: finishDate
                        )
                    }
                }
                if let end = timerEndDate, end > now {
                    NotificationsHelper.scheduleTimeTrackingNotification(
                        id: "timer",
                        title: "\(config.timerName) Finished",
                        body: "Your \(config.timerDurationMinutes) minute timer is up!",
                        endDate: end
                    )
                }
            } else {
                NotificationsHelper.removeTimeTrackingNotification(id: "stopwatch")
                NotificationsHelper.removeTimeTrackingNotification(id: "timer")
            }
        }
    }

    private func toggleStopwatch() {
        if let start = stopwatchStart {
            stopwatchAccumulated += max(0, now.timeIntervalSince(start))
            stopwatchStart = nil
            storedStopwatchStart = 0
            storedStopwatchAccum = stopwatchAccumulated
            NotificationsHelper.removeTimeTrackingNotification(id: "stopwatch")
        } else {
            stopwatchStart = now
            storedStopwatchStart = now.timeIntervalSince1970
            
            if timeTrackingAlertsEnabled {
                let remaining = stopwatchTargetSeconds - stopwatchAccumulated
                if remaining > 0 {
                    let finishDate = now.addingTimeInterval(remaining)
                    NotificationsHelper.scheduleTimeTrackingNotification(
                        id: "stopwatch",
                        title: "\(config.stopwatchName) Target Reached",
                        body: "You've reached your target of \(config.stopwatchTargetMinutes) minutes!",
                        endDate: finishDate
                    )
                }
            }
        }
    }

    private func resetStopwatch() {
        stopwatchStart = nil
        stopwatchAccumulated = 0
        storedStopwatchStart = 0
        storedStopwatchAccum = 0
        NotificationsHelper.removeTimeTrackingNotification(id: "stopwatch")
    }

    private func toggleTimer() {
        if timerIsRunning {
            timerEndDate = nil
            storedTimerEnd = 0
            NotificationsHelper.removeTimeTrackingNotification(id: "timer")
        } else {
            timerEndDate = now.addingTimeInterval(timerTotalSeconds)
            storedTimerEnd = timerEndDate?.timeIntervalSince1970 ?? 0
            
            if timeTrackingAlertsEnabled, let end = timerEndDate {
                NotificationsHelper.scheduleTimeTrackingNotification(
                    id: "timer",
                    title: "\(config.timerName) Finished",
                    body: "Your \(config.timerDurationMinutes) minute timer is up!",
                    endDate: end
                )
            }
        }
    }

    private func resetTimer() {
        timerEndDate = nil
        storedTimerEnd = 0
        NotificationsHelper.removeTimeTrackingNotification(id: "timer")
    }

    private func restorePersistedTimeTracking() {
        guard !hasRestoredState else { return }
        hasRestoredState = true

        if storedStopwatchAccum > 0 {
            stopwatchAccumulated = storedStopwatchAccum
        }
        if storedStopwatchStart > 0 {
            stopwatchStart = Date(timeIntervalSince1970: storedStopwatchStart)
        }

        if storedTimerEnd > 0 {
            let candidate = Date(timeIntervalSince1970: storedTimerEnd)
            if candidate > Date() {
                timerEndDate = candidate
            } else {
                storedTimerEnd = 0
            }
        }
    }

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func formatHMS(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(max(0, interval))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private func formatMMSS(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(max(0, interval.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

private struct TimeTrackingCard: View {
    let title: String
    let statusTitle: String
    let timeLabel: String
    let nextLabel: String
    let progress: Double
    let tint: Color
    let primaryButtonTitle: String
    let primaryButtonAction: () -> Void
    let secondaryButtonTitle: String
    let secondaryButtonAction: () -> Void
    let statusEmphasis: String?
    var showSecondaryButton: Bool = true

    var body: some View {
        VStack(alignment: .center, spacing: 14) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            ZStack {
                Circle()
                    .stroke(tint.opacity(0.12), lineWidth: 10)
                    .frame(width: 120, height: 120)
                Circle()
                    .trim(from: 0, to: min(max(progress, 0), 1))
                    .stroke(tint, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 120, height: 120)
                VStack(spacing: 4) {
                    Text(statusEmphasis ?? statusTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text(timeLabel)
                        .font(.system(size: 18, weight: .semibold))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)

            Text(nextLabel)
                .font(.headline)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            if showSecondaryButton {
                HStack(spacing: 10) {
                    Button(action: primaryButtonAction) {
                        Text(primaryButtonTitle)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(.white)
                            .glassEffect(.regular.tint(tint), in: .rect(cornerRadius: 16.0))
                    }

                    Button(action: secondaryButtonAction) {
                        Text(secondaryButtonTitle)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(.primary)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(.secondary.opacity(0.18), lineWidth: 1)
                            )
                    }
                }
            } else {
                Button(action: primaryButtonAction) {
                    Text(primaryButtonTitle)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(.white)
                        .glassEffect(.regular.tint(tint), in: .rect(cornerRadius: 16.0))
                }
            }
        }
        .padding(20)
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .frame(height: 380)
    }
}

struct TimeTrackingEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var config: TimeTrackingConfig
    var onSave: (TimeTrackingConfig) -> Void = { _ in }

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var working = TimeTrackingConfig.defaultConfig
    @State private var hasLoaded = false
    @State private var showColorPickerSheet = false
    @State private var colorPickerTarget: ColorTarget?

    private let minMinutes = 1
    private let maxMinutes = 240

    private enum ColorTarget { case stopwatch, timer }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tracked Timers")
                            .font(.subheadline.weight(.semibold))

                        VStack(spacing: 12) {
                            TrackedTimerRow(
                                title: "Stopwatch",
                                name: $working.stopwatchName,
                                hoursBinding: hourBinding(for: .stopwatch),
                                minutesBinding: minuteBinding(for: .stopwatch),
                                colorHex: working.stopwatchColorHex,
                                onColorTap: {
                                    guard themeManager.selectedTheme == .multiColour else { return }
                                    if #available(iOS 17.0, *) {
                                        Task { await EditSheetTips.colorPickerOpened.donate() }
                                    }
                                    colorPickerTarget = .stopwatch
                                    showColorPickerSheet = true
                                },
                                minMinutes: minMinutes,
                                maxMinutes: maxMinutes,
                                showTip: true
                            )

                            TrackedTimerRow(
                                title: "Timer",
                                name: $working.timerName,
                                hoursBinding: hourBinding(for: .timer),
                                minutesBinding: minuteBinding(for: .timer),
                                colorHex: working.timerColorHex,
                                onColorTap: {
                                    guard themeManager.selectedTheme == .multiColour else { return }
                                    if #available(iOS 17.0, *) {
                                        Task { await EditSheetTips.colorPickerOpened.donate() }
                                    }
                                    colorPickerTarget = .timer
                                    showColorPickerSheet = true
                                },
                                minMinutes: minMinutes,
                                maxMinutes: maxMinutes
                            )
                        }
                    }

                    Text("Durations are clamped between \(minMinutes) and \(maxMinutes) minutes.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("Edit Time Tracking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let clamped = clamp(working)
                        config = clamped
                        onSave(clamped)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear(perform: loadInitial)
        .sheet(isPresented: $showColorPickerSheet) {
            ColorPickerSheet { hex in
                applyColor(hex: hex)
                showColorPickerSheet = false
            } onCancel: {
                showColorPickerSheet = false
            }
            .presentationDetents([.height(180)])
            .presentationDragIndicator(.visible)
        }
    }


    private func loadInitial() {
        guard !hasLoaded else { return }
        working = config
        hasLoaded = true
    }

    private func clamp(_ value: TimeTrackingConfig) -> TimeTrackingConfig {
        var copy = value
        copy.stopwatchTargetMinutes = min(maxMinutes, max(minMinutes, copy.stopwatchTargetMinutes))
        copy.timerDurationMinutes = min(maxMinutes, max(minMinutes, copy.timerDurationMinutes))
        return copy
    }

    private func splitDuration(_ minutes: Int) -> (hours: Int, minutes: Int) {
        let clamped = max(0, minutes)
        return (clamped / 60, clamped % 60)
    }

    private func clampMinutes(_ minutes: Int) -> Int {
        min(maxMinutes, max(minMinutes, minutes))
    }

    private func hourBinding(for target: ColorTarget) -> Binding<String> {
        Binding {
            let minutes = target == .stopwatch ? working.stopwatchTargetMinutes : working.timerDurationMinutes
            let parts = splitDuration(minutes)
            return String(parts.hours)
        } set: { newValue in
            let hours = max(0, Int(newValue) ?? 0)
            let parts = target == .stopwatch ? splitDuration(working.stopwatchTargetMinutes) : splitDuration(working.timerDurationMinutes)
            let total = clampMinutes(hours * 60 + parts.minutes)
            if target == .stopwatch {
                working.stopwatchTargetMinutes = total
            } else {
                working.timerDurationMinutes = total
            }
        }
    }

    private func minuteBinding(for target: ColorTarget) -> Binding<String> {
        Binding {
            let minutes = target == .stopwatch ? working.stopwatchTargetMinutes : working.timerDurationMinutes
            let parts = splitDuration(minutes)
            return String(parts.minutes)
        } set: { newValue in
            let minutes = max(0, min(59, Int(newValue) ?? 0))
            let parts = target == .stopwatch ? splitDuration(working.stopwatchTargetMinutes) : splitDuration(working.timerDurationMinutes)
            let total = clampMinutes(parts.hours * 60 + minutes)
            if target == .stopwatch {
                working.stopwatchTargetMinutes = total
            } else {
                working.timerDurationMinutes = total
            }
        }
    }

    private func applyColor(hex: String) {
        switch colorPickerTarget {
        case .stopwatch:
            working.stopwatchColorHex = hex
        case .timer:
            working.timerColorHex = hex
        case .none:
            break
        }
    }
}

private struct TrackedTimerRow: View {
    let title: String
    @Binding var name: String
    var hoursBinding: Binding<String>
    var minutesBinding: Binding<String>
    var colorHex: String
    var onColorTap: () -> Void
    let minMinutes: Int
    let maxMinutes: Int
    var showTip: Bool = false

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            let displayColor: Color = {
                if themeManager.selectedTheme == .multiColour { return (Color(hex: colorHex) ?? Color.accentColor) }
                return themeManager.selectedTheme.accent(for: colorScheme)
            }()

            Button(action: onColorTap) {
                Circle()
                    .fill(displayColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay(Image(systemName: "clock")
                        .foregroundStyle(displayColor)
                        .editSheetChangeColorTip(
                            hasTrackedItems: true,
                            isMultiColourTheme: themeManager.selectedTheme == .multiColour,
                            isActive: showTip
                        )
                    )
            }
            .buttonStyle(.plain)
            .disabled(themeManager.selectedTheme != .multiColour)

            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("Name", text: $name)
                    .font(.subheadline.weight(.semibold))
                    .textInputAutocapitalization(.words)

                HStack(spacing: 12) {
                    HStack {
                        TextField("Hours", text: hoursBinding)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.plain)
                        Text("hrs")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .surfaceCard(16)
                    .frame(maxWidth: .infinity)

                    HStack {
                        TextField("Minutes", text: minutesBinding)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.plain)
                        Text("min")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .surfaceCard(16)
                    .frame(maxWidth: .infinity)
                }

                Text("Clamped to \(minMinutes)-\(maxMinutes) minutes.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

#if DEBUG
struct TimeTrackingSection_Previews: PreviewProvider {
    @State static var config = TimeTrackingConfig.defaultConfig
    static var previews: some View {
        TimeTrackingSection(accentColorOverride: .orange, config: $config)
            .environmentObject(ThemeManager())
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
#endif
