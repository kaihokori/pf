//
//  SportsTabView.swift
//  Pump Fitness
//
//  Created by Kyle Graham on 8/12/2025.
//

import Combine
import SwiftUI
import CoreLocation
import MapKit
import WeatherKit
import Charts
import SwiftData

struct SportsTabView: View {
    @Binding var account: Account
    @Binding var sportConfigs: [SportConfig]
    @Binding var sportActivities: [SportActivityRecord]
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @AppStorage("timetracking.config") private var storedTimeTrackingConfigJSON: String = ""
    private let accountService = AccountFirestoreService()
    private let dayService = DayFirestoreService()
    @State private var showCalendar = false
    @Binding var selectedDate: Date
    @State private var showAccountsView = false
    @State private var showTimeTrackingEditor = false
    @State private var timeTrackingConfig = TimeTrackingConfig.defaultConfig
    @StateObject private var weatherModel = WeatherViewModel()
    @State private var teamMetrics: [TeamMetric] = TeamMetric.defaultMetrics
    @State private var soloMetrics: [SoloMetric] = SoloMetric.defaultMetrics
    @State private var teamMetricValuesStore: [String: String] = [:]
    @State private var teamHomeScore: Int = 0
    @State private var teamAwayScore: Int = 0
    @State private var showTeamMetricsEditor = false
    @State private var showSoloMetricsEditor = false
    @State private var showSportsEditor = false
    @State private var metricsEditorSportIndex: Int? = nil
    @State private var dataEntrySportIndex: Int? = nil
    @State private var editingSportRecord: SportActivityRecord? = nil
    @State private var dataEntryDefaultDate: Date? = nil
    @FocusState private var teamInputsFocused: Bool
    @FocusState private var soloInputsFocused: Bool
    @State private var hasLoadedTimeTrackingConfig = false
    @State private var hasLoadedSoloMetrics = false
    @State private var hasLoadedTeamMetrics = false
    @State private var hasLoadedSoloDay = false
    @State private var currentDay: Day? = nil
    @State private var soloMetricValuesStore: [String: String] = [:]
    // Track expanded state for each sport
    @State private var expandedSports: [Bool] = []

    // MARK: - Models

    struct SportActivity: Identifiable {
        let id = UUID()
        var recordId: String? = nil
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

        // Custom values keyed by metric key for user-defined metrics.
        var customValues: [String: Double] = [:]

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
        var color: Color
        var activities: [SportActivity]
        var metrics: [SportMetric]
    }

    struct SportPreset: Identifiable {
        let id = UUID()
        var name: String
        var color: Color
        var metrics: [SportMetric]
    }

    struct SportMetricPreset: Identifiable {
        let id = UUID()
        var key: String
        var label: String
        var unit: String
        var color: Color
        var valueTransform: ((SportActivity) -> Double)? = nil

        func metric() -> SportMetric {
            SportMetric(key: key, label: label, unit: unit, color: color, valueTransform: valueTransform)
        }
    }

    private static let metricPresets: [SportMetricPreset] = [
        .init(key: "distanceKm", label: "Distance", unit: "km", color: .blue),
        .init(key: "durationMin", label: "Duration", unit: "min", color: .green),
        .init(key: "speedKmh", label: "Speed", unit: "km/h", color: .orange),
        .init(key: "speedKmhComputed", label: "Speed (calc)", unit: "km/h", color: .orange, valueTransform: { $0.speedKmhComputed ?? 0 }),
        .init(key: "laps", label: "Laps", unit: "laps", color: .purple),
        .init(key: "attemptsMade", label: "Attempts Made", unit: "count", color: .teal),
        .init(key: "attemptsMissed", label: "Attempts Missed", unit: "count", color: .red),
        .init(key: "accuracy", label: "Accuracy", unit: "%", color: .yellow),
        .init(key: "accuracyComputed", label: "Accuracy (calc)", unit: "%", color: .yellow, valueTransform: { $0.accuracyComputed ?? 0 }),
        .init(key: "rounds", label: "Rounds", unit: "rounds", color: .indigo),
        .init(key: "roundDuration", label: "Round Duration", unit: "min", color: .mint),
        .init(key: "points", label: "Points", unit: "pts", color: .pink),
        .init(key: "holdTime", label: "Hold Time", unit: "sec", color: .cyan),
        .init(key: "poses", label: "Poses", unit: "poses", color: .brown),
        .init(key: "altitude", label: "Altitude", unit: "m", color: .gray),
        .init(key: "timeToPeak", label: "Time to Peak", unit: "min", color: .blue.opacity(0.7)),
        .init(key: "restTime", label: "Rest Time", unit: "min", color: .green.opacity(0.7))
    ]

    private static var metricPresetByKey: [String: SportMetricPreset] {
        Dictionary(uniqueKeysWithValues: metricPresets.map { ($0.key, $0) })
    }

    private static func metrics(forKeys keys: [String]) -> [SportMetric] {
        keys.compactMap { metricPresetByKey[$0]?.metric() }
    }

    private static let sportPresets: [SportPreset] = [
        .init(name: "Running", color: .blue, metrics: metrics(forKeys: ["distanceKm", "durationMin", "speedKmhComputed"])),
        .init(name: "Cycling", color: .green, metrics: metrics(forKeys: ["distanceKm", "durationMin", "speedKmhComputed"])),
        .init(name: "Swimming", color: .purple, metrics: metrics(forKeys: ["distanceKm", "laps", "durationMin"])),
        .init(name: "Team Sports", color: .teal, metrics: metrics(forKeys: ["durationMin", "attemptsMade", "attemptsMissed", "accuracyComputed"])),
        .init(name: "Martial Arts", color: .indigo, metrics: metrics(forKeys: ["rounds", "roundDuration", "points"])),
        .init(name: "Pilates/Yoga", color: .brown, metrics: metrics(forKeys: ["durationMin", "holdTime", "poses"])),
        .init(name: "Climbing", color: .gray, metrics: metrics(forKeys: ["altitude", "timeToPeak", "restTime", "durationMin"])),
        .init(name: "Padel", color: .pink, metrics: metrics(forKeys: ["durationMin", "attemptsMade", "points"])),
        .init(name: "Tennis", color: .orange, metrics: metrics(forKeys: ["durationMin", "attemptsMade", "attemptsMissed", "accuracy", "points"]))
    ]

    @State private var sports: [SportType] = []

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
        let isDaylight: Bool
    }

    // Weather visual grouping used across WeatherSection and surrounding layout
    private enum WeatherGroup {
        case clear, night, cloudy, rainy, snowy, other

        init(symbolName: String) {
            let s = symbolName.lowercased()
            if s.contains("moon") { self = .night }
            else if s.contains("snow") || s.contains("ice") || s.contains("hail") { self = .snowy }
            else if s.contains("rain") || s.contains("drizzle") || s.contains("thunder") { self = .rainy }
            else if s.contains("cloud") || s.contains("fog") || s.contains("overcast") { self = .cloudy }
            else if s.contains("sun") || s.contains("clear") { self = .clear }
            else { self = .other }
        }

        var gradient: LinearGradient {
            switch self {
            case .clear:
                return LinearGradient(colors: [.orange.opacity(0.18), .yellow.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .night:
                return LinearGradient(colors: [.indigo.opacity(0.18), .blue.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .cloudy:
                return LinearGradient(colors: [.gray.opacity(0.18), .blue.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .rainy:
                return LinearGradient(colors: [.blue.opacity(0.18), .indigo.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .snowy:
                return LinearGradient(colors: [.cyan.opacity(0.18), .white.opacity(0.36)], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .other:
                return LinearGradient(colors: [.teal.opacity(0.18), .gray.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }

        var iconName: String {
            switch self {
            case .clear: return "sun.max.fill"
            case .night: return "moon.stars.fill"
            case .cloudy: return "cloud.fill"
            case .rainy: return "cloud.rain.fill"
            case .snowy: return "snowflake"
            case .other: return "wind"
            }
        }
        
        var iconColor: Color {
            switch self {
            case .clear: return .orange
            case .night: return .yellow.opacity(0.9)
            case .cloudy: return .gray
            case .rainy: return .blue
            case .snowy: return .cyan
            case .other: return .teal
            }
        }
    }

    struct WeatherSection: View {
        @ObservedObject var viewModel: WeatherViewModel
        let selectedDate: Date

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                switch viewModel.state {
                case .idle, .loading:
                    HStack {
                        Spacer()
                        ProgressView().progressViewStyle(.circular)
                        Spacer()
                    }
                    .frame(height: 200)
                case .failed(let message):
                    VStack(alignment: .center, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text("Weather unavailable")
                            .font(.headline)
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                case .locationUnavailable:
                    EmptyView()
                case .loaded:
                    if let current = viewModel.currentSnapshot {
                        let group = WeatherGroup(symbolName: current.symbol)
                        let isNight = !current.isDaylight
                        let adjustedGroup: WeatherGroup = {
                            if isNight { return group }
                            if case .night = group {
                                let desc = current.description.lowercased()
                                if desc.contains("rain") || desc.contains("drizzle") || desc.contains("shower") { return .rainy }
                                if desc.contains("cloud") || desc.contains("fog") || desc.contains("overcast") { return .cloudy }
                                if desc.contains("snow") || desc.contains("sleet") || desc.contains("hail") { return .snowy }
                                if desc.contains("clear") || desc.contains("sun") { return .clear }
                                return .clear
                            }
                            return group
                        }()
                        
                        VStack(spacing: 0) {
                            if let region = viewModel.regionDescription {
                                Text(region)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.85))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 24)
                                    .padding(.top, 20)
                            }

                            // Main Info
                            HStack(alignment: .center) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(current.description.capitalized)
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(.white)
                                    
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Text("\(current.temperature)°")
                                            .font(.system(size: 64, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white)
                                        
                                        if let delta = current.temperatureDelta, delta != 0 {
                                            HStack(spacing: 2) {
                                                Image(systemName: delta > 0 ? "arrow.up" : "arrow.down")
                                                Text("\(abs(delta))°")
                                            }
                                            .font(.headline.weight(.bold))
                                            .foregroundStyle(.white)
                                        }
                                    }
                                    
                                    Text("H: \(current.max)°  L: \(current.min)°")
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.85))
                                }
                                
                                Spacer()
                                
                                Image(systemName: adjustedGroup.iconName)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 80, height: 80)
                                    .symbolRenderingMode(.multicolor)
                                    .shadow(color: Color.black.opacity(0.6), radius: 8, x: 0, y: 4)
                                }
                                .padding(.horizontal, 24)
                                .padding(.bottom, 24)
                                .padding(.top, viewModel.regionDescription == nil ? 24 : 12)
                            
                            // Metrics
                            HStack(spacing: 0) {
                                MetricItem(title: "Wind", value: "\(current.windSpeed)", unit: "km/h", icon: "wind")
                                Divider()
                                MetricItem(title: "Humidity", value: "\(current.humidity)", unit: "%", icon: "humidity")
                                Divider()
                                MetricItem(title: "Precip", value: "\(current.precipitationChance)", unit: "%", icon: "drop.fill")
                                Divider()
                                MetricItem(title: "UV Index", value: "\(current.uvIndex)", unit: uvCategory(for: current.uvIndex), icon: "sun.max.fill")
                            }
                            .padding(.vertical, 16)
                            
                            // Forecast
                            VStack(alignment: .leading, spacing: 12) {
                                Text(label(for: selectedDate))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .padding(.horizontal, 24)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(viewModel.upcomingSnapshots.prefix(12)) { snapshot in
                                            HourlyForecastCell(snapshot: snapshot)
                                        }
                                    }
                                    .padding(.horizontal, 24)
                                }
                            }
                            .padding(.bottom, 24)
                            .padding(.top, 16)
                        }
                    }
                }
            }
        }

        private func label(for date: Date) -> String {
            let calendar = Calendar.current
            if calendar.isDateInToday(date) { return "Forecast" }
            if calendar.isDateInTomorrow(date) { return "Tomorrow" }
            return DateFormatter.shortDay.string(from: date)
        }

        private func uvCategory(for index: Int) -> String {
            let clamped = max(index, 0)
            switch clamped {
            case ..<3: return "Low"
            case 3...5: return "Moderate"
            case 6...7: return "High"
            case 8...10: return "Very High"
            default: return "Extreme"
            }
        }
    }

    private struct MetricItem: View {
        let title: String
        let value: String
        let unit: String
        let icon: String
        
        var body: some View {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.white)
                Text(value)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity)
        }

    }

    private struct HourlyForecastCell: View {
        let snapshot: WeatherSnapshot
        
        var body: some View {
            VStack(spacing: 8) {
                Text(snapshot.label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                
                Image(systemName: snapshot.symbol)
                    .symbolRenderingMode(.monochrome)
                    .font(.title2)
                    .frame(height: 24)
                    .foregroundStyle(.white)
                
                Text("\(snapshot.temperature)°")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
        }
    }

    enum WeatherLoadState: Equatable {
        case idle
        case loading
        case loaded
        case locationUnavailable
        case failed(String)
    }

    @MainActor
    final class WeatherViewModel: ObservableObject {
        @Published var currentSnapshot: WeatherSnapshot?
        @Published var upcomingSnapshots: [WeatherSnapshot] = []
        @Published var state: WeatherLoadState = .idle
        @Published var regionDescription: String? = nil

        private let calendar = Calendar.current
        private let weatherService: WeatherService
        private let locationProvider: LocationProvider
        private let geocoder = CLGeocoder()

        init(weatherService: WeatherService? = nil, locationProvider: LocationProvider? = nil) {
            self.weatherService = weatherService ?? WeatherService()
            self.locationProvider = locationProvider ?? LocationProvider()
        }

        func refresh(for date: Date) async {
            state = .loading
            do {
                let location = try await locationProvider.currentLocation()
                await updateRegionDescription(for: location)
                if calendar.isDateInFuture(date) || calendar.isDateInToday(date) {
                    try await loadForecast(location: location, date: date)
                } else {
                    try await loadHistorical(location: location, date: date)
                }
                state = .loaded
            } catch {
                currentSnapshot = nil
                upcomingSnapshots = []
                regionDescription = nil
                if error is LocationError {
                    state = .locationUnavailable
                } else if let clError = error as? CLError, [.denied, .locationUnknown, .network].contains(clError.code) {
                    state = .locationUnavailable
                } else {
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
        }

        private func updateRegionDescription(for location: CLLocation) async {
            geocoder.cancelGeocode()
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(location)
                if let placemark = placemarks.first {
                    var components: [String] = []
                    if let locality = placemark.locality, !locality.isEmpty {
                        components.append(locality)
                    }
                    if let admin = placemark.administrativeArea, !admin.isEmpty {
                        components.append(admin)
                    } else if let country = placemark.country, !country.isEmpty {
                        components.append(country)
                    }
                    let description = components.joined(separator: ", ")
                    regionDescription = description.isEmpty ? nil : description
                } else {
                    regionDescription = nil
                }
            } catch {
                regionDescription = nil
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

            if calendar.isDateInToday(target) {
                let currentTemp = Int(current.temperature.value.rounded())
                let delta = deltaVsPreviousDay(for: target, currentTemp: currentTemp, daily: daily)
                currentSnapshot = makeSnapshot(date: target, hourTemp: anchor, current: current, day: dailyForecast(for: target, from: daily), delta: delta)
            } else if let anchor {
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
                description: (hourTemp?.condition.description ?? current.condition.description),
                isDaylight: hourTemp?.isDaylight ?? current.isDaylight
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
                description: hour.condition.description,
                isDaylight: hour.isDaylight
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
                                .padding(.top, 38)
                                .padding(.bottom, 8)

                                let _isNight = !(weatherModel.currentSnapshot?.isDaylight ?? true)
                                let adjustedGroup: WeatherGroup = {
                                    guard let snapshot = weatherModel.currentSnapshot else { return .other }
                                    let base = WeatherGroup(symbolName: snapshot.symbol)
                                    if _isNight { return base }
                                    if case .night = base {
                                        let desc = snapshot.description.lowercased()
                                        if desc.contains("rain") || desc.contains("drizzle") || desc.contains("shower") { return .rainy }
                                        if desc.contains("cloud") || desc.contains("fog") || desc.contains("overcast") { return .cloudy }
                                        if desc.contains("snow") || desc.contains("sleet") || desc.contains("hail") { return .snowy }
                                        if desc.contains("clear") || desc.contains("sun") { return .clear }
                                        return .clear
                                    }
                                    return base
                                }()
                                let _overlayOpacity = (_isNight ? 0.45 : 0.28)
                                let _imageName: String = {
                                    switch adjustedGroup {
                                    case .clear: return _isNight ? "weather_clear_night" : "weather_clear_day"
                                    case .rainy: return _isNight ? "weather_rainy_night" : "weather_rainy_day"
                                    case .cloudy: return _isNight ? "weather_cloudy_night" : "weather_cloudy_day"
                                    case .snowy: fallthrough
                                    case .other: fallthrough
                                    case .night: return _isNight ? "weather_clear_night" : "weather_clear_day"
                                    }
                                }()

                                WeatherSection(viewModel: weatherModel, selectedDate: selectedDate)
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 18)
                                    .background {
                                        ZStack {
                                            Image(_imageName)
                                                .resizable()
                                                .scaledToFill()
                                                .clipped()
                                                .blur(radius: 5)
                                            // stronger dark scrim for better contrast
                                            LinearGradient(colors: [Color.black.opacity(0.0), Color.black.opacity(_overlayOpacity)], startPoint: .top, endPoint: .bottom)
                                        }
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 16.0, style: .continuous))
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
                            .padding(.top, 38)
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
                            .padding(.top, 38)
                            .padding(.bottom, 8)

                            TeamPlaySection(
                                selectedDate: selectedDate,
                                metrics: $teamMetrics,
                                metricValues: $teamMetricValuesStore,
                                homeScore: $teamHomeScore,
                                awayScore: $teamAwayScore,
                                focusBinding: $teamInputsFocused,
                                onValueChange: handleTeamMetricValueChange,
                                onScoreChange: handleTeamScoreChange
                            )
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
                            .padding(.top, 38)
                            .padding(.bottom, 8)

                           SoloPlaySection(
                               selectedDate: selectedDate,
                               metrics: $soloMetrics,
                               metricValues: $soloMetricValuesStore,
                               focusBinding: $soloInputsFocused,
                               onValueChange: handleSoloMetricValueChange
                           )
                               .padding(.horizontal, 18)

                            HStack {
                                Text("Sports Tracking")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)

                                Spacer()

                                Button {
                                    showSportsEditor = true
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
                            .padding(.top, 38)
                            .padding(.bottom, 8)

                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(Array(sports.enumerated()), id: \.offset) { idx, sport in
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack(spacing: 10) {
                                            Circle()
                                                .fill(sport.color)
                                                .frame(width: 16, height: 16)

                                            Text(sport.name)
                                                .font(.callout.weight(.semibold))
                                                .multilineTextAlignment(.leading)

                                            Spacer()

                                            Button {
                                                metricsEditorSportIndex = idx
                                            } label: {
                                                Image(systemName: "pencil")
                                                    .font(.callout.weight(.semibold))
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 6)
                                                    .glassEffect(in: .rect(cornerRadius: 14.0))
                                                    .accessibilityLabel("Edit sport metrics")
                                            }
                                            .buttonStyle(.plain)

                                            Image(systemName: (idx < expandedSports.count && expandedSports[idx]) ? "chevron.up" : "chevron.down")
                                                .font(.callout.weight(.semibold))
                                                .accessibilityHidden(true)
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
                                                    historyDays: historyDays,
                                                    anchorDate: selectedDate
                                                )
                                                .frame(height: 140)
                                                .padding(.bottom, 8)
                                            }

                                            let weekDates = sportWeekDates(anchor: selectedDate)
                                            let sportRecords = sportActivities.filter { $0.sportName.lowercased() == sport.name.lowercased() }

                                            VStack(spacing: 0) {
                                                ForEach(weekDates, id: \.self) { day in
                                                    let dayRecords = sportRecords.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }

                                                    Section(header:
                                                        HStack {
                                                            VStack(alignment: .leading, spacing: 2) {
                                                                Text(DateFormatter.sportWeekdayFull.string(from: day))
                                                                    .font(.subheadline.weight(.semibold))
                                                                Text(DateFormatter.sportLongDate.string(from: day))
                                                                    .font(.caption2)
                                                                    .foregroundStyle(.secondary)
                                                            }
                                                            Spacer()
                                                        }
                                                        .padding(.vertical, 8)
                                                    ) {
                                                        if dayRecords.isEmpty {
                                                            Text("No sports entries")
                                                                .font(.caption2)
                                                                .foregroundStyle(.secondary)
                                                                .padding(.vertical, 8)
                                                        } else {
                                                            ForEach(dayRecords, id: \.id) { record in
                                                                HStack(alignment: .top, spacing: 12) {
                                                                    VStack(alignment: .leading, spacing: 6) {
                                                                        ForEach(record.values, id: \.id) { val in
                                                                            HStack(spacing: 6) {
                                                                                Text(val.label)
                                                                                    .font(.caption.weight(.semibold))
                                                                                    .foregroundStyle(.secondary)
                                                                                Text(formatMetricValue(val))
                                                                                    .font(.caption)
                                                                            }
                                                                        }
                                                                    }

                                                                    Spacer()

                                                                    Menu {
                                                                        Button("Edit") {
                                                                            editingSportRecord = record
                                                                            dataEntrySportIndex = idx
                                                                            dataEntryDefaultDate = record.date
                                                                        }
                                                                        Button("Delete", role: .destructive) {
                                                                            sportActivities.removeAll { $0.id == record.id }
                                                                            rebuildSports()
                                                                        }
                                                                    } label: {
                                                                        Image(systemName: "ellipsis.circle")
                                                                            .font(.callout)
                                                                            .foregroundStyle(.primary)
                                                                    }
                                                                    .menuStyle(.borderlessButton)
                                                                }
                                                                .padding(.vertical, 8)
                                                                if record.id != dayRecords.last?.id {
                                                                    Divider()
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                            .padding(.horizontal, 8)

                                            Button {
                                                dataEntrySportIndex = idx
                                                editingSportRecord = nil
                                                dataEntryDefaultDate = selectedDate
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
                persistTeamMetrics(updated)
            }
        }
        .sheet(isPresented: $showSoloMetricsEditor) {
            SoloPlayMetricsEditorSheet(metrics: $soloMetrics) { updated in
                persistSoloMetrics(updated)
            }
        }
        .sheet(isPresented: $showSportsEditor) {
            SportsEditorSheet(sports: $sports, presets: Self.sportPresets) { updated in
                sports = updated
                sportConfigs = configs(from: updated)
                expandedSports = Array(repeating: false, count: updated.count)
            }
        }
        .sheet(
            isPresented: Binding(
                get: { metricsEditorSportIndex != nil },
                set: { newValue in if !newValue { metricsEditorSportIndex = nil } }
            )
        ) {
            if let idx = metricsEditorSportIndex, sports.indices.contains(idx) {
                SportMetricsEditorSheet(
                    sportName: sports[idx].name,
                    metrics: $sports[idx].metrics,
                    presets: Self.metricPresets,
                    accent: sports[idx].color
                ) { updated in
                    sports[idx].metrics = updated
                    sportConfigs = configs(from: sports)
                }
            }
        }
        .sheet(
            isPresented: Binding(
                get: { dataEntrySportIndex != nil || editingSportRecord != nil },
                set: { newValue in if !newValue { dataEntrySportIndex = nil; editingSportRecord = nil; dataEntryDefaultDate = nil } }
            )
        ) {
            let idx: Int? = {
                if let i = dataEntrySportIndex { return i }
                if let record = editingSportRecord {
                    return sports.firstIndex { $0.name.lowercased() == record.sportName.lowercased() }
                }
                return nil
            }()

            if let idx, sports.indices.contains(idx) {
                let baseDate = dataEntryDefaultDate ?? editingSportRecord?.date ?? selectedDate
                let existingActivity = editingSportRecord.map { activity(from: $0) }
                SportDataEntrySheet(
                    sportName: sports[idx].name,
                    metrics: sports[idx].metrics,
                    defaultDate: baseDate,
                    accent: sports[idx].color,
                    existingActivity: existingActivity
                ) { activity in
                    let record = record(from: activity, metrics: sports[idx].metrics, sportName: sports[idx].name, color: sports[idx].color, existingId: activity.recordId)
                    if let existingId = activity.recordId, let existingIndex = sportActivities.firstIndex(where: { $0.id == existingId }) {
                        sportActivities[existingIndex] = record
                    } else {
                        sportActivities.append(record)
                    }
                    dataEntrySportIndex = nil
                    editingSportRecord = nil
                    dataEntryDefaultDate = nil
                    rebuildSports()
                } onCancel: {
                    dataEntrySportIndex = nil
                    editingSportRecord = nil
                    dataEntryDefaultDate = nil
                }
            }
        }
        .onAppear {
            rebuildSports()
            loadTimeTrackingConfigFromStorage()
            loadTeamMetricsFromAccount()
            loadSoloMetricsFromAccount()
            loadDayForSelectedDate()
        }
        .task {
            await weatherModel.refresh(for: selectedDate)
        }
        .onChange(of: selectedDate) { _, newValue in
            Task { await weatherModel.refresh(for: newValue) }
            currentDay = nil
            hasLoadedSoloDay = false
            soloMetricValuesStore = [:]
            teamMetricValuesStore = [:]
            teamHomeScore = 0
            teamAwayScore = 0
            loadDayForSelectedDate()
        }
        .onChange(of: sportConfigs) { _, _ in rebuildSports() }
        .onChange(of: sportActivities) { _, _ in rebuildSports() }
        .onChange(of: soloMetrics) { _, _ in
            syncSoloMetricStoreWithMetrics()
            ensureCurrentDay().ensureSoloMetricValues(for: soloMetrics)
            persistDayIfLoaded()
        }
        .onChange(of: teamMetrics) { _, _ in
            syncTeamMetricStoreWithMetrics()
            ensureCurrentDay().ensureTeamMetricValues(for: teamMetrics)
            persistDayIfLoaded()
            persistTeamMetrics(teamMetrics)
        }
        .safeAreaInset(edge: .bottom) {
            KeyboardDismissBar(
                isVisible: teamInputsFocused || soloInputsFocused,
                onDismiss: {
                    teamInputsFocused = false
                    soloInputsFocused = false
                }
            )
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

// MARK: - Solo metrics persistence
private extension SportsTabView {
    func loadSoloMetricsFromAccount() {
        guard !hasLoadedSoloMetrics else { return }
        let source = account.soloMetrics
        soloMetrics = source.isEmpty ? SoloMetric.defaultMetrics : source
        hasLoadedSoloMetrics = true
        syncSoloMetricStoreWithMetrics()
    }

    func loadTeamMetricsFromAccount() {
        guard !hasLoadedTeamMetrics else { return }
        let source = account.teamMetrics
        teamMetrics = source.isEmpty ? TeamMetric.defaultMetrics : source
        hasLoadedTeamMetrics = true
        syncTeamMetricStoreWithMetrics()
    }

    func persistSoloMetrics(_ metrics: [SoloMetric]) {
        soloMetrics = metrics
        account.soloMetrics = metrics
        syncSoloMetricStoreWithMetrics()
        if hasLoadedSoloDay {
            let day = ensureCurrentDay()
            day.ensureSoloMetricValues(for: metrics)
            persistDayIfLoaded()
        }
        accountService.saveAccount(account) { success in
            if !success {
                print("Failed to save solo metrics")
            }
        }
    }

    func persistTeamMetrics(_ metrics: [TeamMetric]) {
        teamMetrics = metrics
        account.teamMetrics = metrics
        syncTeamMetricStoreWithMetrics()
        if hasLoadedSoloDay {
            let day = ensureCurrentDay()
            day.ensureTeamMetricValues(for: metrics)
            persistDayIfLoaded()
        }
        accountService.saveAccount(account) { success in
            if !success {
                print("Failed to save team metrics")
            }
        }
    }

    func loadDayForSelectedDate() {
        guard !hasLoadedSoloDay else { return }
        dayService.fetchDay(
            for: selectedDate,
            in: modelContext,
            trackedMacros: account.trackedMacros,
            soloMetrics: soloMetrics,
            teamMetrics: teamMetrics
        ) { day in
            DispatchQueue.main.async {
                let resolved = day ?? Day.fetchOrCreate(for: selectedDate, in: modelContext, trackedMacros: account.trackedMacros, soloMetrics: soloMetrics, teamMetrics: teamMetrics)
                resolved.ensureSoloMetricValues(for: soloMetrics)
                resolved.ensureTeamMetricValues(for: teamMetrics)
                currentDay = resolved
                syncSoloMetricStoreWithMetrics()
                syncTeamMetricStoreWithMetrics()
                teamHomeScore = resolved.teamHomeScore
                teamAwayScore = resolved.teamAwayScore
                hasLoadedSoloDay = true
            }
        }
    }

    func ensureCurrentDay() -> Day {
        if let day = currentDay {
            return day
        }
        let created = Day.fetchOrCreate(for: selectedDate, in: modelContext, trackedMacros: account.trackedMacros, soloMetrics: soloMetrics, teamMetrics: teamMetrics)
        currentDay = created
        hasLoadedSoloDay = true
        return created
    }

    func syncSoloMetricStoreWithMetrics() {
        let validIds = Set(soloMetrics.map { $0.id })
        soloMetricValuesStore = soloMetricValuesStore.filter { validIds.contains($0.key) }

        // Prefer current day's stored values; fall back to 0
        let dayValues: [String: Double] = {
            guard let day = currentDay else { return [:] }
            return Dictionary(uniqueKeysWithValues: day.soloMetricValues.map { ($0.metricId, $0.value) })
        }()

        for metric in soloMetrics {
            if let value = dayValues[metric.id] {
                soloMetricValuesStore[metric.id] = String(value)
            } else if soloMetricValuesStore[metric.id] == nil {
                soloMetricValuesStore[metric.id] = "0"
            }
        }
    }

    func syncTeamMetricStoreWithMetrics() {
        let validIds = Set(teamMetrics.map { $0.id })
        teamMetricValuesStore = teamMetricValuesStore.filter { validIds.contains($0.key) }

        let dayValues: [String: Double] = {
            guard let day = currentDay else { return [:] }
            return Dictionary(uniqueKeysWithValues: day.teamMetricValues.map { ($0.metricId, $0.value) })
        }()

        for metric in teamMetrics {
            if let value = dayValues[metric.id] {
                teamMetricValuesStore[metric.id] = String(value)
            } else if teamMetricValuesStore[metric.id] == nil {
                teamMetricValuesStore[metric.id] = "0"
            }
        }
    }

    func handleSoloMetricValueChange(_ metric: SoloMetric, rawValue: String) {
        let day = ensureCurrentDay()
        day.ensureSoloMetricValues(for: soloMetrics)
        let value = Double(rawValue) ?? 0
        if let idx = day.soloMetricValues.firstIndex(where: { $0.metricId == metric.id }) {
            day.soloMetricValues[idx].metricName = metric.name
            day.soloMetricValues[idx].value = value
        } else {
            day.soloMetricValues.append(SoloMetricValue(metricId: metric.id, metricName: metric.name, value: value))
        }
        persistDayIfLoaded()
    }

    func handleTeamMetricValueChange(_ metric: TeamMetric, rawValue: String) {
        let day = ensureCurrentDay()
        day.ensureTeamMetricValues(for: teamMetrics)
        let value = Double(rawValue) ?? 0
        if let idx = day.teamMetricValues.firstIndex(where: { $0.metricId == metric.id }) {
            day.teamMetricValues[idx].metricName = metric.name
            day.teamMetricValues[idx].value = value
        } else {
            day.teamMetricValues.append(TeamMetricValue(metricId: metric.id, metricName: metric.name, value: value))
        }
        persistDayIfLoaded()
    }

    func handleTeamScoreChange(_ home: Int, _ away: Int) {
        let day = ensureCurrentDay()
        day.teamHomeScore = home
        day.teamAwayScore = away
        persistDayIfLoaded()
    }

    func persistDayIfLoaded() {
        guard let day = currentDay else { return }
        do {
            try modelContext.save()
        } catch {
            print("SportsTabView: failed to save Day locally: \(error)")
        }

        dayService.saveDay(day) { success in
            if !success {
                print("SportsTabView: failed to sync Day to Firestore")
            }
        }
    }
}

// MARK: - Activity hydration & persistence helpers

private extension SportsTabView {
    func rebuildSports() {
        let grouped = Dictionary(grouping: sportActivities) { $0.sportName.lowercased() }
        // Preserve previous expanded state by sport name so adding/updating records doesn't collapse open rows
        let previousExpansion: [String: Bool] = Dictionary(uniqueKeysWithValues: zip(sports.map { $0.name.lowercased() }, expandedSports))
        let baseTypes = sportsFromConfigs(sportConfigs, fallbackActivities: [])

        var built: [SportType] = baseTypes.map { base in
            let records = grouped[base.name.lowercased()] ?? []
            let recordMetrics = metrics(from: records, fallbackColor: base.color)
            let mergedMetrics = mergeMetrics(base: base.metrics, additional: recordMetrics)
            let activities = records.map { activity(from: $0) }
            return SportType(name: base.name, color: base.color, activities: activities, metrics: mergedMetrics)
        }

        for (nameLower, records) in grouped where !built.contains(where: { $0.name.lowercased() == nameLower }) {
            guard let first = records.first else { continue }
            let color = Color(hex: first.colorHex) ?? .accentColor
            let recordMetrics = metrics(from: records, fallbackColor: color)
            let activities = records.map { activity(from: $0) }
            built.append(SportType(name: first.sportName, color: color, activities: activities, metrics: recordMetrics))
        }

        if built.isEmpty {
            built = sportsFromConfigs(sportConfigs, fallbackActivities: [])
        }

        sports = built
        expandedSports = built.map { previousExpansion[$0.name.lowercased()] ?? false }
    }

    func metrics(from records: [SportActivityRecord], fallbackColor: Color) -> [SportMetric] {
        var byKey: [String: SportMetric] = [:]
        for record in records {
            for value in record.values where byKey[value.key] == nil {
                let color = Color(hex: value.colorHex) ?? fallbackColor
                byKey[value.key] = SportMetric(
                    key: value.key,
                    label: value.label,
                    unit: value.unit,
                    color: color,
                    valueTransform: Self.metricPresetByKey[value.key]?.valueTransform
                )
            }
        }
        return Array(byKey.values)
    }

    func sportWeekDates(anchor: Date) -> [Date] {
        let cal = Calendar.current
        let anchorDay = cal.startOfDay(for: anchor)
        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: anchorDay)
        comps.weekday = 2 // Monday
        guard let startOfWeek = cal.date(from: comps) else { return [] }
        return (0..<historyDays).compactMap { offset in
            cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: startOfWeek))
        }
    }
    func mergeMetrics(base: [SportMetric], additional: [SportMetric]) -> [SportMetric] {
        var merged = base
        let existingKeys = Set(base.map { $0.key })
        for metric in additional where !existingKeys.contains(metric.key) {
            merged.append(metric)
        }
        return merged
    }

    func activity(from record: SportActivityRecord) -> SportActivity {
        var activity = SportActivity(recordId: record.id, date: record.date)
        for value in record.values {
            switch value.key {
            case "distanceKm": activity.distanceKm = value.value
            case "durationMin": activity.durationMin = value.value
            case "speedKmh", "speedKmhComputed": activity.speedKmh = value.value
            case "laps": activity.laps = Int(value.value)
            case "attemptsMade": activity.attemptsMade = Int(value.value)
            case "attemptsMissed": activity.attemptsMissed = Int(value.value)
            case "accuracy", "accuracyComputed": activity.accuracy = value.value
            case "rounds": activity.rounds = Int(value.value)
            case "roundDuration": activity.roundDuration = value.value
            case "points": activity.points = Int(value.value)
            case "holdTime": activity.holdTime = value.value
            case "poses": activity.poses = Int(value.value)
            case "altitude": activity.altitude = value.value
            case "timeToPeak": activity.timeToPeak = value.value
            case "restTime": activity.restTime = value.value
            default:
                activity.customValues[value.key] = value.value
            }
        }
        return activity
    }

    func record(from activity: SportActivity, metrics: [SportMetric], sportName: String, color: Color, existingId: String? = nil) -> SportActivityRecord {
        let values: [SportMetricValue] = metrics.map { metric in
            let value = metricValue(metric, in: activity)
            let colorHex = metric.color.toHexString(fallback: color.toHexString())
            return SportMetricValue(key: metric.key, label: metric.label, unit: metric.unit, colorHex: colorHex, value: value)
        }

        return SportActivityRecord(
            id: existingId ?? activity.recordId ?? UUID().uuidString,
            sportName: sportName,
            colorHex: color.toHexString(),
            date: activity.date,
            values: values
        )
    }

    func metricValue(_ metric: SportMetric, in activity: SportActivity) -> Double {
        switch metric.key {
        case "distanceKm": return activity.distanceKm ?? 0
        case "durationMin": return activity.durationMin ?? 0
        case "speedKmh": return activity.speedKmh ?? 0
        case "speedKmhComputed": return activity.speedKmhComputed ?? activity.speedKmh ?? 0
        case "laps": return Double(activity.laps ?? 0)
        case "attemptsMade": return Double(activity.attemptsMade ?? 0)
        case "attemptsMissed": return Double(activity.attemptsMissed ?? 0)
        case "accuracy": return activity.accuracy ?? activity.accuracyComputed ?? 0
        case "accuracyComputed": return activity.accuracyComputed ?? activity.accuracy ?? 0
        case "rounds": return Double(activity.rounds ?? 0)
        case "roundDuration": return activity.roundDuration ?? 0
        case "points": return Double(activity.points ?? 0)
        case "holdTime": return activity.holdTime ?? 0
        case "poses": return Double(activity.poses ?? 0)
        case "altitude": return activity.altitude ?? 0
        case "timeToPeak": return activity.timeToPeak ?? 0
        case "restTime": return activity.restTime ?? 0
        default: return activity.customValues[metric.key] ?? 0
        }
    }

    func formatMetricValue(_ value: SportMetricValue) -> String {
        let intVal = Int(value.value)
        let numberString: String
        if Double(intVal) == value.value {
            numberString = String(intVal)
        } else {
            numberString = String(format: "%.2f", value.value)
        }
        if value.unit.isEmpty { return numberString }
        return "\(numberString) \(value.unit)"
    }
}

// MARK: - Solo Play

fileprivate struct SoloPlaySection: View {
    let selectedDate: Date

    @Binding var metrics: [SoloMetric]
    @Binding var metricValues: [String: String]
    var focusBinding: FocusState<Bool>.Binding
    var onValueChange: (SoloMetric, String) -> Void

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
                                .textInputAutocapitalization(.none)
                                .keyboardType(.decimalPad)
                                .focused(focusBinding)
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
            set: {
                metricValues[metric.id] = $0
                onValueChange(metric, $0)
            }
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
                                ForEach($working, id: \.id) { $metric in
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(Color.accentColor.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                            .overlay(Image(systemName: "figure.walk.motion")
                                                .foregroundStyle(Color.accentColor))

                                        VStack {
                                            TextField("Metric name", text: $metric.name)
                                                .font(.subheadline.weight(.semibold))

                                            HStack {
                                                Menu {
                                                    Button("Top") { moveMetricToTop(metric.id) }
                                                    Button("Up") { moveMetricUp(metric.id) }
                                                    Button("Down") { moveMetricDown(metric.id) }
                                                    Button("Bottom") { moveMetricToBottom(metric.id) }
                                                } label: {
                                                    Label("Reorder", systemImage: "arrow.up.arrow.down")
                                                        .font(.footnote.weight(.semibold))
                                                }

                                                Spacer()

                                                Button(role: .destructive) {
                                                    removeMetric(metric.id)
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
                            Text("Quick Add")
                                .font(.subheadline.weight(.semibold))

                            VStack(spacing: 12) {
                                ForEach(presets.filter { !isPresetSelected($0) }, id: \.self) { preset in
                                    HStack(spacing: 14) {
                                        Circle()
                                            .fill(Color.accentColor.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                            .overlay(
                                                Image(systemName: "figure.walk.motion")
                                                    .foregroundStyle(Color.accentColor)
                                            )

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(preset)
                                                .font(.subheadline.weight(.semibold))
                                        }

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
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                                }
                            }
                        }
                    }

                    Button(action: { /* TODO: present upgrade flow */ }) {
                        HStack(alignment: .center) {
                            Image(systemName: "sparkles")
                                .font(.title3)
                                .foregroundStyle(Color.accentColor)
                                .padding(.trailing, 8)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Upgrade to Pro")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)

                                Text("Unlock more grocery slots + other benefits")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .surfaceCard(16)
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Add Custom Metric")
                            .font(.subheadline.weight(.semibold))

                        HStack(spacing: 10) {
                            TextField("Enter name", text: $newName)
                                .textInputAutocapitalization(.words)
                                .padding()
                                .surfaceCard(14)
                            
                            Button(action: addCustomMetric) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                            .buttonStyle(.plain)
                            .disabled(!canAddCustom)
                            .opacity(!canAddCustom ? 0.4 : 1)
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

    private func removeMetric(_ id: String) {
        working.removeAll { $0.id == id }
    }

    private func moveMetricUp(_ id: String) {
        guard let index = working.firstIndex(where: { $0.id == id }), index > 0 else { return }
        working.swapAt(index, index - 1)
    }

    private func moveMetricDown(_ id: String) {
        guard let index = working.firstIndex(where: { $0.id == id }), index < working.count - 1 else { return }
        working.swapAt(index, index + 1)
    }

    private func moveMetricToTop(_ id: String) {
        guard let index = working.firstIndex(where: { $0.id == id }), index > 0 else { return }
        let item = working.remove(at: index)
        working.insert(item, at: 0)
    }

    private func moveMetricToBottom(_ id: String) {
        guard let index = working.firstIndex(where: { $0.id == id }), index < working.count - 1 else { return }
        let item = working.remove(at: index)
        working.append(item)
    }

    private func donePressed() {
        metrics = working
        onSave(working)
        dismiss()
    }
}

// Safe-area inset dismiss bar that mirrors the weights tracking behavior
private struct KeyboardDismissBar: View {
    var isVisible: Bool
    var onDismiss: () -> Void

    var body: some View {
        Group {
            if isVisible {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Label("Dismiss", systemImage: "keyboard.chevron.compact.down")
                            .font(.callout.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: Capsule())
                            .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
                .padding(.bottom, 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.2), value: isVisible)
            } else {
                EmptyView()
                    .frame(height: 0)
            }
        }
    }
}

// MARK: - Team Play

fileprivate struct TeamPlaySection: View {
    let selectedDate: Date

    @Binding var metrics: [TeamMetric]
    @Binding var metricValues: [String: String]
    @Binding var homeScore: Int
    @Binding var awayScore: Int
    var focusBinding: FocusState<Bool>.Binding
    var onValueChange: (TeamMetric, String) -> Void
    var onScoreChange: (Int, Int) -> Void

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
                                    .textInputAutocapitalization(.none)
                                    .keyboardType(.decimalPad)
                                    .focused(focusBinding)
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
        .onChange(of: homeScore) { _, _ in onScoreChange(homeScore, awayScore) }
        .onChange(of: awayScore) { _, _ in onScoreChange(homeScore, awayScore) }
    }

    private func valueBinding(for metric: TeamMetric) -> Binding<String> {
        Binding(
            get: { metricValues[metric.id] ?? "" },
            set: {
                metricValues[metric.id] = $0
                onValueChange(metric, $0)
            }
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

                    Button(action: { /* TODO: present upgrade flow */ }) {
                        HStack(alignment: .center) {
                            Image(systemName: "sparkles")
                                .font(.title3)
                                .foregroundStyle(Color.accentColor)
                                .padding(.trailing, 8)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Upgrade to Pro")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)

                                Text("Unlock more grocery slots + other benefits")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .surfaceCard(16)
                    }
                    .buttonStyle(.plain)

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

    private func removeMetric(_ id: String) {
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

// Lightweight section header used by editor sheets (mirrors MacroEditorSheet styling)
private struct MacroEditorSectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}

// MARK: - Sports & Metrics Editors

private struct SportsEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var sports: [SportsTabView.SportType]
    let presets: [SportsTabView.SportPreset]
    var onSave: ([SportsTabView.SportType]) -> Void

    @State private var working: [SportsTabView.SportType] = []
    @State private var newName: String = ""
    @State private var newColor: Color = .accentColor
    @State private var hasLoaded = false
    @State private var showColorPickerSheet = false
    @State private var colorPickerSportID: UUID? = nil

    private var availablePresets: [SportsTabView.SportPreset] {
        presets.filter { preset in
            !working.contains { $0.name.caseInsensitiveCompare(preset.name) == .orderedSame }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Tracked sports
                    if !working.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            MacroEditorSectionHeader(title: "Tracked Sports")
                            VStack(spacing: 12) {
                                ForEach(Array(working.enumerated()), id: \.element.id) { idx, sport in
                                    let binding = $working[idx]
                                    HStack(spacing: 12) {
                                        Button(action: {
                                            colorPickerSportID = sport.id
                                            showColorPickerSheet = true
                                        }) {
                                            Circle()
                                                .fill(binding.color.wrappedValue.opacity(0.15))
                                                .frame(width: 44, height: 44)
                                                .overlay(
                                                    Image(systemName: "sportscourt")
                                                        .foregroundStyle(binding.color.wrappedValue)
                                                )
                                        }
                                        .buttonStyle(.plain)

                                        VStack(alignment: .leading, spacing: 6) {
                                            TextField("Name", text: binding.name)
                                                .font(.subheadline.weight(.semibold))
                                        }

                                        Spacer()

                                        Button(role: .destructive) {
                                            removeSport(sport.id)
                                        } label: {
                                            Image(systemName: "trash")
                                                .foregroundStyle(.red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .surfaceCard(12)
                                }
                            }
                        }
                    }

                    // Quick Add
                    if !availablePresets.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            MacroEditorSectionHeader(title: "Quick Add")
                            VStack(spacing: 12) {
                                ForEach(availablePresets) { preset in
                                    HStack(spacing: 14) {
                                        Circle()
                                            .fill(preset.color.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                            .overlay(
                                                Image(systemName: "sportscourt")
                                                    .foregroundStyle(preset.color)
                                            )

                                        VStack(alignment: .leading) {
                                            Text(preset.name)
                                                .font(.subheadline.weight(.semibold))
                                            Text("\(preset.metrics.count) default values")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Button {
                                            addPreset(preset)
                                        } label: {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 24, weight: .semibold))
                                                .foregroundStyle(preset.color)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .surfaceCard(18)
                                }
                            }
                        }
                    }

                    // Custom composer
                    VStack(alignment: .leading, spacing: 12) {
                        MacroEditorSectionHeader(title: "Custom Sports")
                        HStack(spacing: 12) {
                            TextField("Sport name", text: $newName)
                                .textInputAutocapitalization(.words)
                                .padding()
                                .surfaceCard(16)

                            Button(action: addCustomSport) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(newColor)
                            }
                            .buttonStyle(.plain)
                            .disabled(!canAddCustomSport)
                            .opacity(!canAddCustomSport ? 0.4 : 1)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("Edit Sports")
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

    private var canAddCustomSport: Bool {
        !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func loadInitial() {
        guard !hasLoaded else { return }
        working = sports
        hasLoaded = true
    }

    private func addPreset(_ preset: SportsTabView.SportPreset) {
        working.append(
            SportsTabView.SportType(
                name: preset.name,
                color: preset.color,
                activities: [],
                metrics: preset.metrics
            )
        )
    }

    private func addCustomSport() {
        guard canAddCustomSport else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        working.append(
            SportsTabView.SportType(
                name: trimmed,
                color: newColor,
                activities: [],
                metrics: []
            )
        )
        newName = ""
    }

    private func removeSport(_ id: UUID) {
        working.removeAll { $0.id == id }
    }

    private func applyColor(hex: String) {
        guard let target = colorPickerSportID else { return }
        guard let idx = working.firstIndex(where: { $0.id == target }) else { return }
        if let col = Color(hex: hex) {
            working[idx].color = col
        }
    }

    private func donePressed() {
        sports = working
        onSave(working)
        dismiss()
    }
}

private struct SportMetricsEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let sportName: String
    @Binding var metrics: [SportsTabView.SportMetric]
    let presets: [SportsTabView.SportMetricPreset]
    var accent: Color
    var onSave: ([SportsTabView.SportMetric]) -> Void

    @State private var working: [SportsTabView.SportMetric] = []
    @State private var newName: String = ""
    @State private var newUnit: String = ""
    @State private var newColor: Color = .accentColor
    @State private var hasLoaded = false
    @State private var showColorPickerSheet = false
    @State private var colorPickerMetricID: UUID? = nil

    private var availablePresets: [SportsTabView.SportMetricPreset] {
        let existingKeys = Set(working.map { $0.key })
        return presets.filter { !existingKeys.contains($0.key) }
    }

    private var canAddCustomMetric: Bool {
        !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !newUnit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    if !working.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            MacroEditorSectionHeader(title: "Tracked Values")
                            VStack(spacing: 12) {
                                ForEach(Array(working.enumerated()), id: \.element.id) { idx, metric in
                                    let binding = $working[idx]
                                    HStack(spacing: 12) {
                                        Button(action: {
                                            colorPickerMetricID = metric.id
                                            showColorPickerSheet = true
                                        }) {
                                            Circle()
                                                .fill(binding.color.wrappedValue.opacity(0.15))
                                                .frame(width: 44, height: 44)
                                                .overlay(
                                                    Image(systemName: "chart.bar.fill")
                                                        .foregroundStyle(binding.color.wrappedValue)
                                                )
                                        }
                                        .buttonStyle(.plain)

                                        VStack(alignment: .leading, spacing: 6) {
                                            TextField("Name", text: binding.label)
                                                .font(.subheadline.weight(.semibold))
                                            TextField("Unit (e.g. km, min)", text: binding.unit)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Button(role: .destructive) {
                                            removeMetric(metric.id)
                                        } label: {
                                            Image(systemName: "trash")
                                                .foregroundStyle(.red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .surfaceCard(14)
                                }
                            }
                        }
                    }

                    if !availablePresets.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            MacroEditorSectionHeader(title: "Quick Add")
                            VStack(spacing: 12) {
                                ForEach(availablePresets) { preset in
                                    HStack(spacing: 14) {
                                        Circle()
                                            .fill(preset.color.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                            .overlay(
                                                Image(systemName: "chart.bar.fill")
                                                    .foregroundStyle(preset.color)
                                            )

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(preset.label)
                                                .font(.subheadline.weight(.semibold))
                                            Text(preset.unit)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Button {
                                            addPreset(preset)
                                        } label: {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 24, weight: .semibold))
                                                .foregroundStyle(preset.color)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .surfaceCard(18)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        MacroEditorSectionHeader(title: "Custom Values")
                        VStack(spacing: 12) {
                            TextField("Value name", text: $newName)
                                .textInputAutocapitalization(.words)
                                .padding()
                                .surfaceCard(16)
                            HStack(spacing: 12) {
                                TextField("Unit (e.g. pts, km)", text: $newUnit)
                                    .padding()
                                    .surfaceCard(16)
                                
                                Button(action: addCustomMetric) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 28, weight: .semibold))
                                        .foregroundStyle(newColor)
                                }
                                .buttonStyle(.plain)
                                .disabled(!canAddCustomMetric)
                                .opacity(!canAddCustomMetric ? 0.4 : 1)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("Edit \(sportName) Values")
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
        working = metrics
        newColor = accent
        hasLoaded = true
    }

    private func addPreset(_ preset: SportsTabView.SportMetricPreset) {
        working.append(preset.metric())
    }

    private func addCustomMetric() {
        guard canAddCustomMetric else { return }
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUnit = newUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        let custom = SportsTabView.SportMetric(
            key: "custom-\(UUID().uuidString)",
            label: trimmedName,
            unit: trimmedUnit,
            color: newColor,
            valueTransform: nil
        )
        working.append(custom)
        newName = ""
        newUnit = ""
    }

    private func applyColor(hex: String) {
        guard let target = colorPickerMetricID else { return }
        guard let idx = working.firstIndex(where: { $0.id == target }) else { return }
        if let col = Color(hex: hex) {
            working[idx].color = col
        }
    }

    private func removeMetric(_ id: UUID) {
        working.removeAll { $0.id == id }
    }

    private func donePressed() {
        metrics = working
        onSave(working)
        dismiss()
    }
}

private struct SportDataEntrySheet: View {
    @Environment(\.dismiss) private var dismiss

    let sportName: String
    let metrics: [SportsTabView.SportMetric]
    let defaultDate: Date
    let accent: Color
    var onSave: (SportsTabView.SportActivity) -> Void
    var onCancel: () -> Void

    @State private var selectedDate: Date
    @State private var currentMonth: Date
    @State private var valueInputs: [UUID: String]
    @State private var showMonthPicker: Bool = false
    @State private var showYearPicker: Bool = false

    private let calendar = Calendar.current
    private let daysOfWeek = ["S", "M", "T", "W", "T", "F", "S"]

    private var existingActivity: SportsTabView.SportActivity?
    private var existingRecordId: String? { existingActivity?.recordId }

    init(
        sportName: String,
        metrics: [SportsTabView.SportMetric],
        defaultDate: Date,
        accent: Color,
        existingActivity: SportsTabView.SportActivity? = nil,
        onSave: @escaping (SportsTabView.SportActivity) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.sportName = sportName
        self.metrics = metrics
        self.defaultDate = defaultDate
        self.accent = accent
        self.existingActivity = existingActivity
        self.onSave = onSave
        self.onCancel = onCancel

        let baseDate = Calendar.current.startOfDay(for: existingActivity?.date ?? defaultDate)
        _selectedDate = State(initialValue: baseDate)
        _currentMonth = State(initialValue: baseDate)

        let initialInputs: [UUID: String]
        if let activity = existingActivity {
            initialInputs = Dictionary(uniqueKeysWithValues: metrics.map { metric in
                let val = Self.value(for: metric, in: activity)
                return (metric.id, Self.displayString(for: val))
            })
        } else {
            initialInputs = Dictionary(uniqueKeysWithValues: metrics.map { ($0.id, "") })
        }
        _valueInputs = State(initialValue: initialInputs)
    }

    private var canSave: Bool {
        metrics.allSatisfy { metric in
            if let text = valueInputs[metric.id]?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                return Double(text) != nil
            }
            return false
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    dateSection
                    valuesSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("Submit Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                        .opacity(canSave ? 1 : 0.4)
                }
            }
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Date")
                .font(.subheadline.weight(.semibold))

            VStack(spacing: 0) {
                HStack {
                    Button(action: { withAnimation(.easeInOut) { shiftMonth(-1) } }) {
                        Image(systemName: "chevron.left")
                    }
                    .padding(.leading, 12)

                    Spacer()

                    Text(monthYearString(currentMonth))
                        .font(.headline)
                        .onTapGesture { toggleMonthYearPickers() }

                    Spacer()

                    Button(action: { withAnimation(.easeInOut) { shiftMonth(1) } }) {
                        Image(systemName: "chevron.right")
                    }
                    .padding(.trailing, 12)
                }
                .padding(.vertical, 10)

                if showYearPicker {
                    yearPicker
                } else if showMonthPicker {
                    monthPicker
                } else {
                    calendarGrid
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(accent.opacity(0.15), lineWidth: 1)
            )
        }
    }

    private var valuesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Values")
                .font(.subheadline.weight(.semibold))

            VStack(spacing: 12) {
                ForEach(metrics) { metric in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(metric.label)
                                .font(.subheadline.weight(.semibold))
                            TextField("Enter \(metric.unit)", text: binding(for: metric))
                                .keyboardType(.decimalPad)
                                .textInputAutocapitalization(.none)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.secondary.opacity(0.08))
                                )
                        }

                        Text(metric.unit)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.secondary.opacity(0.06))
                    )
                }
            }
        }
    }

    private var calendarGrid: some View {
        VStack(spacing: 0) {
            HStack {
                ForEach(daysOfWeek, id: \.self) { dow in
                    Text(dow)
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            let days = daysInMonth(currentMonth)
            let firstWeekday = calendar.component(.weekday, from: firstOfMonth(currentMonth)) - 1

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(0..<(days + firstWeekday), id: \.self) { i in
                    if i < firstWeekday {
                        Color.clear.frame(height: 32)
                    } else {
                        let dayNum = i - firstWeekday + 1
                        let date = dateForDay(dayNum, in: currentMonth)
                        Button(action: { select(date) }) {
                            Text("\(dayNum)")
                                .frame(maxWidth: .infinity, minHeight: 32)
                                .background(calendar.isDate(date, inSameDayAs: selectedDate) ? accent.opacity(0.2) : Color.clear)
                                .clipShape(Circle())
                        }
                        .foregroundColor(calendar.isDate(date, inSameDayAs: selectedDate) ? accent : .primary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }

    private var monthPicker: some View {
        let months = DateFormatter().monthSymbols ?? []
        return ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                ForEach(months.indices, id: \.self) { idx in
                    Button(action: {
                        var comps = calendar.dateComponents([.year, .day], from: currentMonth)
                        comps.month = idx + 1
                        if let newDate = calendar.date(from: comps) {
                            currentMonth = newDate
                        }
                        showMonthPicker = false
                    }) {
                        Text(months[idx])
                            .font(.body)
                            .frame(maxWidth: .infinity, minHeight: 32)
                            .background(calendar.component(.month, from: currentMonth) == idx + 1 ? accent.opacity(0.2) : Color.clear)
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
        }
        .frame(maxHeight: 340)
    }

    private var yearPicker: some View {
        let currentYear = calendar.component(.year, from: currentMonth)
        let years = (currentYear - 50...currentYear + 10).map { $0 }
        return ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                ForEach(years, id: \.self) { year in
                    Button(action: {
                        var comps = calendar.dateComponents([.month, .day], from: currentMonth)
                        comps.year = year
                        if let newDate = calendar.date(from: comps) {
                            currentMonth = newDate
                        }
                        showYearPicker = false
                    }) {
                        Text("\(year)")
                            .font(.body)
                            .frame(maxWidth: .infinity, minHeight: 32)
                            .background(calendar.component(.year, from: currentMonth) == year ? accent.opacity(0.2) : Color.clear)
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
        }
        .frame(maxHeight: 340)
    }

    private func binding(for metric: SportsTabView.SportMetric) -> Binding<String> {
        Binding(
            get: { valueInputs[metric.id] ?? "" },
            set: { valueInputs[metric.id] = $0 }
        )
    }

    private static func value(for metric: SportsTabView.SportMetric, in activity: SportsTabView.SportActivity) -> Double {
        switch metric.key {
        case "distanceKm": return activity.distanceKm ?? 0
        case "durationMin": return activity.durationMin ?? 0
        case "speedKmh": return activity.speedKmh ?? activity.speedKmhComputed ?? 0
        case "speedKmhComputed": return activity.speedKmhComputed ?? activity.speedKmh ?? 0
        case "laps": return Double(activity.laps ?? 0)
        case "attemptsMade": return Double(activity.attemptsMade ?? 0)
        case "attemptsMissed": return Double(activity.attemptsMissed ?? 0)
        case "accuracy": return activity.accuracy ?? activity.accuracyComputed ?? 0
        case "accuracyComputed": return activity.accuracyComputed ?? activity.accuracy ?? 0
        case "rounds": return Double(activity.rounds ?? 0)
        case "roundDuration": return activity.roundDuration ?? 0
        case "points": return Double(activity.points ?? 0)
        case "holdTime": return activity.holdTime ?? 0
        case "poses": return Double(activity.poses ?? 0)
        case "altitude": return activity.altitude ?? 0
        case "timeToPeak": return activity.timeToPeak ?? 0
        case "restTime": return activity.restTime ?? 0
        default: return activity.customValues[metric.key] ?? 0
        }
    }

    private static func displayString(for value: Double) -> String {
        if value == 0 { return "" }
        let intVal = Int(value)
        if Double(intVal) == value {
            return String(intVal)
        }
        return String(format: "%.2f", value)
    }

    private func select(_ date: Date) {
        selectedDate = calendar.startOfDay(for: date)
    }

    private func shiftMonth(_ delta: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: delta, to: currentMonth) {
            currentMonth = newMonth
        }
    }

    private func toggleMonthYearPickers() {
        if showMonthPicker {
            showMonthPicker = false
            showYearPicker = true
        } else if showYearPicker {
            showYearPicker = false
        } else {
            showMonthPicker = true
        }
    }

    private func save() {
        guard let activity = buildActivity() else { return }
        onSave(activity)
        dismiss()
    }

    private func buildActivity() -> SportsTabView.SportActivity? {
        var activity = SportsTabView.SportActivity(recordId: existingRecordId, date: selectedDate)

        for metric in metrics {
            guard let text = valueInputs[metric.id]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let value = Double(text) else { return nil }

            switch metric.key {
            case "distanceKm": activity.distanceKm = value
            case "durationMin": activity.durationMin = value
            case "speedKmh": activity.speedKmh = value
            case "speedKmhComputed": activity.speedKmh = value
            case "laps": activity.laps = Int(value)
            case "attemptsMade": activity.attemptsMade = Int(value)
            case "attemptsMissed": activity.attemptsMissed = Int(value)
            case "accuracy": activity.accuracy = value
            case "accuracyComputed": activity.accuracy = value
            case "rounds": activity.rounds = Int(value)
            case "roundDuration": activity.roundDuration = value
            case "points": activity.points = Int(value)
            case "holdTime": activity.holdTime = value
            case "poses": activity.poses = Int(value)
            case "altitude": activity.altitude = value
            case "timeToPeak": activity.timeToPeak = value
            case "restTime": activity.restTime = value
            default:
                activity.customValues[metric.key] = value
            }
        }

        return activity
    }

    private func monthYearString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func firstOfMonth(_ date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    private func daysInMonth(_ date: Date) -> Int {
        calendar.range(of: .day, in: .month, for: date)?.count ?? 30
    }

    private func dateForDay(_ day: Int, in month: Date) -> Date {
        var comps = calendar.dateComponents([.year, .month], from: month)
        comps.day = day
        return calendar.date(from: comps) ?? month
    }
}

// MARK: - Modular Metric Graph

struct SportMetricGraph: View {
    let metric: SportsTabView.SportMetric
    let activities: [SportsTabView.SportActivity]
    let historyDays: Int
    let anchorDate: Date

    private var cal: Calendar { Calendar.current }
    private var today: Date { cal.startOfDay(for: anchorDate) }

    private var displayDates: [Date] {
        let anchor = cal.startOfDay(for: anchorDate)
        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: anchor)
        comps.weekday = 2 // Monday
        guard let startOfWeek = cal.date(from: comps) else { return [] }
        return (0..<historyDays).compactMap { offset in
            cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: startOfWeek))
        }
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
        case "speedKmhComputed": return activity.speedKmhComputed ?? activity.speedKmh ?? 0
        case "laps": return Double(activity.laps ?? 0)
        case "attemptsMade": return Double(activity.attemptsMade ?? 0)
        case "attemptsMissed": return Double(activity.attemptsMissed ?? 0)
        case "accuracy": return activity.accuracy ?? activity.accuracyComputed ?? 0
        case "accuracyComputed": return activity.accuracyComputed ?? activity.accuracy ?? 0
        case "rounds": return Double(activity.rounds ?? 0)
        case "roundDuration": return activity.roundDuration ?? 0
        case "points": return Double(activity.points ?? 0)
        case "holdTime": return activity.holdTime ?? 0
        case "poses": return Double(activity.poses ?? 0)
        case "altitude": return activity.altitude ?? 0
        case "timeToPeak": return activity.timeToPeak ?? 0
        case "restTime": return activity.restTime ?? 0
        default: return activity.customValues[metric.key] ?? 0
        }
    }

    private var dailyTotals: [(date: Date, total: Double)] {
        let grouped = Dictionary(grouping: activities) { cal.startOfDay(for: $0.date) }
        return displayDates.map { day in
            let items = grouped[day] ?? []
            let maxValue = items.map { value(for: $0) }.max() ?? 0
            return (date: day, total: maxValue)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(metric.label) (\(metric.unit))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(metric.color)
                
                Spacer()
            }
            .padding(.bottom, 4)

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

    func configs(from sports: [SportType]) -> [SportConfig] {
        sports.map { sport in
            SportConfig(
                id: sport.id,
                name: sport.name,
                colorHex: sport.color.toHexString(),
                metrics: sport.metrics.map { metric in
                    SportMetricConfig(
                        id: metric.id,
                        key: metric.key,
                        label: metric.label,
                        unit: metric.unit,
                        colorHex: metric.color.toHexString()
                    )
                }
            )
        }
    }

    func sportsFromConfigs(_ configs: [SportConfig], fallbackActivities: [SportType]) -> [SportType] {
        let fallbackByName = Dictionary(uniqueKeysWithValues: fallbackActivities.map { ($0.name.lowercased(), $0.activities) })
        return configs.map { config in
            let color = Color(hex: config.colorHex) ?? .accentColor
            let activities = fallbackByName[config.name.lowercased()] ?? []
            return SportType(
                name: config.name,
                color: color,
                activities: activities,
                metrics: config.metrics.map { metric in
                    SportMetric(
                        key: metric.key,
                        label: metric.label,
                        unit: metric.unit,
                        color: Color(hex: metric.colorHex) ?? color,
                        valueTransform: Self.metricPresetByKey[metric.key]?.valueTransform
                    )
                }
            )
        }
    }
}

private extension DateFormatter {
    static var shortDate: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEE d" // weekday short + day number (Mon 22)
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

    static var sportWeekdayFull: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEEE"
        return df
    }()

    static var sportLongDate: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MMMM d"
        return df
    }()
}

private extension Calendar {
    func isDateInFuture(_ date: Date) -> Bool {
        compare(date, to: Date(), toGranularity: .day) == .orderedDescending
    }
}
