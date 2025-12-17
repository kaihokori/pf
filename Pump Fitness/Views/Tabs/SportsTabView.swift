//
//  SportsTabView.swift
//  Pump Fitness
//
//  Created by Kyle Graham on 8/12/2025.
//

import Combine
import SwiftUI
import CoreLocation
import WeatherKit
import Charts

struct SportsTabView: View {
    @Binding var account: Account
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("timetracking.config") private var storedTimeTrackingConfigJSON: String = ""
    @State private var showCalendar = false
    @Binding var selectedDate: Date
    @State private var showAccountsView = false
    @State private var showTimeTrackingEditor = false
    @State private var timeTrackingConfig = TimeTrackingConfig.defaultConfig
    @StateObject private var weatherModel = WeatherViewModel()
    @State private var teamMetrics: [TeamMetric] = TeamMetric.defaultMetrics
    @State private var soloMetrics: [SoloMetric] = SoloMetric.defaultMetrics
    @State private var showTeamMetricsEditor = false
    @State private var showSoloMetricsEditor = false
    @State private var hasLoadedTimeTrackingConfig = false
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

    // MARK: - Weather Section

    struct WeatherSnapshot: Identifiable {
        let id = UUID()
        let time: Date
        let label: String
        let temperature: Int
        let temperatureDelta: Int?
        let precipitationChance: Int
        let min: Int
        let max: Int
        let uvIndex: Int
        let windSpeed: Int
        let humidity: Int
        let symbol: String
        let description: String
    }

    struct WeatherSection: View {
        @ObservedObject var viewModel: WeatherViewModel
        let selectedDate: Date

        private func symbolColors(for symbol: String) -> [Color] {
            let s = symbol.lowercased()
            if s.contains("sun") || s.contains("clear") { return [Color.yellow, Color.orange] }
            if s.contains("cloud") { return [Color.gray.opacity(0.9), Color.gray.opacity(0.6)] }
            if s.contains("rain") || s.contains("drizzle") { return [Color.blue.opacity(0.9), Color.cyan.opacity(0.7)] }
            if s.contains("snow") { return [Color.white, Color.blue.opacity(0.6)] }
            if s.contains("wind") { return [Color.gray, Color.cyan] }
            return []
        }

        var body: some View {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 16) {
                    switch viewModel.state {
                    case .idle, .loading:
                        HStack {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(.circular)
                            Spacer()
                        }
                    case .failed(let message):
                        VStack(alignment: .center, spacing: 8) {
                            Text("Weather unavailable")
                                .font(.headline)
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    case .loaded:
                        if let current = viewModel.currentSnapshot {
                            HStack {
                                Spacer()

                                HStack(spacing: 6) {
                                    Image(systemName: "location.fill")
                                        .font(.caption.weight(.bold))
                                    Text("Current Location")
                                        .font(.caption.weight(.semibold))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.14), in: Capsule())
                                .foregroundStyle(.white)
                                .padding(.bottom, 12)
                                .offset(x: 10, y: -8)
                            }

                            HStack {
                                Spacer()
                                VStack(spacing: 8) {
                                    let colors = symbolColors(for: current.symbol)
                                    if colors.isEmpty {
                                        Image(systemName: current.symbol)
                                            .font(.system(size: 42, weight: .semibold))
                                            .symbolRenderingMode(.multicolor)
                                    } else {
                                        Image(systemName: current.symbol)
                                            .font(.system(size: 42, weight: .semibold))
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(colors.count > 0 ? colors[0] : .primary,
                                                             colors.count > 1 ? colors[1] : colors.first ?? .primary)
                                    }
                                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                                        Text("\(current.temperature)°")
                                            .font(.system(size: 56, weight: .bold, design: .rounded))

                                        if let delta = current.temperatureDelta, delta != 0 {
                                            let isWarmer = delta > 0
                                            let trendColor: Color = isWarmer ? .red : .blue

                                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                                Image(systemName: isWarmer ? "chevron.up" : "chevron.down")
                                                    .font(.headline.weight(.bold))
                                                    .foregroundStyle(trendColor)
                                                Text(String(format: "%+d°", delta))
                                                    .font(.headline.weight(.bold))
                                                    .foregroundStyle(trendColor)
                                            }
                                        }
                                    }
                                    Text(current.description)
                                        .font(.headline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text("Min \(current.min)°   Max \(current.max)°")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    let pillColumns = [GridItem(.adaptive(minimum: 120), spacing: 12)]
                                    LazyVGrid(columns: pillColumns, alignment: .center, spacing: 12) {
                                        WeatherMetricPill(title: "UV", value: "\(current.uvIndex)", tint: .purple)
                                        WeatherMetricPill(title: "Wind", value: "\(current.windSpeed) km/h", tint: .white)
                                        WeatherMetricPill(title: "Humidity", value: "\(current.humidity)%", tint: .green)
                                        WeatherMetricPill(title: "Precipitation", value: "\(current.precipitationChance)%", tint: .cyan)
                                    }
                                    .frame(maxWidth: 280, alignment: .center)
                                }
                                Spacer()
                            }
                        }

                        Divider()

                        HStack {
                            Text(label(for: selectedDate))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Spacer()
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(viewModel.upcomingSnapshots.prefix(12)) { snapshot in
                                    VStack(alignment: .center, spacing: 10) {
                                        Text(snapshot.label)
                                            .font(.footnote.weight(.semibold))
                                            
                                        let sColors = symbolColors(for: snapshot.symbol)
                                        if sColors.isEmpty {
                                            Image(systemName: snapshot.symbol)
                                                .symbolRenderingMode(.multicolor)
                                        } else {
                                            Image(systemName: snapshot.symbol)
                                                .symbolRenderingMode(.palette)
                                                .foregroundStyle(sColors.count > 0 ? sColors[0] : .primary,
                                                                  sColors.count > 1 ? sColors[1] : sColors.first ?? .primary)
                                        }

                                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                                            Text("\(snapshot.temperature)°")
                                                .font(.title3.weight(.semibold))

                                            if let delta = snapshot.temperatureDelta, delta != 0 {
                                                let isWarmer = delta > 0
                                                Image(systemName: isWarmer ? "chevron.up" : "chevron.down")
                                                    .font(.caption.weight(.bold))
                                                    .foregroundStyle(isWarmer ? Color.red : Color.blue)
                                            }
                                        }
                                    }
                                    .padding(12)
                                    .frame(width: 80)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                    }
                }
            }
        }

        private func label(for date: Date) -> String {
            let calendar = Calendar.current
            if calendar.isDateInToday(date) { return "Next 12 Hours" }
            if calendar.isDateInTomorrow(date) { return "Tomorrow" }
            return DateFormatter.shortDay.string(from: date)
        }
    }

    enum WeatherLoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    @MainActor
    final class WeatherViewModel: ObservableObject {
        @Published var currentSnapshot: WeatherSnapshot?
        @Published var upcomingSnapshots: [WeatherSnapshot] = []
        @Published var state: WeatherLoadState = .idle

        private let calendar = Calendar.current
        private let weatherService: WeatherService
        private let locationProvider: LocationProvider

        init(weatherService: WeatherService? = nil, locationProvider: LocationProvider? = nil) {
            self.weatherService = weatherService ?? WeatherService()
            self.locationProvider = locationProvider ?? LocationProvider()
        }

        func refresh(for date: Date) async {
            state = .loading
            do {
                let location = try await locationProvider.currentLocation()
                if calendar.isDateInFuture(date) || calendar.isDateInToday(date) {
                    try await loadForecast(location: location, date: date)
                } else {
                    try await loadHistorical(location: location, date: date)
                }
                state = .loaded
            } catch {
                    let ns = error as NSError
                    if ns.domain == "WeatherDaemon.WDSJWTAuthenticatorServiceListener.Errors" && ns.code == 2 {
                        state = .failed("WeatherKit not authorized. Check entitlements and Apple ID.")
                    } else if error.localizedDescription.contains("WDSJWTAuthenticatorServiceListener") {
                        state = .failed("WeatherKit not authorized. Check entitlements and Apple ID.")
                    } else {
                        state = .failed(error.localizedDescription)
                    }
                }
        }

        private func loadForecast(location: CLLocation, date: Date) async throws {
            let weather = try await weatherService.weather(for: location)
            let dayForecast = weather.dailyForecast
            let hourly = weather.hourlyForecast
            apply(hourly: hourly, daily: dayForecast, target: date)
        }

        private func loadHistorical(location: CLLocation, date: Date) async throws {
            if #available(iOS 17.0, *) {
                let weather = try await weatherService.weather(for: location)
                apply(current: weather.currentWeather, hourly: weather.hourlyForecast, daily: weather.dailyForecast, target: date)
            } else {
                try await loadForecast(location: location, date: date)
                state = .failed("Historical weather requires iOS 17. Showing forecast instead.")
            }
        }

        private func apply(current: CurrentWeather, hourly: Forecast<HourWeather>, daily: Forecast<DayWeather>, target: Date) {
            let anchor = anchorHour(for: target, hourly: hourly)
            if let anchor {
                let anchorDay = dailyForecast(for: anchor.date, from: daily)
                let anchorTemp = Int(anchor.temperature.value.rounded())
                let delta = deltaVsPreviousDay(for: anchor.date, currentTemp: anchorTemp, daily: daily)
                currentSnapshot = makeSnapshot(from: anchor, day: anchorDay, delta: delta)
            } else {
                let currentTemp = Int(current.temperature.value.rounded())
                let delta = deltaVsPreviousDay(for: target, currentTemp: currentTemp, daily: daily)
                currentSnapshot = makeSnapshot(date: target, hourTemp: nil, current: current, day: dailyForecast(for: target, from: daily), delta: delta)
            }

            upcomingSnapshots = snapshotsWithDelta(hourly: hourly, daily: daily, anchor: anchor, count: 12)
        }

        private func apply(hourly: Forecast<HourWeather>, daily: Forecast<DayWeather>, target: Date) {
            let anchor = anchorHour(for: target, hourly: hourly)
            if let anchor {
                let anchorTemp = Int(anchor.temperature.value.rounded())
                let delta = deltaVsPreviousDay(for: anchor.date, currentTemp: anchorTemp, daily: daily)
                currentSnapshot = makeSnapshot(from: anchor, day: dailyForecast(for: anchor.date, from: daily), delta: delta)
            }
            upcomingSnapshots = snapshotsWithDelta(hourly: hourly, daily: daily, anchor: anchor, count: 12)
        }

        private func dailyForecast(for date: Date, from forecast: Forecast<DayWeather>) -> DayWeather? {
            forecast.first { calendar.isDate($0.date, inSameDayAs: date) }
        }

        private func sortedHours(_ hourly: Forecast<HourWeather>) -> [HourWeather] {
            hourly.sorted { $0.date < $1.date }
        }

        private func anchorHour(for date: Date, hourly: Forecast<HourWeather>) -> HourWeather? {
            let hours = sortedHours(hourly)
            guard !hours.isEmpty else { return nil }
            let referenceDate = calendar.isDateInToday(date) ? Date() : calendar.startOfDay(for: date)
            if let match = hours.first(where: { $0.date >= referenceDate }) { return match }
            return hours.first
        }

        private func nextHours(after anchor: HourWeather?, hourly: Forecast<HourWeather>, count: Int) -> [HourWeather] {
            let hours = sortedHours(hourly)
            guard let anchor else { return Array(hours.prefix(count)) }
            guard let idx = hours.firstIndex(where: { $0.date == anchor.date }) else {
                return Array(hours.prefix(count))
            }
            let slice = hours.dropFirst(idx + 1)
            return Array(slice.prefix(count))
        }

        private func deltaVsPreviousDay(for date: Date, currentTemp: Int, daily: Forecast<DayWeather>) -> Int? {
            guard let previousDate = calendar.date(byAdding: .day, value: -1, to: date),
                  let previousDay = dailyForecast(for: previousDate, from: daily) else { return nil }
            return currentTemp - Int(previousDay.highTemperature.value.rounded())
        }

        private func snapshotsWithDelta(hourly: Forecast<HourWeather>, daily: Forecast<DayWeather>, anchor: HourWeather?, count: Int) -> [WeatherSnapshot] {
            let hours = sortedHours(hourly)
            guard !hours.isEmpty else { return [] }

            var startIndex = 0
            if let anchor, let idx = hours.firstIndex(where: { $0.date == anchor.date }) {
                startIndex = min(hours.count, idx + 1)
            }

            let endIndex = min(hours.count, startIndex + count)
            var result: [WeatherSnapshot] = []

            for i in startIndex..<endIndex {
                let hour = hours[i]
                let previous = i > 0 ? hours[i - 1] : nil
                let delta = previous.map { Int(hour.temperature.value.rounded()) - Int($0.temperature.value.rounded()) }
                let day = dailyForecast(for: hour.date, from: daily)
                result.append(makeSnapshot(from: hour, day: day, delta: delta))
            }

            return result
        }

        private func makeSnapshot(date: Date, hourTemp: HourWeather?, current: CurrentWeather, day: DayWeather?, delta: Int?) -> WeatherSnapshot {
            WeatherSnapshot(
                time: date,
                label: DateFormatter.shortHour.string(from: date),
                temperature: Int(hourTemp?.temperature.value ?? current.temperature.value.rounded()),
                temperatureDelta: delta,
                precipitationChance: Int(((hourTemp?.precipitationChance ?? 0) * 100).rounded()),
                min: Int((day?.lowTemperature.value ?? current.temperature.value).rounded()),
                max: Int((day?.highTemperature.value ?? current.temperature.value).rounded()),
                uvIndex: Int(Double(current.uvIndex.value)),
                windSpeed: Int(current.wind.speed.converted(to: .kilometersPerHour).value.rounded()),
                humidity: Int((current.humidity * 100).rounded()),
                symbol: current.symbolName,
                description: (hourTemp?.condition.description ?? current.condition.description)
            )
        }

        private func makeSnapshot(from hour: HourWeather, day: DayWeather?, delta: Int?) -> WeatherSnapshot {
            WeatherSnapshot(
                time: hour.date,
                label: DateFormatter.shortHour.string(from: hour.date),
                temperature: Int(hour.temperature.value.rounded()),
                temperatureDelta: delta,
                precipitationChance: Int((hour.precipitationChance * 100).rounded()),
                min: Int((day?.lowTemperature.value ?? hour.temperature.value).rounded()),
                max: Int((day?.highTemperature.value ?? hour.temperature.value).rounded()),
                uvIndex: Int(Double(hour.uvIndex.value)),
                windSpeed: Int(hour.wind.speed.converted(to: .kilometersPerHour).value.rounded()),
                humidity: Int((hour.humidity * 100).rounded()),
                symbol: hour.symbolName,
                description: hour.condition.description
            )
        }
    }

    enum LocationError: LocalizedError {
        case denied
        case unavailable

        var errorDescription: String? {
            switch self {
            case .denied: return "Location access denied. Enable it in Settings to load weather."
            case .unavailable: return "Could not determine location."
            }
        }
    }

    final class LocationProvider: NSObject, CLLocationManagerDelegate {
        static let shared = LocationProvider()

        private let manager = CLLocationManager()
        private var locationContinuation: CheckedContinuation<CLLocation, Error>?
        private var authContinuation: CheckedContinuation<Void, Error>?

        override init() {
            super.init()
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        }

        func currentLocation() async throws -> CLLocation {
            if let location = manager.location { return location }

            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                return try await requestFreshLocation()
            case .notDetermined:
                try await requestAuthorization()
                return try await requestFreshLocation()
            case .restricted, .denied:
                throw LocationError.denied
            @unknown default:
                throw LocationError.unavailable
            }
        }

        private func requestAuthorization() async throws {
            manager.requestWhenInUseAuthorization()
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                authContinuation = continuation
            }
        }

        private func requestFreshLocation() async throws -> CLLocation {
            manager.requestLocation()
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CLLocation, Error>) in
                locationContinuation = continuation
            }
        }

        private var hasAuthorization: Bool {
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse: return true
            case .notDetermined, .restricted, .denied: return false
            @unknown default: return false
            }
        }

        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                authContinuation?.resume()
                authContinuation = nil
            case .denied, .restricted:
                authContinuation?.resume(throwing: LocationError.denied)
                authContinuation = nil
                locationContinuation?.resume(throwing: LocationError.denied)
                locationContinuation = nil
            case .notDetermined:
                break
            @unknown default:
                authContinuation?.resume(throwing: LocationError.unavailable)
                authContinuation = nil
                locationContinuation?.resume(throwing: LocationError.unavailable)
                locationContinuation = nil
            }
        }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            locationContinuation?.resume(throwing: error)
            locationContinuation = nil
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let location = locations.first else {
                locationContinuation?.resume(throwing: LocationError.unavailable)
                locationContinuation = nil
                return
            }
            locationContinuation?.resume(returning: location)
            locationContinuation = nil
        }
    }

    private struct WeatherMetricPill: View {
        let title: String
        let value: String
        var tint: Color = .accentColor

        var body: some View {
            HStack(spacing: 6) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                Text(value)
                    .font(.caption2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12), in: Capsule())
            .foregroundStyle(tint)
        }
    }

    private struct WeatherMetricRow: View {
        let label: String
        let value: String

        var body: some View {
            HStack {
                Text(label)
                Spacer()
                Text(value)
            }
        }
    }

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

                            if Calendar.current.isDateInToday(selectedDate) && weatherModel.state == .loaded {
                                HStack {
                                    Text("Weather")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.primary)

                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 18)
                                .padding(.top, 48)
                                .padding(.bottom, 8)

                                WeatherSection(viewModel: weatherModel, selectedDate: selectedDate)
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 18)
                                    .glassEffect(in: .rect(cornerRadius: 16.0))
                                    .padding(.horizontal, 18)
                            }

                            HStack {
                                Text("Time Tracking")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)

                                Spacer()

                                Button {
                                    showTimeTrackingEditor = true
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

                            TimeTrackingSection(
                                accentColorOverride: accentOverride,
                                config: $timeTrackingConfig
                            )
                                .padding(.horizontal, 18)
                            
                            HStack {
                                Text("Team Play Tracking")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)

                                Spacer()

                                Button {
                                    showTeamMetricsEditor = true
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

                            TeamPlaySection(selectedDate: selectedDate, metrics: $teamMetrics)
                                .padding(.horizontal, 18)

                            HStack {
                                Text("Solo Play Tracking")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)

                                Spacer()

                                Button {
                                    showSoloMetricsEditor = true
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

                           SoloPlaySection(selectedDate: selectedDate, metrics: $soloMetrics)
                               .padding(.horizontal, 18)

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
                                ForEach(Array(sports.enumerated()), id: \.offset) { idx, sport in
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            Spacer()
                                            VStack(spacing: 6) {
                                                Text(sport.name)
                                                    .font(.callout.weight(.semibold))
                                                    .multilineTextAlignment(.center)

                                                Image(systemName: (idx < expandedSports.count && expandedSports[idx]) ? "chevron.up" : "chevron.down")
                                                    .font(.callout.weight(.semibold))
                                                    .accessibilityHidden(true)
                                            }
                                            .frame(maxWidth: .infinity)
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
                        }

                        ShareProgressCTA(accentColor: accentOverride ?? .accentColor)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 24)
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
        .sheet(isPresented: $showTimeTrackingEditor) {
            TimeTrackingEditorSheet(config: $timeTrackingConfig) { updated in
                timeTrackingConfig = updated
                persistTimeTrackingConfig(updated)
            }
        }
        .sheet(isPresented: $showTeamMetricsEditor) {
            TeamPlayMetricsEditorSheet(metrics: $teamMetrics) { updated in
                teamMetrics = updated
            }
        }
        .sheet(isPresented: $showSoloMetricsEditor) {
            SoloPlayMetricsEditorSheet(metrics: $soloMetrics) { updated in
                soloMetrics = updated
            }
        }
        .onAppear {
            // Ensure expandedSports matches the number of sports
            if expandedSports.count != sports.count {
                expandedSports = Array(repeating: false, count: sports.count)
            }
            loadTimeTrackingConfigFromStorage()
        }
        .task {
            await weatherModel.refresh(for: selectedDate)
        }
        .onChange(of: selectedDate) { _, newValue in
            Task { await weatherModel.refresh(for: newValue) }
        }
    }
}

// MARK: - Time tracking persistence
private extension SportsTabView {
    func loadTimeTrackingConfigFromStorage() {
        guard !hasLoadedTimeTrackingConfig else { return }
        defer { hasLoadedTimeTrackingConfig = true }
        guard !storedTimeTrackingConfigJSON.isEmpty, let data = storedTimeTrackingConfigJSON.data(using: .utf8) else {
            persistTimeTrackingConfig(timeTrackingConfig)
            return
        }
        if let decoded = try? JSONDecoder().decode(TimeTrackingConfig.self, from: data) {
            timeTrackingConfig = decoded
        }
    }

    func persistTimeTrackingConfig(_ config: TimeTrackingConfig) {
        if let data = try? JSONEncoder().encode(config), let json = String(data: data, encoding: .utf8) {
            storedTimeTrackingConfigJSON = json
        }
    }
}

// MARK: - Solo Play

fileprivate struct SoloMetric: Identifiable, Equatable, Hashable {
    let id = UUID()
    var name: String
}

fileprivate extension SoloMetric {
    static var defaultMetrics: [SoloMetric] {
        [
            .init(name: "Distance"),
            .init(name: "Laps"),
            .init(name: "Speed"),
            .init(name: "Rounds")
        ]
    }
}

fileprivate struct SoloPlaySection: View {
    let selectedDate: Date

    @Binding var metrics: [SoloMetric]

    @State private var metricValues: [UUID: String] = [:]

    var body: some View {
        VStack(alignment: .center, spacing: 18) {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(rows(for: metrics), id: \.self) { row in
                    HStack(spacing: 12) {
                        ForEach(row) { metric in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(metric.name)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)

                                TextField(
                                    metric.name,
                                    text: valueBinding(for: metric),
                                    prompt: Text("Enter value…").foregroundStyle(.secondary)
                                )
                                .textInputAutocapitalization(.words)
                                .padding()
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                            }
                            .frame(maxWidth: .infinity)
                        }

                        if row.count == 1 {
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 18)
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .onAppear(perform: syncValueStore)
        .onChange(of: metrics) { _, _ in syncValueStore() }
    }

    private func valueBinding(for metric: SoloMetric) -> Binding<String> {
        Binding(
            get: { metricValues[metric.id] ?? "" },
            set: { metricValues[metric.id] = $0 }
        )
    }

    private func rows(for items: [SoloMetric]) -> [[SoloMetric]] {
        stride(from: 0, to: items.count, by: 2).map { idx in
            Array(items[idx..<min(idx + 2, items.count)])
        }
    }

    private func syncValueStore() {
        let validIds = Set(metrics.map { $0.id })
        metricValues = metricValues.filter { validIds.contains($0.key) }
        for metric in metrics where metricValues[metric.id] == nil {
            metricValues[metric.id] = "0"
        }
    }
}

private struct SoloPlayMetricsEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var metrics: [SoloMetric]
    var onSave: ([SoloMetric]) -> Void

    @State private var working: [SoloMetric] = []
    @State private var newName: String = ""
    @State private var hasLoaded = false

    private let presets: [String] = ["Distance", "Laps", "Speed", "Rounds"]
    private let maxTracked = 6

    private var canAddMore: Bool { working.count < maxTracked }
    private var canAddCustom: Bool {
        canAddMore && !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    if !working.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tracked Metrics")
                                .font(.subheadline.weight(.semibold))

                            VStack(spacing: 12) {
                                ForEach(Array(working.enumerated()), id: \.element.id) { idx, _ in
                                    let binding = $working[idx]
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(Color.accentColor.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                            .overlay(Image(systemName: "figure.climbing")
                                                .foregroundStyle(Color.accentColor))

                                        VStack {
                                            TextField("Metric name", text: binding.name)
                                                .font(.subheadline.weight(.semibold))

                                            HStack {
                                                Menu {
                                                    Button("Top") { moveMetricToTop(idx) }
                                                    Button("Up") { moveMetricUp(idx) }
                                                    Button("Down") { moveMetricDown(idx) }
                                                    Button("Bottom") { moveMetricToBottom(idx) }
                                                } label: {
                                                    Label("Reorder", systemImage: "arrow.up.arrow.down")
                                                        .font(.footnote.weight(.semibold))
                                                }

                                                Spacer()

                                                Button(role: .destructive) {
                                                    removeMetric(binding.wrappedValue.id)
                                                } label: {
                                                    Image(systemName: "trash")
                                                        .font(.footnote.weight(.semibold))
                                                }
                                            }
                                        }
                                    }
                                    .padding()
                                    .surfaceCard(16)
                                }
                            }
                        }
                    }

                    if !presets.filter({ !isPresetSelected($0) }).isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Presets")
                                .font(.subheadline.weight(.semibold))

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(presets.filter { !isPresetSelected($0) }, id: \.self) { preset in
                                    Button {
                                        togglePreset(preset)
                                    } label: {
                                        Text(preset)
                                            .font(.callout.weight(.semibold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .glassEffect(in: .rect(cornerRadius: 12))
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(!canAddMore)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Add Custom Metric")
                            .font(.subheadline.weight(.semibold))

                        HStack(spacing: 10) {
                            TextField("Enter name", text: $newName)
                                .textInputAutocapitalization(.words)
                                .padding()
                                .surfaceCard(14)

                            Button(action: addCustomMetric) {
                                Image(systemName: "plus")
                                    .font(.callout.weight(.semibold))
                                    .frame(width: 44, height: 44)
                                    .glassEffect(in: .capsule)
                            }
                            .buttonStyle(.plain)
                            .disabled(!canAddCustom)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("Edit Solo Metrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { donePressed() }
                }
            }
        }
        .onAppear(perform: loadInitial)
    }

    private func loadInitial() {
        guard !hasLoaded else { return }
        working = metrics.isEmpty ? SoloMetric.defaultMetrics : metrics
        hasLoaded = true
    }

    private func togglePreset(_ name: String) {
        if isPresetSelected(name) {
            working.removeAll { $0.name == name }
        } else if canAddMore {
            working.append(.init(name: name))
        }
    }

    private func isPresetSelected(_ name: String) -> Bool {
        working.contains { $0.name == name }
    }

    private func addCustomMetric() {
        guard canAddCustom else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        working.append(.init(name: trimmed))
        newName = ""
    }

    private func removeMetric(_ id: UUID) {
        working.removeAll { $0.id == id }
    }

    private func moveMetricUp(_ index: Int) {
        guard working.indices.contains(index), index > 0 else { return }
        working.swapAt(index, index - 1)
    }

    private func moveMetricDown(_ index: Int) {
        guard working.indices.contains(index), index < working.count - 1 else { return }
        working.swapAt(index, index + 1)
    }

    private func moveMetricToTop(_ index: Int) {
        guard working.indices.contains(index), index > 0 else { return }
        let item = working.remove(at: index)
        working.insert(item, at: 0)
    }

    private func moveMetricToBottom(_ index: Int) {
        guard working.indices.contains(index), index < working.count - 1 else { return }
        let item = working.remove(at: index)
        working.append(item)
    }

    private func donePressed() {
        metrics = working
        onSave(working)
        dismiss()
    }
}

// MARK: - Team Play

fileprivate struct TeamMetric: Identifiable, Equatable, Hashable {
    let id = UUID()
    var name: String
}

fileprivate extension TeamMetric {
    static var defaultMetrics: [TeamMetric] {
        [
            .init(name: "Attempts Made"),
            .init(name: "Attempts Missed"),
            .init(name: "Assists")
        ]
    }
}

fileprivate struct TeamPlaySection: View {
    let selectedDate: Date

    @Binding var metrics: [TeamMetric]

    @State private var homeScore: Int = 0
    @State private var awayScore: Int = 0
    @State private var metricValues: [UUID: String] = [:]

    var body: some View {
        VStack(alignment: .center, spacing: 18) {
            HStack(spacing: 12) {
                ScoreBox(title: "Home", value: $homeScore)
                ScoreBox(title: "Away", value: $awayScore)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(rows(for: metrics), id: \.self) { row in
                    HStack(spacing: 12) {
                        ForEach(row) { metric in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(metric.name)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)

                                TextField(metric.name, text: valueBinding(for: metric), prompt: Text("Enter value…").foregroundStyle(.secondary))
                                    .textInputAutocapitalization(.words)
                                    .padding()
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                            }
                            .frame(maxWidth: .infinity)
                        }

                        if row.count == 1 {
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 18)
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .onAppear(perform: syncValueStore)
        .onChange(of: metrics) { _, _ in syncValueStore() }
    }

    private func valueBinding(for metric: TeamMetric) -> Binding<String> {
        Binding(
            get: { metricValues[metric.id] ?? "" },
            set: { metricValues[metric.id] = $0 }
        )
    }

    private func syncValueStore() {
        let validIds = Set(metrics.map { $0.id })
        metricValues = metricValues.filter { validIds.contains($0.key) }
        for metric in metrics where metricValues[metric.id] == nil {
            metricValues[metric.id] = "0"
        }
    }

    private func rows(for items: [TeamMetric]) -> [[TeamMetric]] {
        stride(from: 0, to: items.count, by: 2).map { idx in
            Array(items[idx..<min(idx + 2, items.count)])
        }
    }

    private struct ScoreBox: View {
        let title: String
        @Binding var value: Int

        var body: some View {
            VStack(spacing: 12) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text("\(value)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)

                HStack(spacing: 10) {
                    Button {
                        if value > 0 { value -= 1 }
                    } label: {
                        Image(systemName: "minus")
                            .font(.headline.weight(.bold))
                            .frame(width: 44, height: 44)
                            .glassEffect(in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 52, height: 52)
                    .contentShape(Rectangle())

                    Button {
                        value += 1
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline.weight(.bold))
                            .frame(width: 44, height: 44)
                            .glassEffect(in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 52, height: 52)
                    .contentShape(Rectangle())
                }
            }
            .padding()
            .aspectRatio(1, contentMode: .fit)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

private struct TeamPlayMetricsEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var metrics: [TeamMetric]
    var onSave: ([TeamMetric]) -> Void

    @State private var working: [TeamMetric] = []
    @State private var newName: String = ""
    @State private var hasLoaded = false

    private let presets: [String] = ["Attempts Made", "Attempts Missed", "Assists"]
    private let maxTracked = 6

    private var canAddMore: Bool { working.count < maxTracked }
    private var canAddCustom: Bool {
        canAddMore && !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    if !working.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tracked Metrics")
                                .font(.subheadline.weight(.semibold))

                            VStack(spacing: 12) {
                                ForEach(Array(working.enumerated()), id: \.element.id) { idx, _ in
                                    let binding = $working[idx]
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(Color.accentColor.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                            .overlay(Image(systemName: "sportscourt")
                                                .foregroundStyle(Color.accentColor))

                                        VStack {
                                            TextField("Metric name", text: binding.name)
                                                .font(.subheadline.weight(.semibold))

                                            HStack {
                                                Menu {
                                                    Button("Top") { moveMetricToTop(idx) }
                                                    Button("Up") { moveMetricUp(idx) }
                                                    Button("Down") { moveMetricDown(idx) }
                                                    Button("Bottom") { moveMetricToBottom(idx) }
                                                } label: {
                                                    HStack(spacing: 6) {
                                                        Image(systemName: "arrow.up.arrow.down")
                                                            .font(.system(size: 14, weight: .semibold))
                                                        Text("Move")
                                                            .font(.caption)
                                                    }
                                                    .foregroundStyle(.secondary)
                                                }
                                                .buttonStyle(.plain)
                                                .padding(.trailing, 4)

                                                Spacer()
                                            }
                                        }

                                        Spacer()

                                        Button(role: .destructive) {
                                            removeMetric(working[idx].id)
                                        } label: {
                                            Image(systemName: "trash")
                                                .foregroundStyle(.red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding()
                                    .surfaceCard(16)
                                }
                            }
                        }
                    }

                    if !presets.filter({ !isPresetSelected($0) }).isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Quick Add")
                                .font(.subheadline.weight(.semibold))

                            VStack(spacing: 12) {
                                ForEach(presets.filter { !isPresetSelected($0) }, id: \.self) { preset in
                                    HStack(spacing: 14) {
                                        Circle()
                                            .fill(Color.accentColor.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                            .overlay(Image(systemName: "sportscourt")
                                                .foregroundStyle(Color.accentColor))

                                        Text(preset)
                                            .font(.subheadline.weight(.semibold))

                                        Spacer()

                                        Button(action: { togglePreset(preset) }) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 24, weight: .semibold))
                                                .foregroundStyle(Color.accentColor)
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(!canAddMore)
                                        .opacity(!canAddMore ? 0.3 : 1)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .surfaceCard(18)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Custom Metric")
                            .font(.subheadline.weight(.semibold))

                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                TextField("Metric name", text: $newName)
                                    .textInputAutocapitalization(.words)
                                    .padding()
                                    .surfaceCard(16)

                                Button(action: addCustomMetric) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 28, weight: .semibold))
                                        .foregroundStyle(Color.accentColor)
                                }
                                .buttonStyle(.plain)
                                .disabled(!canAddCustom)
                                .opacity(!canAddCustom ? 0.4 : 1)
                            }

                            Text("You can track up to \(maxTracked) metrics.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("Edit Team Metrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { donePressed() }
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear(perform: loadInitial)
    }

    private func loadInitial() {
        guard !hasLoaded else { return }
        working = metrics.isEmpty ? TeamMetric.defaultMetrics : metrics
        hasLoaded = true
    }

    private func togglePreset(_ name: String) {
        if isPresetSelected(name) {
            working.removeAll { $0.name == name }
        } else if canAddMore {
            working.append(.init(name: name))
        }
    }

    private func isPresetSelected(_ name: String) -> Bool {
        working.contains { $0.name == name }
    }

    private func addCustomMetric() {
        guard canAddCustom else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        working.append(.init(name: trimmed))
        newName = ""
    }

    private func removeMetric(_ id: UUID) {
        working.removeAll { $0.id == id }
    }

    private func moveMetricUp(_ index: Int) {
        guard working.indices.contains(index), index > 0 else { return }
        working.swapAt(index, index - 1)
    }

    private func moveMetricDown(_ index: Int) {
        guard working.indices.contains(index), index < working.count - 1 else { return }
        working.swapAt(index, index + 1)
    }

    private func moveMetricToTop(_ index: Int) {
        guard working.indices.contains(index), index > 0 else { return }
        let item = working.remove(at: index)
        working.insert(item, at: 0)
    }

    private func moveMetricToBottom(_ index: Int) {
        guard working.indices.contains(index), index < working.count - 1 else { return }
        let item = working.remove(at: index)
        working.append(item)
    }

    private func donePressed() {
        metrics = working
        onSave(working)
        dismiss()
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
                ForEach(dailyTotals, id: \.date) { item in
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

    static var shortHour: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "ha"
        return df
    }()

    static var shortDay: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }()
}

private extension Calendar {
    func isDateInFuture(_ date: Date) -> Bool {
        compare(date, to: Date(), toGranularity: .day) == .orderedDescending
    }
}
