//
//  SportsTabView.swift
//  Pump Fitness
//
//  Created by Kyle Graham on 8/12/2025.
//

import SwiftUI

import Charts

struct SportsTabView: View {
    @Binding var account: Account
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var showCalendar = false
    @State private var selectedDate = Date()
    @State private var showAccountsView = false
    // Track expanded state for each sport
    @State private var expandedSports: [Bool] = []

    // MARK: - Models

    struct SportActivity: Identifiable {
        let id = UUID()
        var date: Date
        // Running, Cycling, Swimming
        var distanceKm: Double? = nil
        var durationMin: Double? = nil
        var speedKmh: Double? = nil
        // Swimming
        var laps: Int? = nil
        // Team sports
        var attemptsMade: Int? = nil
        var attemptsMissed: Int? = nil
        var accuracy: Double? = nil
        // Martial arts
        var rounds: Int? = nil
        var roundDuration: Double? = nil
        var points: Int? = nil
        // Pilates/Yoga
        var holdTime: Double? = nil
        var poses: Int? = nil
        // Climbing
        var altitude: Double? = nil
        var timeToPeak: Double? = nil
        var restTime: Double? = nil

        // Computed properties
        var speedKmhComputed: Double? {
            if let distance = distanceKm, let duration = durationMin, duration > 0 {
                return distance / (duration / 60.0)
            }
            return nil
        }
        var accuracyComputed: Double? {
            if let made = attemptsMade, let missed = attemptsMissed, (made + missed) > 0 {
                return Double(made) / Double(made + missed) * 100.0
            }
            return nil
        }
    }

    struct SportMetric: Identifiable {
        let id = UUID()
        var key: String // e.g. "distanceKm", "durationMin", etc.
        var label: String // e.g. "Distance", "Duration"
        var unit: String // e.g. "km", "min"
        var color: Color
        var valueTransform: ((SportActivity) -> Double)? = nil // Optional custom transform
    }

    struct SportType: Identifiable {
        let id = UUID()
        var name: String
        var activities: [SportActivity]
        var metrics: [SportMetric]
    }

    // MARK: - Sample Data

    @State private var sports: [SportType] = {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        func metric(_ key: String, _ label: String, _ unit: String, _ color: Color, transform: ((SportActivity) -> Double)? = nil) -> SportMetric {
            SportMetric(key: key, label: label, unit: unit, color: color, valueTransform: transform)
        }

        let runningMetrics = [
            metric("distanceKm", "Distance", "km", .blue),
            metric("durationMin", "Duration", "min", .green),
            metric("speedKmhComputed", "Speed", "km/h", .orange, transform: { $0.speedKmhComputed ?? 0 })
        ]
        let cyclingMetrics = [
            metric("distanceKm", "Distance", "km", .blue),
            metric("durationMin", "Duration", "min", .green),
            metric("speedKmhComputed", "Speed", "km/h", .orange, transform: { $0.speedKmhComputed ?? 0 })
        ]
        let swimmingMetrics = [
            metric("distanceKm", "Distance", "km", .blue),
            metric("laps", "Laps", "laps", .purple),
            metric("durationMin", "Duration", "min", .green)
        ]
        let teamMetrics = [
            metric("durationMin", "Duration", "min", .green),
            metric("attemptsMade", "Attempts Made", "count", .teal),
            metric("attemptsMissed", "Attempts Missed", "count", .red),
            metric("accuracyComputed", "Accuracy", "%", .yellow, transform: { $0.accuracyComputed ?? 0 })
        ]
        let martialMetrics = [
            metric("rounds", "Rounds", "rounds", .indigo),
            metric("roundDuration", "Round Duration", "min", .mint),
            metric("points", "Points", "pts", .pink)
        ]
        let pilatesMetrics = [
            metric("durationMin", "Duration", "min", .green),
            metric("holdTime", "Hold Time", "sec", .cyan),
            metric("poses", "Poses", "poses", .brown)
        ]
        let climbingMetrics = [
            metric("altitude", "Altitude", "m", .gray),
            metric("timeToPeak", "Time to Peak", "min", .blue.opacity(0.7)),
            metric("restTime", "Rest Time", "min", .green.opacity(0.7)),
            metric("durationMin", "Duration", "min", .green)
        ]
        let padelMetrics = [
            metric("durationMin", "Duration", "min", .green),
            metric("attemptsMade", "Attempts Made", "count", .teal),
            metric("points", "Points", "pts", .pink)
        ]
        let tennisMetrics = [
            metric("durationMin", "Duration", "min", .green),
            metric("attemptsMade", "Attempts Made", "count", .teal),
            metric("attemptsMissed", "Attempts Missed", "count", .red),
            metric("accuracy", "Accuracy", "%", .yellow),
            metric("points", "Points", "pts", .pink)
        ]

        // ...existing code for activities...
        let runningActivities: [SportActivity] = [
            SportActivity(date: today, distanceKm: 5.2, durationMin: 32),
            SportActivity(date: cal.date(byAdding: .day, value: -1, to: today)!, distanceKm: 7.0, durationMin: 45),
            SportActivity(date: cal.date(byAdding: .day, value: -2, to: today)!, distanceKm: 3.5, durationMin: 22),
            SportActivity(date: cal.date(byAdding: .day, value: -3, to: today)!, distanceKm: 10.0, durationMin: 65),
            SportActivity(date: cal.date(byAdding: .day, value: -4, to: today)!, distanceKm: 4.0, durationMin: 28),
            SportActivity(date: cal.date(byAdding: .day, value: -5, to: today)!, distanceKm: 6.3, durationMin: 38)
        ]
        let cyclingActivities: [SportActivity] = [
            SportActivity(date: today, distanceKm: 15.0, durationMin: 50),
            SportActivity(date: cal.date(byAdding: .day, value: -1, to: today)!, distanceKm: 22.5, durationMin: 80),
            SportActivity(date: cal.date(byAdding: .day, value: -2, to: today)!, distanceKm: 10.0, durationMin: 35)
        ]
        let swimmingActivities: [SportActivity] = [
            SportActivity(date: today, distanceKm: 1.2, durationMin: 40, laps: 24),
            SportActivity(date: cal.date(byAdding: .day, value: -1, to: today)!, distanceKm: 0.8, durationMin: 28, laps: 16)
        ]
        let teamActivities: [SportActivity] = [
            SportActivity(date: today, durationMin: 60, attemptsMade: 12, attemptsMissed: 5),
            SportActivity(date: cal.date(byAdding: .day, value: -1, to: today)!, durationMin: 45, attemptsMade: 8, attemptsMissed: 7)
        ]
        let martialActivities: [SportActivity] = [
            SportActivity(date: today, rounds: 3, roundDuration: 5, points: 18),
            SportActivity(date: cal.date(byAdding: .day, value: -1, to: today)!, rounds: 5, roundDuration: 3, points: 22)
        ]
        let pilatesActivities: [SportActivity] = [
            SportActivity(date: today, durationMin: 55, holdTime: 30, poses: 12),
            SportActivity(date: cal.date(byAdding: .day, value: -1, to: today)!, durationMin: 40, holdTime: 45, poses: 9)
        ]
        let climbingActivities: [SportActivity] = [
            SportActivity(date: today, durationMin: 120, altitude: 1200, timeToPeak: 90, restTime: 20),
            SportActivity(date: cal.date(byAdding: .day, value: -1, to: today)!, durationMin: 90, altitude: 800, timeToPeak: 60, restTime: 15)
        ]
        let padelActivities: [SportActivity] = [
            SportActivity(date: today, durationMin: 90, attemptsMade: 30, attemptsMissed: 12, accuracy: 71.4, points: 18),
            SportActivity(date: cal.date(byAdding: .day, value: -1, to: today)!, durationMin: 80, attemptsMade: 25, attemptsMissed: 15, accuracy: 62.5, points: 15)
        ]
        let tennisActivities: [SportActivity] = [
            SportActivity(date: today, durationMin: 75, attemptsMade: 40, attemptsMissed: 20, accuracy: 66.7, points: 21),
            SportActivity(date: cal.date(byAdding: .day, value: -1, to: today)!, durationMin: 60, attemptsMade: 32, attemptsMissed: 18, accuracy: 64.0, points: 17)
        ]

        return [
            SportType(name: "Running", activities: runningActivities, metrics: runningMetrics),
            SportType(name: "Cycling", activities: cyclingActivities, metrics: cyclingMetrics),
            SportType(name: "Swimming", activities: swimmingActivities, metrics: swimmingMetrics),
            SportType(name: "Team Sports", activities: teamActivities, metrics: teamMetrics),
            SportType(name: "Martial Arts", activities: martialActivities, metrics: martialMetrics),
            SportType(name: "Pilates/Yoga", activities: pilatesActivities, metrics: pilatesMetrics),
            SportType(name: "Climbing", activities: climbingActivities, metrics: climbingMetrics),
            SportType(name: "Padel", activities: padelActivities, metrics: padelMetrics),
            SportType(name: "Tennis", activities: tennisActivities, metrics: tennisMetrics)
        ]
    }()

    private let historyDays: Int = 7

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundView
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 0) {
                            HeaderComponent(
                                showCalendar: $showCalendar,
                                selectedDate: $selectedDate,
                                onProfileTap: { showAccountsView = true }
                            )
                            .environmentObject(account)

                            HStack {
                                Text("Sports Tracking")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)

                                Spacer()

                                Button {
                                    //
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                        .font(.callout)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .glassEffect(in: .rect(cornerRadius: 18.0))
                                }
                                .buttonStyle(.plain)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 18)
                            .padding(.top, 48)
                            .padding(.bottom, 8)

                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(Array(sports.enumerated()), id: \ .offset) { idx, sport in
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            Spacer()
                                            Label(sport.name, systemImage: (idx < expandedSports.count && expandedSports[idx]) ? "chevron.up" : "chevron.down")
                                                .font(.callout.weight(.semibold))
                                            Spacer()
                                        }
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                                if idx < expandedSports.count {
                                                    expandedSports[idx].toggle()
                                                }
                                            }
                                        }

                                        if idx < expandedSports.count && expandedSports[idx] {
                                            ForEach(sport.metrics) { metric in
                                                SportMetricGraph(
                                                    metric: metric,
                                                    activities: sport.activities,
                                                    historyDays: historyDays
                                                )
                                                .frame(height: 140)
                                                .padding(.bottom, 8)
                                            }
                                            Button {
                                                // 
                                            } label: {
                                                Label("Submit Data", systemImage: "paperplane.fill")
                                                    .font(.callout.weight(.semibold))
                                                    .padding(.vertical, 18)
                                                    .frame(maxWidth: .infinity, minHeight: 52)
                                                    .glassEffect(in: .rect(cornerRadius: 16.0))
                                            }
                                            .padding(.horizontal, 8)
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(20)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                    .glassEffect(in: .rect(cornerRadius: 16.0))
                                    .padding(.horizontal, 18)
                                    .padding(.top, 12)
                                }
                            }
                            .padding(.top, -12)

                            Button(action: { /* TODO: present upgrade flow */ }) {
                                HStack(alignment: .center) {
                                    Image(systemName: "sparkles")
                                            .font(.title3)
                                            .foregroundStyle(accentOverride ?? .accentColor)
                                        .padding(.trailing, 8)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Upgrade to Pro")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)

                                        Text("Unlock more sports trackers + other benefits")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(12)
                                .glassEffect(in: .rect(cornerRadius: 12.0))
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 8)
                            .padding(.horizontal, 18)
                            
                            ShareProgressCTA(accentColor: accentOverride ?? .accentColor)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 24)
                        }
                    }

                    Spacer()
                }
                if showCalendar {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                        .onTapGesture { showCalendar = false }
                    CalendarComponent(selectedDate: $selectedDate, showCalendar: $showCalendar)
                }
            }
            .navigationDestination(isPresented: $showAccountsView) {
                AccountsView(account: $account)
            }
        }
        .onAppear {
            // Ensure expandedSports matches the number of sports
            if expandedSports.count != sports.count {
                expandedSports = Array(repeating: false, count: sports.count)
            }
        }
    }
}

// MARK: - Modular Metric Graph

struct SportMetricGraph: View {
    let metric: SportsTabView.SportMetric
    let activities: [SportsTabView.SportActivity]
    let historyDays: Int

    private var cal: Calendar { Calendar.current }
    private var today: Date { cal.startOfDay(for: Date()) }

    private var displayDates: [Date] {
        (0..<historyDays).compactMap { offset in
            cal.date(byAdding: .day, value: -offset, to: today)
        }.reversed()
    }

    private func value(for activity: SportsTabView.SportActivity) -> Double {
        if let transform = metric.valueTransform {
            return transform(activity)
        }
        // Fallback: use key-based lookup
        switch metric.key {
        case "distanceKm": return activity.distanceKm ?? 0
        case "durationMin": return activity.durationMin ?? 0
        case "speedKmh": return activity.speedKmh ?? 0
        case "speedKmhComputed": return activity.speedKmhComputed ?? 0
        case "laps": return Double(activity.laps ?? 0)
        case "attemptsMade": return Double(activity.attemptsMade ?? 0)
        case "attemptsMissed": return Double(activity.attemptsMissed ?? 0)
        case "accuracy": return activity.accuracy ?? activity.accuracyComputed ?? 0
        case "accuracyComputed": return activity.accuracyComputed ?? 0
        case "rounds": return Double(activity.rounds ?? 0)
        case "roundDuration": return activity.roundDuration ?? 0
        case "points": return Double(activity.points ?? 0)
        case "holdTime": return activity.holdTime ?? 0
        case "poses": return Double(activity.poses ?? 0)
        case "altitude": return activity.altitude ?? 0
        case "timeToPeak": return activity.timeToPeak ?? 0
        case "restTime": return activity.restTime ?? 0
        default: return 0
        }
    }

    private var dailyTotals: [(date: Date, total: Double)] {
        let grouped = Dictionary(grouping: activities) { cal.startOfDay(for: $0.date) }
        return displayDates.map { day in
            let items = grouped[day] ?? []
            let total = items.reduce(0) { $0 + value(for: $1) }
            return (date: day, total: total)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(metric.label) (\(metric.unit))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(metric.color)
                
                Spacer()

                Button {
                    // 
                } label: {
                    Image(systemName: "pencil")
                        .font(.callout)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassEffect(in: .rect(cornerRadius: 18.0))
                        .accessibilityLabel("Edit")
                }
                .buttonStyle(.plain)
            }

            Chart {
                ForEach(dailyTotals, id: \ .date) { item in
                    BarMark(
                        x: .value("Day", DateFormatter.shortDate.string(from: item.date)),
                        y: .value(metric.label, item.total)
                    )
                    .foregroundStyle(metric.color)
                    .cornerRadius(4)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                let labels = displayDates.enumerated().compactMap { idx, d in
                    (idx % max(1, historyDays / 6) == 0) ? DateFormatter.shortDate.string(from: d) : nil
                }
                AxisMarks(values: labels) { value in
                    AxisGridLine()
                    AxisValueLabel() {
                        if let label = value.as(String.self) {
                            Text(label)
                                .font(.caption2)
                        }
                    }
                }
            }
        }
    }
}

private extension SportsTabView {
    @ViewBuilder
    var backgroundView: some View {
        if themeManager.selectedTheme == .multiColour {
            GradientBackground(theme: .sports)
        } else {
            themeManager.selectedTheme.background(for: colorScheme)
                .ignoresSafeArea()
        }
    }

    var accentOverride: Color? {
        guard themeManager.selectedTheme != .multiColour else { return nil }
        return themeManager.selectedTheme.accent(for: colorScheme)
    }
}

private extension DateFormatter {
    static var shortDate: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEE" // weekday short (Mon, Tue)
        return df
    }()
}
