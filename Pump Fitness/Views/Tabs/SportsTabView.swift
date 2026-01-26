//
//  SportsTabView.swift
//  Trackerio
//
//  Created by Kyle Graham on 8/12/2025.
//

import Combine
import SwiftUI
import CoreLocation
import MapKit
import WeatherKit
import SwiftData
import TipKit

struct SportsTabView: View {
    @Binding var account: Account
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    private let accountService = AccountFirestoreService()
    private let dayService = DayFirestoreService()
    @State private var showCalendar = false
    @Binding var selectedDate: Date
    var isPro: Bool
    @State private var showAccountsView = false
    @ObservedObject var weatherModel: WeatherViewModel
    @State private var showProSheet = false
    @State private var showWellnessShareSheet = false
    
    // Wellness
    @State private var showWellnessEditor = false
    @State private var showWellnessEntry = false
    @State private var wellnessHKValues: [WellnessMetricType: Double] = [:]
    private let healthKitService = HealthKitService()
    @State private var healthKitAuthorized = false

    // Sleep tracking state (moved from RoutineTabView)
    @State private var nightSleepSeconds: TimeInterval = 0
    @State private var napSleepSeconds: TimeInterval = 0
    @State private var showWeeklySleep: Bool = false
    @State private var weekStartsOnMonday: Bool = true
    @Binding var weeklySleepEntries: [SleepDayEntry]

    // Keyboard Toolbar State
    @State private var isKeyboardBarVisible = false
    @State private var keyboardBarUnit = "°F"
    @State private var onKeyboardUnitChange: ((String) -> Void)? = nil
    @State private var onKeyboardDismiss: (() -> Void)? = nil

    @State private var isSimpleKeyboardBarVisible = false
    @State private var onSimpleKeyboardDismiss: (() -> Void)? = nil

    var accentOverride: Color? {
        guard themeManager.selectedTheme != .multiColour else { return nil }
        return themeManager.selectedTheme.accent(for: colorScheme)
    }

    var workoutTimelineAccent: Color {
        if themeManager.selectedTheme == .multiColour {
            return Color.yellow
        }
        return accentOverride ?? .accentColor
    }


    // MARK: - Weather Section

    // Weather visual grouping used across WeatherSection and surrounding layout
    fileprivate enum WeatherGroup {
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
                case .failed:
                    VStack(alignment: .center, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text("Weather unavailable")
                            .font(.headline)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                case .locationUnavailable:
                    VStack(alignment: .center, spacing: 8) {
                        Image(systemName: "location.slash.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Location Required")
                            .font(.headline)
                        Text("We need your location to show local weather conditions and show your location in the itinerary tab.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
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
                            
                            // Attribution
                            Link(destination: URL(string: "https://weatherkit.apple.com/legal-attribution.html")!) {
                                Text("Source:  Weather")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

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

                // Small description below the symbol (e.g., "UV")
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))

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
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                HeaderComponent(
                                    showCalendar: $showCalendar,
                                    selectedDate: $selectedDate,
                                    onProfileTap: { showAccountsView = true },
                                    isPro: isPro
                                )
                                .environmentObject(account)
                                .onAppear {
                                    // Removed auto-scroll logic as Weather tip is now first and at the top
                                }
                                .onChange(of: selectedDate) { _, newDate in
                                    Task {
                                        await weatherModel.refresh(for: newDate)
                                    }
                                }

                            VStack(spacing: 0) {
                                SportsWeatherHeaderView(
                                    weatherModel: weatherModel,
                                    selectedDate: selectedDate,
                                    isPro: isPro,
                                    onScrollRequest: {
                                        withAnimation {
                                            proxy.scrollTo("teamPlay", anchor: .center)
                                        }
                                    }
                                )
                                .padding(.bottom, 16)
                                
                                SportsWellnessSection(
                                    showWellnessEditor: $showWellnessEditor,
                                    showWellnessEntry: $showWellnessEntry,
                                    account: account,
                                    wellnessHKValues: wellnessHKValues,
                                    wellnessManualAdjustment: wellnessManualAdjustment,
                                    accentOverride: accentOverride
                                )

                                SobrietyTrackingSection(
                                    account: $account,
                                    selectedDate: $selectedDate
                                )
                                .opacity(isPro ? 1 : 0.5)
                                .blur(radius: isPro ? 0 : 4)
                                .disabled(!isPro)
                                .overlay {
                                    if !isPro {
                                        ZStack {
                                            Color.black.opacity(0.001) // Capture taps
                                                .onTapGesture {
                                                    // no-op capture
                                                }

                                            Button {
                                                showProSheet = true
                                            } label: {
                                                VStack(spacing: 8) {
                                                    HStack {
                                                        let accent = themeManager.selectedTheme == .multiColour ? nil : themeManager.selectedTheme.accent(for: colorScheme)

                                                        if let accent {
                                                            Image("logo")
                                                                .resizable()
                                                                .renderingMode(.template)
                                                                .foregroundStyle(accent)
                                                                .aspectRatio(contentMode: .fit)
                                                                .frame(height: 40)
                                                                .padding(.leading, 4)
                                                                .offset(y: 6)
                                                        } else {
                                                            Image("logo")
                                                                .resizable()
                                                                .renderingMode(.original)
                                                                .aspectRatio(contentMode: .fit)
                                                                .frame(height: 40)
                                                                .padding(.leading, 4)
                                                                .offset(y: 6)
                                                        }
                                                        
                                                        Text("PRO")
                                                            .font(.subheadline)
                                                            .fontWeight(.semibold)
                                                            .foregroundStyle(Color.white)
                                                            .padding(.horizontal, 8)
                                                            .padding(.vertical, 4)
                                                            .background(
                                                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                                    .fill(
                                                                        accent.map {
                                                                            LinearGradient(
                                                                                gradient: Gradient(colors: [$0, $0.opacity(0.85)]),
                                                                                startPoint: .topLeading,
                                                                                endPoint: .bottomTrailing
                                                                            )
                                                                        } ?? LinearGradient(
                                                                            gradient: Gradient(colors: [
                                                                                Color(red: 0.74, green: 0.43, blue: 0.97),
                                                                                Color(red: 0.83, green: 0.99, blue: 0.94)
                                                                            ]),
                                                                            startPoint: .topLeading,
                                                                            endPoint: .bottomTrailing
                                                                        )
                                                                    )
                                                            )
                                                            .offset(y: 6)
                                                    }
                                                    .padding(.bottom, 5)
                                                    
                                                    Text("Trackerio Pro")
                                                        .font(.headline)
                                                        .foregroundStyle(.primary)
                                                    
                                                    Text("Upgrade to unlock Sobriety Tracking + More")
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                                .padding()
                                                .glassEffect(in: .rect(cornerRadius: 16.0))
                                            }
                                            .buttonStyle(.plain)
                                            .sheet(isPresented: $showProSheet) {
                                                ProSubscriptionView()
                                            }
                                        }
                                    }
                                }
                                
                                SportsInjurySection(
                                    injuries: $account.injuries,
                                    selectedDate: selectedDate,
                                    onSave: {
                                        accountService.saveAccount(account) { _ in }
                                    },
                                    isPro: isPro,
                                    showProSheet: $showProSheet
                                )

                                RecoveryTrackingSection(
                                    date: selectedDate,
                                    accentColorOverride: accentOverride,
                                    isKeyboardVisible: $isKeyboardBarVisible,
                                    keyboardUnit: $keyboardBarUnit,
                                    onUnitChange: $onKeyboardUnitChange,
                                    onDismiss: $onKeyboardDismiss,
                                    isSimpleKeyboardVisible: $isSimpleKeyboardBarVisible,
                                    onSimpleDismiss: $onSimpleKeyboardDismiss
                                )

                                VStack {
                                    HStack {
                                        Text("Sleep Tracking")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.primary)

                                        Spacer()
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 38)
                                    .padding(.horizontal, 18)

                                    SleepTrackingSection(
                                        accentColor: accentOverride,
                                        nightStored: $nightSleepSeconds,
                                        napStored: $napSleepSeconds,
                                        onPersist: { night, nap in
                                            onUpdateSleep(night, nap)
                                        },
                                        onLiveUpdate: { night, nap in
                                            onLiveSleepUpdate(night, nap)
                                        }
                                    )

                                    VStack(alignment: .leading, spacing: 16) {
                                        // New collapsible Sleep Summary section (Macro-style layout adapted for sleep)
                                        HStack {
                                            Spacer()
                                            Label("Sleep Summary", systemImage: "bed.double.fill")
                                                .font(.callout.weight(.semibold))
                                            Image(systemName: showWeeklySleep ? "chevron.up" : "chevron.down")
                                                .font(.caption.weight(.semibold))
                                            Spacer()
                                        }
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                                showWeeklySleep.toggle()
                                            }
                                        }

                                        if showWeeklySleep {
                                            VStack(alignment: .leading, spacing: 10) {
                                                ScrollView(.horizontal, showsIndicators: false) {
                                                    HStack(spacing: 12) {
                                                        let cal = Calendar.current
                                                        let today = selectedDate
                                                        let weekday = cal.component(.weekday, from: today) // 1 = Sunday
                                                        let startIndex = weekStartsOnMonday ? 2 : 1
                                                        let offsetToStart = (weekday - startIndex + 7) % 7
                                                        let startOfWeek = cal.date(byAdding: .day, value: -offsetToStart, to: cal.startOfDay(for: today)) ?? today

                                                        let weekDates: [Date] = (0..<7).compactMap { i in
                                                            cal.date(byAdding: .day, value: i, to: startOfWeek)
                                                        }

                                                        ForEach(weekDates, id: \.self) { day in
                                                            if let entry = weeklySleepEntries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: day) }) {
                                                                // Use existing entry values
                                                                SleepDayColumn(date: day, tint: workoutTimelineAccent, nightSeconds: entry.nightSeconds, napSeconds: entry.napSeconds)
                                                            } else {
                                                                // No recorded data for this day yet
                                                                SleepDayColumn(date: day, tint: workoutTimelineAccent, nightSeconds: 0, napSeconds: 0)
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                            .transition(.opacity.combined(with: .move(edge: .top)))
                                            .padding(.top, 6)
                                        }
                                    }
                                    .padding(20)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                    .glassEffect(in: .rect(cornerRadius: 16.0))
                                    .padding(.horizontal, 18)
                                    .padding(.top, 12)
                                }
                                .opacity(isPro ? 1 : 0.5)
                                .blur(radius: isPro ? 0 : 4)
                                .disabled(!isPro)
                                .overlay {
                                    if !isPro {
                                        ZStack {
                                            Color.black.opacity(0.001) // Capture taps
                                                .onTapGesture {
                                                    // Optional: Trigger upgrade flow
                                                }
                                            
                                            VStack(spacing: 8) {
                                                HStack {
                                                    let accent = themeManager.selectedTheme == .multiColour ? nil : themeManager.selectedTheme.accent(for: colorScheme)

                                                    if let accent {
                                                        Image("logo")
                                                            .resizable()
                                                            .renderingMode(.template)
                                                            .foregroundStyle(accent)
                                                            .aspectRatio(contentMode: .fit)
                                                            .frame(height: 40)
                                                            .padding(.leading, 4)
                                                            .offset(y: 6)
                                                    } else {
                                                        Image("logo")
                                                            .resizable()
                                                            .renderingMode(.original)
                                                            .aspectRatio(contentMode: .fit)
                                                            .frame(height: 40)
                                                            .padding(.leading, 4)
                                                            .offset(y: 6)
                                                    }
                                                    
                                                    Text("PRO")
                                                        .font(.subheadline)
                                                        .fontWeight(.semibold)
                                                        .foregroundStyle(Color.white)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 4)
                                                        .background(
                                                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                                .fill(
                                                                    accent.map {
                                                                        LinearGradient(
                                                                            gradient: Gradient(colors: [$0, $0.opacity(0.85)]),
                                                                            startPoint: .topLeading,
                                                                            endPoint: .bottomTrailing
                                                                        )
                                                                    } ?? LinearGradient(
                                                                        gradient: Gradient(colors: [
                                                                            Color(red: 0.74, green: 0.43, blue: 0.97),
                                                                            Color(red: 0.83, green: 0.99, blue: 0.94)
                                                                        ]),
                                                                        startPoint: .topLeading,
                                                                        endPoint: .bottomTrailing
                                                                    )
                                                                )
                                                        )
                                                        .offset(y: 6)
                                                }
                                                .padding(.bottom, 5)
                                                
                                                Text("Trackerio Pro")
                                                    .font(.headline)
                                                    .foregroundStyle(.primary)
                                                
                                                Text("Upgrade to unlock Sleep Tracking + More")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            .padding()
                                            .glassEffect(in: .rect(cornerRadius: 16.0))
                                        }
                                    }
                                }

                                ShareWellnessCTA(accentColor: accentOverride ?? .blue) {
                                    showWellnessShareSheet = true
                                }
                                .padding(.horizontal, 18)
                                .padding(.top, 16)
                                }
                            }
                            .padding(.bottom, 24)
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
            .overlay(alignment: .bottom) {
                KeyboardDismissBar(
                    isVisible: isKeyboardBarVisible,
                    selectedUnit: keyboardBarUnit,
                    availableUnits: ["°F", "°C"],
                    tint: accentOverride ?? .accentColor,
                    onDismiss: {
                        onKeyboardDismiss?()
                        isKeyboardBarVisible = false
                    },
                    onSelectUnit: { unit in
                        onKeyboardUnitChange?(unit)
                        keyboardBarUnit = unit
                    }
                )
                SimpleKeyboardDismissBar(
                    isVisible: isSimpleKeyboardBarVisible,
                    tint: accentOverride ?? .accentColor,
                    onDismiss: {
                        onSimpleKeyboardDismiss?()
                        isSimpleKeyboardBarVisible = false
                    }
                )
            }
            .navigationDestination(isPresented: $showAccountsView) {
                AccountsView(account: $account)
            }
            .sheet(isPresented: $showWellnessEditor) {
                let metricsBinding = Binding<[TrackedWellnessMetric]>(
                    get: { account.dailyWellnessMetrics },
                    set: { newValue in
                        account.dailyWellnessMetrics = newValue
                        accountService.saveAccount(account) { _ in }
                    }
                )
                
                WellnessSummaryEditorSheet(
                    metrics: metricsBinding,
                    tint: accentOverride ?? .blue, // Wellness themed color
                    onDone: {
                        showWellnessEditor = false
                        do {
                            try modelContext.save()
                        } catch {
                            print("Failed to save local account for wellness: \(error)")
                        }
                        accountService.saveAccount(account) { _ in }
                        requestWellnessAuthorization()
                    },
                    onCancel: { showWellnessEditor = false }
                )
            }
            .sheet(isPresented: $showWellnessEntry) {
                WellnessEntrySheet(
                    metrics: account.dailyWellnessMetrics,
                    hkValues: wellnessHKValues,
                    onSave: { type, isAddition, valueStr in
                        guard let value = Double(valueStr) else { return }
                        let day = Day.fetchOrCreate(for: selectedDate, in: modelContext)
                        
                        // Find existing adjustment for this type
                        var currentAdjustments = day.wellnessMetricAdjustments
                        let change = isAddition ? value : -value
                        
                        if let index = currentAdjustments.firstIndex(where: { $0.metricId == type.id }) {
                            // Update existing
                            currentAdjustments[index].manualValue += change
                        } else {
                            // Create new adjustment
                            let adj = SoloMetricValue(metricId: type.id, metricName: type.displayName, value: change)
                            currentAdjustments.append(adj)
                        }
                        day.wellnessMetricAdjustments = currentAdjustments
                        
                        // Persist
                        do {
                            try modelContext.save()
                        } catch {
                            print("Failed to save wellness adjustment: \(error)")
                        }
                        dayService.updateDayFields(["wellnessMetricAdjustments": day.wellnessMetricAdjustments], for: day) { _ in }
                        
                        syncWellnessMetricsToAccount()
                    }
                )
            }
            .sheet(isPresented: $showWellnessShareSheet) {
                wellnessShareSheetContent
            }

        }
        .onAppear {
            let metrics = account.dailyWellnessMetrics
            healthKitService.requestAuthorization(wellnessMetrics: metrics.map { $0.type }) { _ in
                refreshWellnessValues()
            }
            refreshSleepValues()
        }
        .onChange(of: selectedDate) { _, _ in
            refreshWellnessValues()
            refreshSleepValues()
        }
        .onChange(of: account.dailyWellnessMetrics) { _, _ in
            refreshWellnessValues()
        }
    }

    private var wellnessShareSheetContent: some View {
        let day = Day.fetchOrCreate(for: selectedDate, in: modelContext)
        
        let metricsSnapshots = account.dailyWellnessMetrics.map { metric -> WellnessMetricSnapshot in
            let val = (metric.manualValue ?? 0) + (metric.healthKitValue ?? 0)
            let formatted = val.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", val) : String(format: "%.1f", val)
            return WellnessMetricSnapshot(
                id: metric.id, // Stable ID
                name: metric.type.displayName,
                value: formatted,
                unit: metric.type.unit,
                icon: metric.type.systemImage,
                color: accentOverride ?? .blue
            )
        }
        
        let activeInjuries = account.injuries.filter { injury in
             let calendar = Calendar.current
             let startOfSelected = calendar.startOfDay(for: selectedDate)
             let startOfOccurrence = calendar.startOfDay(for: injury.dateOccurred)
             guard startOfOccurrence <= startOfSelected else { return false }
             let endDate = calendar.date(byAdding: .day, value: injury.durationDays, to: injury.dateOccurred) ?? injury.dateOccurred
             let endOfInjury = calendar.startOfDay(for: endDate)
             return startOfSelected < endOfInjury
        }.map { injury -> BodyInjurySnapshot in
            return BodyInjurySnapshot(
                id: injury.id, // Stable ID
                name: injury.name,
                bodyPart: injury.bodyPart?.rawValue.capitalized ?? "Body",
                severity: "",
                status: "Active",
                dateOccurred: injury.dateOccurred,
                color: .pink
            )
        }
        
        let sessions = day.recoverySessions.map { session in
            let mins = Int(session.durationSeconds / 60)
            return RecoverySessionSnapshot(
                id: session.id, // Stable ID
                name: session.category.rawValue,
                detail: "\(mins) min",
                icon: session.category.icon,
                color: .orange
            )
        }
        
        let hNight = Int(nightSleepSeconds) / 3600
        let mNight = (Int(nightSleepSeconds) % 3600) / 60
        
        let hNap = Int(napSleepSeconds) / 3600
        let mNap = (Int(napSleepSeconds) % 3600) / 60
        
        let total = nightSleepSeconds + napSleepSeconds
        let hTotal = Int(total) / 3600
        let mTotal = (Int(total) % 3600) / 60
        
        let sleepSnap = SleepSnapshot(
            nightText: "\(hNight)h \(mNight)m",
            napText: "\(hNap)h \(mNap)m",
            totalText: "\(hTotal)h \(mTotal)m",
            score: nil
        )
        
        let sobrietySnapshots = account.sobrietyMetrics
            .filter { $0.isEnabled }
            .map { metric -> SobrietySnapshot in
                let entry = day.sobrietyEntries.first(where: { $0.metricID == metric.id })
                var status = "Pending"
                var isSuccess = false
                
                if let entry = entry, let sober = entry.isSober {
                    status = sober ? "Success" : "Relapsed"
                    isSuccess = sober
                }
                
                return SobrietySnapshot(
                    id: metric.id, // Stable ID from metric
                    name: metric.displayName,
                    icon: "drop.fill",
                    status: status,
                    color: Color(hex: metric.colorHex) ?? .teal,
                    isSuccess: isSuccess
                )
            }
        
        return WellnessShareSheet(
            accentColor: accentOverride ?? .blue,
            date: selectedDate,
            dailyCheckIn: nil,
            metrics: metricsSnapshots,
            injuries: activeInjuries,
            recoverySessions: sessions,
            sleep: sleepSnap,
            sobriety: sobrietySnapshots
        )
    }

    private func refreshSleepValues() {
        let day = Day.fetchOrCreate(for: selectedDate, in: modelContext)
        nightSleepSeconds = day.nightSleepSeconds
        napSleepSeconds = day.napSleepSeconds
    }

    private func onLiveSleepUpdate(_ night: TimeInterval, _ nap: TimeInterval) {
        nightSleepSeconds = night
        napSleepSeconds = nap
    }

    private func onUpdateSleep(_ night: TimeInterval, _ nap: TimeInterval) {
        let day = Day.fetchOrCreate(for: selectedDate, in: modelContext)
        day.nightSleepSeconds = night
        day.napSleepSeconds = nap

        do {
            try modelContext.save()
        } catch {
            print("SportsTabView: failed to save sleep locally: \(error)")
        }

        var fields: [String: Any] = [:]
        fields["nightSleepSeconds"] = night
        fields["napSleepSeconds"] = nap

        dayService.updateDayFields(fields, for: day) { success in
            if !success {
                print("SportsTabView: failed to sync sleep to Firestore for date=\(selectedDate)")
            }
        }
    }

    private func wellnessManualAdjustment(for type: WellnessMetricType) -> Double {
        let day = Day.fetchOrCreate(for: selectedDate, in: modelContext)
        return day.wellnessMetricAdjustments.first(where: { $0.metricId == type.id })?.manualValue ?? 0
    }

    private func refreshWellnessValues() {
        guard healthKitService.isAvailable else { return }
        let metrics = account.dailyWellnessMetrics
        let group = DispatchGroup()
        var newValues: [WellnessMetricType: Double] = [:]
        
        for metric in metrics {
            group.enter()
            healthKitService.fetchWellnessMetric(type: metric.type, for: selectedDate) { val in
                if let val = val {
                    newValues[metric.type] = val
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            self.wellnessHKValues = newValues
            self.syncWellnessMetricsToAccount()
            self.syncWellnessHKToDay(newValues)
        }
    }
    
    private func syncWellnessHKToDay(_ values: [WellnessMetricType: Double]) {
         let day = Day.fetchOrCreate(for: selectedDate, in: modelContext)
         var changed = false
         var adjustments = day.wellnessMetricAdjustments
         
         for (type, val) in values {
             if let idx = adjustments.firstIndex(where: { $0.metricId == type.id }) {
                 if adjustments[idx].healthKitValue != val {
                     adjustments[idx].healthKitValue = val
                     changed = true
                 }
             } else {
                 // Create new entry
                 var newEntry = SoloMetricValue(metricId: type.id, metricName: type.displayName, value: 0)
                 newEntry.healthKitValue = val
                 adjustments.append(newEntry)
                 changed = true
             }
         }
         
         if changed {
             day.wellnessMetricAdjustments = adjustments
             try? modelContext.save()
             dayService.updateDayFields(["wellnessMetricAdjustments": day.wellnessMetricAdjustments], for: day) { _ in }
         }
    }
    
    private func syncWellnessMetricsToAccount() {
        var metrics = account.dailyWellnessMetrics
        var changed = false
        
        for i in metrics.indices {
            let type = metrics[i].type
            let manual = wellnessManualAdjustment(for: type)
            let hk = wellnessHKValues[type] ?? 0
            
            if metrics[i].manualValue != manual || metrics[i].healthKitValue != hk {
                metrics[i].manualValue = manual
                metrics[i].healthKitValue = hk
                changed = true
            }
        }
        
        if changed {
            account.dailyWellnessMetrics = metrics
            accountService.saveAccount(account) { _ in }
        }
    }

    private func requestWellnessAuthorization() {
        let wellnessTypes = account.dailyWellnessMetrics.map { $0.type }
        if wellnessTypes.isEmpty { return }
        
        healthKitService.requestAuthorization(activityMetrics: [], wellnessMetrics: wellnessTypes) { ok in
            DispatchQueue.main.async {
                self.healthKitAuthorized = ok
                if ok {
                    refreshWellnessValues()
                }
            }
        }
    }
}

private struct SimpleKeyboardDismissBar: View {
    var isVisible: Bool
    var tint: Color
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
                            .foregroundStyle(tint)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
                .padding(.bottom, 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}


// MARK: - Weather Models & ViewModel

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
    private var lastFetchTime: Date?
    private var lastFetchedTargetDate: Date?

    private let calendar = Calendar.current
    private let weatherService: WeatherService
    private let locationProvider: LocationProvider
    private var localSearch: MKLocalSearch?

    init(weatherService: WeatherService? = nil, locationProvider: LocationProvider? = nil) {
        self.weatherService = weatherService ?? WeatherService()
        self.locationProvider = locationProvider ?? LocationProvider()
    }

    func refresh(for date: Date) async {
        // Cache check: if we fetched for this same target date less than 5 minutes ago, skip.
        if let lastFetchTime, let lastFetchedTargetDate,
           calendar.isDate(date, inSameDayAs: lastFetchedTargetDate),
           abs(lastFetchTime.timeIntervalSinceNow) < 300,
           state == .loaded {
            return
        }

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
            lastFetchTime = Date()
            lastFetchedTargetDate = date
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
        localSearch?.cancel()
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "\(location.coordinate.latitude), \(location.coordinate.longitude)"
        request.resultTypes = .address
        
        let search = MKLocalSearch(request: request)
        localSearch = search
        
        do {
            let response = try await search.start()
            if let item = response.mapItems.first {
                let placemark = item.placemark
                var components: [String] = []
                
                // Show "Locality, Region, Country" to protect privacy
                if let locality = placemark.locality, !locality.isEmpty {
                    components.append(locality)
                }

                if let admin = placemark.administrativeArea, !admin.isEmpty {
                    components.append(admin)
                }
                
                if let country = placemark.country, !country.isEmpty {
                    components.append(country)
                }
                
                if !components.isEmpty {
                    regionDescription = components.joined(separator: ", ")
                } else {
                    regionDescription = nil
                }
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
        // Only use cached location if it is recent (within 5 minutes)
        if let location = manager.location, abs(location.timestamp.timeIntervalSinceNow) < 300 {
            return location
        }

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
        guard let location = locations.last else {
            locationContinuation?.resume(throwing: LocationError.unavailable)
            locationContinuation = nil
            return
        }
        locationContinuation?.resume(returning: location)
        locationContinuation = nil
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
}

private extension DateFormatter {
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

private struct KeyboardDismissBar: View {
    var isVisible: Bool
    var selectedUnit: String?
    var availableUnits: [String] = []
    var tint: Color = .accentColor
    var onDismiss: () -> Void
    var onSelectUnit: ((String) -> Void)? = nil

    var body: some View {
        Group {
            if isVisible {
                HStack(spacing: 12) {
                    if !availableUnits.isEmpty {
                        ForEach(availableUnits, id: \.self) { unit in
                            // Comparison handles mixed case ("kg" vs "KG") or degrees symbol
                            let isSelected = selectedUnit?.lowercased() == unit.lowercased()
                            Button {
                                onSelectUnit?(unit)
                            } label: {
                                Text(unit.uppercased())
                                    .font(.callout.weight(.semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
                                    .foregroundStyle(isSelected ? tint : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Spacer()

                    Button(action: onDismiss) {
                        Label("Dismiss", systemImage: "keyboard.chevron.compact.down")
                            .font(.callout.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: Capsule())
                            .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
                            .foregroundStyle(tint)
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

private struct SleepDayColumn: View {
    let date: Date
    let tint: Color
    let nightSeconds: TimeInterval
    let napSeconds: TimeInterval

    var body: some View {
        VStack(spacing: 8) {
            Text(formattedDate(from: date))
                .font(.caption)
                .fontWeight(.semibold)

            VStack(spacing: 8) {
                // Night sleep (hours)
                SleepIndicatorRow(label: "Night", color: .indigo, seconds: nightSeconds)

                // Nap sleep (minutes)
                SleepIndicatorRow(label: "Nap", color: .cyan, seconds: napSeconds)

                // Total
                SleepIndicatorRow(label: "Total", color: tint, seconds: nightSeconds + napSeconds)
            }
            Spacer()
        }
        .padding(EdgeInsets(top: 16, leading: 12, bottom: 12, trailing: 12))
        .frame(width: 180, height: 140)
        .liquidGlass(cornerRadius: 14)
    }

    private struct SleepIndicatorRow: View {
        var label: String
        var color: Color
        var seconds: TimeInterval
        private var displayText: String {
            let total = Int(seconds)
            let h = total / 3600
            let m = (total % 3600) / 60
            if h > 0 { return String(format: "%dh %02dm", h, m) }
            return String(format: "%dm", m)
        }

        var body: some View {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)

                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(displayText)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func shortWeekday(from date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "E"
        return df.string(from: date)
    }

    private func formattedDate(from date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "E, d MMM"
        return df.string(from: date)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return String(format: "%dh %02dm", h, m) }
        return String(format: "%dm", m)
    }
}

fileprivate struct SportsWeatherHeaderView: View {
    @ObservedObject var weatherModel: WeatherViewModel
    let selectedDate: Date
    let isPro: Bool
    let onScrollRequest: () -> Void

    var body: some View {
        if Calendar.current.isDateInToday(selectedDate) {
            let _isNight = !(weatherModel.currentSnapshot?.isDaylight ?? true)
            let adjustedGroup: SportsTabView.WeatherGroup = {
                guard let snapshot = weatherModel.currentSnapshot else { return .other }
                let base = SportsTabView.WeatherGroup(symbolName: snapshot.symbol)
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

            VStack(spacing: 0) {
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

                SportsTabView.WeatherSection(viewModel: weatherModel, selectedDate: selectedDate)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 18)
                    .background {
                        if weatherModel.state == .loaded {
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
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16.0, style: .continuous))
                    .padding(.horizontal, 18)
                    .frame(height: 500)
                    .padding(.top, 18)
                    .sportsTip(.weather, isEnabled: isPro, onStepChange: { step in
                        if step == 1 {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                onScrollRequest()
                            }
                        }
                    })
            }
        }
    }
}

fileprivate struct SportsWellnessSection: View {
    @Binding var showWellnessEditor: Bool
    @Binding var showWellnessEntry: Bool
    let account: Account
    let wellnessHKValues: [WellnessMetricType: Double]
    let wellnessManualAdjustment: (WellnessMetricType) -> Double
    let accentOverride: Color?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Daily Wellness Summary")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 18)
            .padding(.top, 48)

            Button {
                showWellnessEditor = true
            } label: {
                Label("Change Goals", systemImage: "pencil")
                  .font(.callout.weight(.semibold))
                  .padding(.vertical, 18)
                  .frame(maxWidth: .infinity, minHeight: 52)
                  .glassEffect(in: .rect(cornerRadius: 16.0))
                  .contentShape(Rectangle())
            }
            .nutritionTip(.editCalorieGoal)
            .padding(.top, 16)
            .padding(.horizontal, 18)
            .buttonStyle(.plain)

            if account.dailyWellnessMetrics.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("No wellness metrics", systemImage: "heart.text.square")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("Add metrics using the Edit button to start tracking your health and wellness.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .glassEffect(in: .rect(cornerRadius: 16.0))
                .padding(.horizontal, 18)
                .padding(.top, 18)
            } else {
                WellnessMetricsGrid(
                    metrics: account.dailyWellnessMetrics,
                    hkValues: wellnessHKValues,
                    manualAdjustmentProvider: wellnessManualAdjustment,
                    accentColor: accentOverride
                )
                .padding(.horizontal, 18)
                .padding(.top, 18)
                
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(accentOverride ?? .pink)
                    Text("Synced with Apple Health")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 12)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if !account.dailyWellnessMetrics.isEmpty {
                Button {
                    showWellnessEntry = true
                } label: {
                    HStack(spacing: 8) {
                        Spacer()
                        Label("Submit Data", systemImage: "paperplane.fill")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.white)
                            Spacer()
                    }
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(accentOverride ?? Color.blue, in: RoundedRectangle(cornerRadius: 18))
                }
                .padding(.horizontal, 18)
                .buttonStyle(.plain)
                .contentShape(RoundedRectangle(cornerRadius: 16.0))
                .padding(.top, 16)
            }
        }
    }
}

fileprivate struct SportsInjurySection: View {
    @Binding var injuries: [Injury]
    let selectedDate: Date
    let onSave: () -> Void
    let isPro: Bool
    @Binding var showProSheet: Bool
    
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        InjuryTrackingSection(
            injuries: $injuries,
            selectedDate: selectedDate,
            onSave: onSave
        )
        .opacity(isPro ? 1 : 0.5)
        .blur(radius: isPro ? 0 : 4)
        .disabled(!isPro)
        .overlay {
            if !isPro {
                ZStack {
                    Color.black.opacity(0.001) // Capture taps
                        .onTapGesture {
                            // no-op capture
                        }

                    Button {
                        showProSheet = true
                    } label: {
                        VStack(spacing: 8) {
                            HStack {
                                let accent = themeManager.selectedTheme == .multiColour ? nil : themeManager.selectedTheme.accent(for: colorScheme)

                                if let accent {
                                    Image("logo")
                                        .resizable()
                                        .renderingMode(.template)
                                        .foregroundStyle(accent)
                                        .aspectRatio(contentMode: .fit)
                                        .frame(height: 40)
                                        .padding(.leading, 4)
                                        .offset(y: 6)
                                } else {
                                    Image("logo")
                                        .resizable()
                                        .renderingMode(.original)
                                        .aspectRatio(contentMode: .fit)
                                        .frame(height: 40)
                                        .padding(.leading, 4)
                                        .offset(y: 6)
                                }
                                
                                Text("PRO")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .fill(
                                                accent.map {
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [$0, $0.opacity(0.85)]),
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                } ?? LinearGradient(
                                                    gradient: Gradient(colors: [
                                                        Color(red: 0.74, green: 0.43, blue: 0.97),
                                                        Color(red: 0.83, green: 0.99, blue: 0.94)
                                                    ]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    )
                                    .offset(y: 6)
                            }
                            .padding(.bottom, 5)
                                
                            Text("Trackerio Pro")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Text("Upgrade to unlock Injury Tracking + More")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .glassEffect(in: .rect(cornerRadius: 16.0))
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showProSheet) {
                        ProSubscriptionView()
                    }
                }
            }
        }
    }
}
