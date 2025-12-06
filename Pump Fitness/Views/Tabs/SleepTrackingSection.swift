//
//  SleepTrackingSection.swift
//  Pump Fitness
//
//  Created by GitHub Copilot on 2025-12-05.
//

import SwiftUI
import Combine

struct SleepTrackingSection: View {
    let accentColor: Color?

    @State private var nightAccumulated: TimeInterval = 0
    @State private var napAccumulated: TimeInterval = 0

    @State private var nightRunning: Bool = false
    @State private var napRunning: Bool = false

    @State private var nightStart: Date? = nil
    @State private var napStart: Date? = nil

    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    private enum EditingTimer: Int, Identifiable {
        case night
        case nap

        var id: Int { rawValue }
    }

    @State private var editingTimer: EditingTimer? = nil

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Night Sleep card — tapping opens editor
                StopwatchCard(
                    title: "Night Sleep",
                    elapsed: currentNightElapsed,
                    isRunning: nightRunning,
                    showsStartButton: true,
                    accent: accentColor ?? .accentColor,
                    startAction: { toggleNight() },
                    editAction: { openEditor(.night) }
                )
                .onTapGesture {
                    openEditor(.night)
                }

                // Nap card — tapping opens editor
                StopwatchCard(
                    title: "Nap",
                    elapsed: currentNapElapsed,
                    isRunning: napRunning,
                    showsStartButton: true,
                    accent: accentColor ?? .accentColor,
                    startAction: { toggleNap() },
                    editAction: { openEditor(.nap) }
                )
                .onTapGesture {
                    openEditor(.nap)
                }
            }

            StopwatchCard(
                title: "Total Sleep",
                elapsed: currentNightElapsed + currentNapElapsed,
                isRunning: false,
                showsStartButton: false,
                accent: accentColor ?? .accentColor,
                startAction: { }
            )
            .frame(maxWidth: .infinity)
        }
        .onReceive(timer) { _ in
            // tick keeps UI updated
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .sheet(item: $editingTimer) { item in
            switch item {
            case .night:
                SleepTimerEditorSheet(
                    title: "Edit Night Sleep",
                    initialElapsed: currentNightElapsed,
                    tint: accentColor ?? .accentColor,
                    onDone: { newElapsed in
                        nightStart = nil
                        nightRunning = false
                        nightAccumulated = newElapsed
                        editingTimer = nil
                    },
                    onCancel: {
                        editingTimer = nil
                    }
                )
            case .nap:
                SleepTimerEditorSheet(
                    title: "Edit Nap",
                    initialElapsed: currentNapElapsed,
                    tint: accentColor ?? .accentColor,
                    onDone: { newElapsed in
                        napStart = nil
                        napRunning = false
                        napAccumulated = newElapsed
                        editingTimer = nil
                    },
                    onCancel: {
                        editingTimer = nil
                    }
                )
            }
        }
    }

    private var currentNightElapsed: TimeInterval {
        if let start = nightStart, nightRunning {
            return nightAccumulated + Date().timeIntervalSince(start)
        }
        return nightAccumulated
    }

    private var currentNapElapsed: TimeInterval {
        if let start = napStart, napRunning {
            return napAccumulated + Date().timeIntervalSince(start)
        }
        return napAccumulated
    }

    private func toggleNight() {
        if nightRunning {
            // stop
            if let start = nightStart {
                nightAccumulated += Date().timeIntervalSince(start)
            }
            nightStart = nil
            nightRunning = false
        } else {
            // start
            nightStart = Date()
            nightRunning = true
        }
    }

    private func toggleNap() {
        if napRunning {
            if let start = napStart {
                napAccumulated += Date().timeIntervalSince(start)
            }
            napStart = nil
            napRunning = false
        } else {
            napStart = Date()
            napRunning = true
        }
    }

    private func openEditor(_ which: EditingTimer) {
        // Ensure the timer is stopped when editing begins
        switch which {
        case .night:
            if nightRunning { toggleNight() }
        case .nap:
            if napRunning { toggleNap() }
        }
        editingTimer = which
    }
}

// MARK: - StopwatchCard

private struct StopwatchCard: View {
    let title: String
    let elapsed: TimeInterval
    let isRunning: Bool
    let showsStartButton: Bool
    let accent: Color
    let startAction: () -> Void
    let editAction: (() -> Void)?

    init(title: String,
         elapsed: TimeInterval,
         isRunning: Bool,
         showsStartButton: Bool,
         accent: Color,
         startAction: @escaping () -> Void,
         editAction: (() -> Void)? = nil) {
        self.title = title
        self.elapsed = elapsed
        self.isRunning = isRunning
        self.showsStartButton = showsStartButton
        self.accent = accent
        self.startAction = startAction
        self.editAction = editAction
    }

    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            Text(timeString(from: elapsed))
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            if showsStartButton {
                Button(action: startAction) {
                    Text(isRunning ? "Stop" : "Start")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(12)
        .glassEffect(in: .rect(cornerRadius: 12.0))
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) {
            Image(systemName: "pencil")
                .font(.system(size: 14, weight: .semibold))
                .padding(8)
        }
    }

    private func timeString(from interval: TimeInterval) -> String {
        let total = Int(interval)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct SleepTrackingSection_Previews: PreviewProvider {
    static var previews: some View {
        SleepTrackingSection(accentColor: .accentColor)
            .previewLayout(.sizeThatFits)
            .padding()
    }
}

// MARK: - Editor Sheet

private struct SleepTimerEditorSheet: View {
    let title: String
    let initialElapsed: TimeInterval
    var tint: Color
    var onDone: (TimeInterval) -> Void
    var onCancel: () -> Void

    @State private var hoursText: String = "0"
    @State private var minutesText: String = "00"
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Manual time")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Hours")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("0", text: $hoursText)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.plain)
                                .frame(width: 80)
                                .padding()
                                .surfaceCard(12)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Minutes")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("00", text: $minutesText)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.plain)
                                .frame(width: 80)
                                .padding()
                                .surfaceCard(12)
                        }
                    }

                    Text("This will set the elapsed time for the selected sleep timer. The timer is paused while editing.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        commit()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            let total = Int(initialElapsed)
            let hrs = total / 3600
            let mins = (total % 3600) / 60
            hoursText = String(hrs)
            minutesText = String(format: "%02d", mins)
        }
    }

    private func commit() {
        let h = Int(hoursText.filter { $0.isNumber }) ?? 0
        let m = Int(minutesText.filter { $0.isNumber }) ?? 0
        let total = TimeInterval(max(0, h * 3600 + m * 60))
        onDone(total)
    }
}
