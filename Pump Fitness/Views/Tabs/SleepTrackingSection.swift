//
//  SleepTrackingSection.swift
//  Trackerio
//
//  Created by GitHub Copilot on 2025-12-05.
//

import SwiftUI
import Combine

struct SleepTrackingSection: View {
    let accentColor: Color?
    @Binding var nightStored: TimeInterval
    @Binding var napStored: TimeInterval
    var onPersist: (TimeInterval, TimeInterval) -> Void
    var onLiveUpdate: (TimeInterval, TimeInterval) -> Void

    @State private var timerTick: Date = Date()

    @State private var nightRunning: Bool = false
    @State private var napRunning: Bool = false

    @State private var nightStart: Date? = nil
    @State private var napStart: Date? = nil

    // Keep a fixed baseline captured at the moment a timer starts so that
    // live updates to the bound stored values do not compound elapsed time.
    @State private var nightAccumulatedAtStart: TimeInterval = 0
    @State private var napAccumulatedAtStart: TimeInterval = 0

    // Persist the timer publisher across view re-creations to avoid
    // creating multiple autoconnect subscriptions which accelerate ticks.
    @State private var timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    private enum EditingTimer: Int, Identifiable {
        case night
        case nap

        var id: Int { rawValue }
    }

    @State private var editingTimer: EditingTimer? = nil

    @AppStorage("sleeptracking.nightStart") private var storedNightStart: Double = 0
    @AppStorage("sleeptracking.napStart") private var storedNapStart: Double = 0
    @AppStorage("sleeptracking.nightAccum") private var storedNightAccum: Double = 0
    @AppStorage("sleeptracking.napAccum") private var storedNapAccum: Double = 0

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Night Sleep card — tapping opens editor
                StopwatchCard(
                    title: "Night Sleep",
                    elapsed: currentNightElapsed,
                    isRunning: nightRunning,
                    showsStartButton: true,
                    showsSeconds: true,
                    accent: accentColor ?? .accentColor,
                    startAction: { toggleNight() },
                    editAction: { openEditor(.night) }
                )

                // Nap card — tapping opens editor
                StopwatchCard(
                    title: "Nap",
                    elapsed: currentNapElapsed,
                    isRunning: napRunning,
                    showsStartButton: true,
                    showsSeconds: true,
                    accent: accentColor ?? .accentColor,
                    startAction: { toggleNap() },
                    editAction: { openEditor(.nap) }
                )
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
            // force a state change so SwiftUI re-renders and recomputes elapsed time
            timerTick = Date()
            // send live totals while any timer is running
            if nightRunning || napRunning {
                onLiveUpdate(currentNightElapsed, currentNapElapsed)
            }
        }
        // Note: don't set view identity to the ticking date — changing the view's `id`
        // every second causes SwiftUI to recreate the view and reconnect the timer,
        // which can lead to multiple timer subscriptions and accelerating ticks.
        .onChange(of: nightStored) { _, _ in
            // If the user is currently running the night timer, ignore external stored-value
            // updates (they may come from live updates) so the timer isn't stopped.
            if !nightRunning {
                nightAccumulatedAtStart = nightStored
                nightStart = nil
                nightRunning = false
            }
        }
        .onChange(of: napStored) { _, _ in
            // Same handling for nap: only reset if the nap timer isn't running.
            if !napRunning {
                napAccumulatedAtStart = napStored
                napStart = nil
                napRunning = false
            }
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
                        storedNightStart = 0
                        storedNightAccum = 0
                        nightStored = newElapsed
                        onPersist(nightStored, napStored)
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
                        storedNapStart = 0
                        storedNapAccum = 0
                        napStored = newElapsed
                        onPersist(nightStored, napStored)
                        editingTimer = nil
                    },
                    onCancel: {
                        editingTimer = nil
                    }
                )
            }
        }
        .onAppear {
            if storedNightStart > 0 {
                nightStart = Date(timeIntervalSince1970: storedNightStart)
                nightAccumulatedAtStart = storedNightAccum
                nightRunning = true
            }
            if storedNapStart > 0 {
                napStart = Date(timeIntervalSince1970: storedNapStart)
                napAccumulatedAtStart = storedNapAccum
                napRunning = true
            }
        }
    }

    private var currentNightElapsed: TimeInterval {
        if let start = nightStart, nightRunning {
            return nightAccumulatedAtStart + Date().timeIntervalSince(start)
        }
        return nightStored
    }

    private var currentNapElapsed: TimeInterval {
        if let start = napStart, napRunning {
            return napAccumulatedAtStart + Date().timeIntervalSince(start)
        }
        return napStored
    }

    private func toggleNight() {
        if nightRunning {
            // stop
            if let start = nightStart {
                nightStored = nightAccumulatedAtStart + Date().timeIntervalSince(start)
            }
            nightStart = nil
            nightRunning = false
            
            // Clear persistence
            storedNightStart = 0
            storedNightAccum = 0
            
            onPersist(nightStored, napStored)
        } else {
            // if a nap is running, stop it first
            if napRunning {
                if let nstart = napStart {
                    napStored = napAccumulatedAtStart + Date().timeIntervalSince(nstart)
                }
                napStart = nil
                napRunning = false
                
                // Clear nap persistence
                storedNapStart = 0
                storedNapAccum = 0
                
                onPersist(nightStored, napStored)
            }

            // start night timer
            nightAccumulatedAtStart = nightStored
            nightStart = Date()
            nightRunning = true
            
            // Persist start
            storedNightAccum = nightAccumulatedAtStart
            storedNightStart = nightStart!.timeIntervalSince1970
        }
    }

    private func toggleNap() {
        if napRunning {
            if let start = napStart {
                napStored = napAccumulatedAtStart + Date().timeIntervalSince(start)
            }
            napStart = nil
            napRunning = false
            
            // Clear persistence
            storedNapStart = 0
            storedNapAccum = 0
            
            onPersist(nightStored, napStored)
        } else {
            // if night sleep is running, stop it first
            if nightRunning {
                if let nstart = nightStart {
                    nightStored = nightAccumulatedAtStart + Date().timeIntervalSince(nstart)
                }
                nightStart = nil
                nightRunning = false
                
                // Clear night persistence
                storedNightStart = 0
                storedNightAccum = 0
                
                onPersist(nightStored, napStored)
            }

            // start nap timer
            napAccumulatedAtStart = napStored
            napStart = Date()
            napRunning = true
            
            // Persist start
            storedNapAccum = napAccumulatedAtStart
            storedNapStart = napStart!.timeIntervalSince1970
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
    let showsSeconds: Bool
    let accent: Color
    let startAction: () -> Void
    let editAction: (() -> Void)?

    init(title: String,
         elapsed: TimeInterval,
         isRunning: Bool,
         showsStartButton: Bool,
         showsSeconds: Bool = false,
         accent: Color,
         startAction: @escaping () -> Void,
         editAction: (() -> Void)? = nil) {
        self.title = title
        self.elapsed = elapsed
        self.isRunning = isRunning
        self.showsStartButton = showsStartButton
        self.showsSeconds = showsSeconds
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
            if let edit = editAction {
                Button(action: edit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func timeString(from interval: TimeInterval) -> String {
        if showsSeconds {
            let totalSeconds = Int(interval)
            // Show MM:SS while under 60 minutes, then switch to H:MM (no seconds)
            if totalSeconds < 3600 {
                let minutes = (totalSeconds / 60)
                let seconds = totalSeconds % 60
                return String(format: "%02d:%02d", minutes, seconds)
            } else {
                let hours = totalSeconds / 3600
                let minutes = (totalSeconds % 3600) / 60
                return String(format: "%d:%02d", hours, minutes)
            }
        } else {
            let totalMinutes = Int(interval) / 60
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            // Always show H:MM for Total Sleep
            return String(format: "%d:%02d", hours, minutes)
        }
    }
}

struct SleepTrackingSection_Previews: PreviewProvider {
    static var previews: some View {
        SleepTrackingSection(
            accentColor: .accentColor,
            nightStored: .constant(7_200),
            napStored: .constant(1_200),
            onPersist: { _, _ in },
            onLiveUpdate: { _, _ in }
        )
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
