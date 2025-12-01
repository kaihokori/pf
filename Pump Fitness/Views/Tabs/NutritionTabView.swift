import SwiftUI

struct NutritionTabView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var showCalendar = false
    @State private var selectedDate = Date()
    @State private var showAccountsView = false
    @State private var showAddSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundView
                ScrollView {
                    VStack(spacing: 0) {
                        HeaderComponent(
                            showCalendar: $showCalendar,
                            selectedDate: $selectedDate,
                            profileImage: Image("profile"),
                            onProfileTap: { showAccountsView = true }
                        )

                        Text("Calorie Tracking")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 18)
                            .padding(.top, 48)

                        CalorieSummary(
                            accentColorOverride: accentOverride
                        )
                        .padding(.top, 20)

                        Button {
                            // 
                        } label: {
                            Label("Log Intake", systemImage: "plus")
                                .font(.callout.weight(.semibold))
                                .padding(.vertical, 18)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .glassEffect(in: .rect(cornerRadius: 16.0))
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 12)
                        .buttonStyle(.plain)

                        Text("Macro Tracking")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 18)
                            .padding(.top, 48)

                        MacroSummary(
                            accentColorOverride: accentOverride
                        )

                        Text("Daily Summary")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 18)
                            .padding(.top, 48)
                        
                        DailyMealLogSection(
                            accentColorOverride: accentOverride
                        )

                        Text("Supplement Tracking")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 18)
                            .padding(.top, 48)

                        SupplementTrackingView(
                            accentColorOverride: accentOverride
                        )

                        Text("Intermittent Fasting")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 18)

                        FastingTimerCard(
                            accentColorOverride: accentOverride
                        )

                        ShareProgressCTA(accentColor: accentOverride ?? .accentColor)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 24)
                        
                        Button {
                            // 
                        } label: {
                            Label("Hide/Show Sections", systemImage: "eye.slash")
                                .font(.callout.weight(.semibold))
                                .padding(.vertical, 18)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .glassEffect(in: .rect(cornerRadius: 16.0))
                        }
                        .padding(.horizontal, 18)
                        .buttonStyle(.plain)
                    }
                }
                if showCalendar {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                        .onTapGesture { showCalendar = false }
                    CalendarComponent(selectedDate: $selectedDate, showCalendar: $showCalendar)
                }
            }
            .navigationDestination(isPresented: $showAccountsView) {
                AccountsView()
            }
        }
        .tint(accentOverride ?? .accentColor)
        .accentColor(accentOverride ?? .accentColor)
        .sheet(isPresented: $showAddSheet) {
            AddNutritionView()
                .environmentObject(themeManager)
        }
    }
}

private enum NutritionLayout {
    static let macroTileMinHeight: CGFloat = 128
    static let supplementTileMinHeight: CGFloat = 150
}

private extension NutritionTabView {
    @ViewBuilder
    var backgroundView: some View {
        if themeManager.selectedTheme == .multiColour {
            GradientBackground(theme: .nutrition)
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

struct CalorieSummary: View {
    var accentColorOverride: Color?
    let caloriesMaintenance: Int = 2200
    let caloriesConsumed: Int = 3100
    let calorieGoal: Int = 2500

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Maintenance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(caloriesConsumed)")
                        .font(.title2)
                }
                Spacer()
                VStack {
                    Text("Consumed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(calorieGoal)")
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Goal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button(action: {
                          
                        }) {
                            Image(systemName: "pencil")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                    Text("\(calorieGoal)")
                        .font(.title2)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .padding(.horizontal, 18)
    }
}

struct MacroSummary: View {
    var accentColorOverride: Color?
    let macros: [(type: String, percent: Double, color: Color, consumed: String, allowed: String)] = [
        ("Protein", 0.72, .green, "72g", "100g"),
        ("Carbs", 0.55, .blue, "110g", "200g"),
        ("Fats", 0.43, .orange, "38g", "70g"),
        ("Water", 0.80, .cyan, "2.0L", "2.5L")
    ]

    var body: some View {
        VStack(spacing: 12) {
            let items: [MacroSummaryItem] = macros.map { macro in
                .macro(type: macro.type, percent: macro.percent, color: macro.color, consumed: macro.consumed, allowed: macro.allowed)
            } + [.add]

            let macroRows: [[MacroSummaryItem]] = {
                let count = items.count
                if count <= 4 {
                    return [items]
                } else if count == 5 {
                    return [Array(items.prefix(3)), Array(items.suffix(2))]
                } else if count == 6 {
                    return [Array(items.prefix(3)), Array(items.suffix(3))]
                } else if count == 7 {
                    return [Array(items.prefix(4)), Array(items.suffix(3))]
                } else {
                    // For 8+, split into rows of 4
                    return stride(from: 0, to: count, by: 4).map { i in
                        Array(items[i..<min(i+4, count)])
                    }
                }
            }()

            VStack(spacing: 16) {
                ForEach(macroRows.indices, id: \.self) { rowIdx in
                    HStack {
                        Spacer(minLength: 0)
                        ForEach(macroRows[rowIdx]) { item in
                            switch item {
                            case let .macro(type, percent, color, consumed, allowed):
                                let displayColor = accentColorOverride ?? color
                                VStack(spacing: 2) {
                                    ZStack {
                                        Circle()
                                            .stroke(displayColor.opacity(0.18), lineWidth: 6)
                                            .frame(width: 54, height: 54)
                                        Circle()
                                            .trim(from: 0, to: percent)
                                            .stroke(displayColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                            .rotationEffect(.degrees(-90))
                                            .frame(width: 54, height: 54)
                                        Text(consumed)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(displayColor)
                                    }
                                    .padding(.bottom, 10)
                                    Text("\(allowed)")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                    Text(type)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 0)
                                }
                                .frame(maxWidth: .infinity, minHeight: NutritionLayout.macroTileMinHeight, alignment: .top)
                            case .add:
                                MacroAddButton(
                                    tint: Color(.systemGray3),
                                    minHeight: NutritionLayout.macroTileMinHeight
                                )
                            }
                        }
                        .padding(.bottom, -10)
                        Spacer(minLength: 0)
                    }
                }
                .padding(.top, 10)
            }
            .padding(.horizontal)
            .padding(.top, 16)
        }
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .padding(.horizontal, 18)
        .padding(.top, 24)
    }
}

private enum MacroSummaryItem: Identifiable {
    case macro(type: String, percent: Double, color: Color, consumed: String, allowed: String)
    case add

    var id: String {
        switch self {
        case .macro(let type, _, _, _, _):
            return type
        case .add:
            return "macro-add-button"
        }
    }
}

private struct MacroAddButton: View {
    var tint: Color
    var minHeight: CGFloat
    var body: some View {
        Button(action: {}) {
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .stroke(tint.opacity(0.18), lineWidth: 6)
                        .frame(width: 54, height: 54)
                    Circle()
                        .stroke(style: StrokeStyle(lineWidth: 6, dash: [4]))
                        .foregroundStyle(tint.opacity(0.4))
                        .frame(width: 54, height: 54)
                    Image(systemName: "pencil")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(tint)
                }
                .padding(.bottom, 10)
                Text("Edit Macros")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .top)
        .buttonStyle(.plain)
    }
}

struct DailyMealLogSection: View {
    var accentColorOverride: Color?
    private let meals: [MealLogEntry] = MealLogEntry.sampleEntries
    private var totalCalories: Int {
        meals.reduce(0) { $0 + $1.calorieValue }
    }
    @State private var isExpanded = false

    var body: some View {
        let tint = accentColorOverride ?? .accentColor
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Spacer()
                Label("What You've Eaten", systemImage: "magnifyingglass")
                    .font(.callout.weight(.semibold))
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    isExpanded.toggle()
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(meals) { meal in
                        HStack(alignment: .top, spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(tint.opacity(0.12))
                                    .frame(width: 42, height: 42)
                                Image(systemName: meal.iconName)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(tint)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(meal.title)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Text(meal.caloriesText)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Text(meal.itemsSummary)
                                    .font(.footnote)
                                    .foregroundStyle(Color.primary.opacity(0.85))
                            }
                        }
                        .padding(.vertical, 4)

                        if meal.id != meals.last?.id {
                            Divider()
                                .overlay(Color.white.opacity(0.12))
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
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

private struct MealLogEntry: Identifiable {
    let id = UUID()
    let title: String
    let calorieValue: Int
    let items: [String]
    let iconName: String

    var caloriesText: String { "\(calorieValue) cal" }
    var itemsSummary: String {
        items.joined(separator: ", ")
    }

    static let sampleEntries: [MealLogEntry] = [
        MealLogEntry(title: "Breakfast", calorieValue: 420, items: ["Overnight oats", "Blueberries", "Cold brew"], iconName: "sunrise.fill"),
        MealLogEntry(title: "Lunch", calorieValue: 610, items: ["Chicken power bowl", "Roasted veggies"], iconName: "fork.knife"),
        MealLogEntry(title: "Dinner", calorieValue: 780, items: ["Salmon + quinoa", "Side salad", "Sparkling water"], iconName: "moon.stars.fill"),
        MealLogEntry(title: "Snack", calorieValue: 210, items: ["Greek yogurt", "Almonds"], iconName: "cup.and.saucer.fill")
    ]
}

struct FastingTimerCard: View {
    var accentColorOverride: Color?
    let fastingState: String = "FASTING"
    let hoursElapsed: Double = 12.5
    let nextMeal: String = "Starts at 11:10 AM"
    @State private var showProtocolSheet = false
    @State private var selectedProtocol: FastingProtocolOption = .sixteenEight
    @State private var customHours: String = "16"
    @State private var customMinutes: String = "00"

    private var progress: Double {
        guard fastingDurationHours > 0 else { return 0 }
        return min(max(hoursElapsed / fastingDurationHours, 0), 1)
    }

    private var remainingHours: Double {
        max(fastingDurationHours - hoursElapsed, 0)
    }

    private var remainingTimeString: String {
        formattedTimeString(for: remainingHours)
    }

    private var elapsedTimeString: String {
        formattedTimeString(for: fastingDurationHours)
    }

    private var protocolDisplayText: String {
        switch selectedProtocol {
        case .twelveTwelve:
            return "12:12"
        case .fourteenTen:
            return "14:10"
        case .sixteenEight:
            return "16:8"
        case .custom:
            let hoursText = customHours.isEmpty ? "0" : customHours
            let minutesText = customMinutes.isEmpty ? "00" : customMinutes
            return "Custom \(hoursText):\(minutesText)"
        }
    }

    private var fastingDurationHours: Double {
        switch selectedProtocol {
        case .twelveTwelve:
            return 12
        case .fourteenTen:
            return 14
        case .sixteenEight:
            return 16
        case .custom:
            let hoursValue = Double(customHours) ?? 0
            let minutesValue = Double(customMinutes) ?? 0
            let normalizedMinutes = max(min(minutesValue, 59), 0)
            return max(hoursValue, 0) + normalizedMinutes / 60
        }
    }

    private func formattedTimeString(for hoursValue: Double) -> String {
        let safeHours = max(hoursValue, 0)
        let hoursComponent = Int(safeHours)
        let minutesComponent = Int((safeHours - Double(hoursComponent)) * 60)
        return String(format: "%02dh %02dm", hoursComponent, minutesComponent)
    }

    var body: some View {
        let tint = accentColorOverride ?? .green
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(protocolDisplayText)")
                        .font(.title)
                        .fontWeight(.semibold)
                }
                Spacer()
                Button {
                    showProtocolSheet = true
                } label: {
                    Label("\(elapsedTimeString)", systemImage: "pencil")
                        .font(.callout)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(tint.opacity(0.15))
                        )
                }
                .buttonStyle(.plain)
            }

            ZStack {
                Circle()
                    .stroke(tint.opacity(0.12), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(tint, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 6) {
                    Text("Time Left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(remainingTimeString)
                        .font(.title2)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 180)

            VStack(alignment: .leading, spacing: 6) {
                Text("Next Meal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(nextMeal)
                    .font(.headline)
                    .fontWeight(.medium)
            }

            Button {
                // hooking up to backend will start/stop fasting windows
            } label: {
                Text("End Fast")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(.white)
                    .glassEffect(accentColorOverride == nil ? .regular.tint(tint.opacity(0.2)) : .regular, in: .rect(cornerRadius: 16.0))
            }
        }
        .padding(20)
        // .glassEffect(accentColorOverride == nil ? .regular.tint(tint.opacity(0.2)) : .regular, in: .rect(cornerRadius: 16.0))
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 32)
        .sheet(isPresented: $showProtocolSheet) {
            FastingProtocolSheet(
                selectedProtocol: $selectedProtocol,
                customHours: $customHours,
                customMinutes: $customMinutes,
                tint: tint,
                onDone: { showProtocolSheet = false }
            )
            .presentationDetents([.medium, .large])
        }
    }
}

struct SupplementTrackingView: View {
    var accentColorOverride: Color?
    @State private var supplements: [SupplementItem] = SupplementItem.defaultSupplements

    var body: some View {
        let supplementTint = accentColorOverride ?? .orange
        let displayItems: [SupplementSummaryItem] =
            Array(supplements.enumerated()).map { .supplement(index: $0.offset, item: $0.element) } + [.add]

        let rows: [[SupplementSummaryItem]] = {
            let count = displayItems.count
            if count <= 4 {
                return [displayItems]
            } else if count == 5 {
                return [Array(displayItems.prefix(3)), Array(displayItems.suffix(2))]
            } else if count == 6 {
                return [Array(displayItems.prefix(3)), Array(displayItems.suffix(3))]
            } else if count == 7 {
                return [Array(displayItems.prefix(4)), Array(displayItems.suffix(3))]
            } else {
                return stride(from: 0, to: count, by: 4).map { index in
                    Array(displayItems[index..<min(index + 4, count)])
                }
            }
        }()

        VStack(spacing: 16) {
            VStack(spacing: 16) {
                ForEach(rows.indices, id: \.self) { rowIdx in
                    HStack {
                        Spacer(minLength: 0)
                        ForEach(rows[rowIdx]) { item in
                            switch item {
                            case let .supplement(index, supplement):
                                SupplementRing(
                                    item: supplement,
                                    tint: supplementTint
                                ) {
                                    toggleSupplement(at: index)
                                } onRemove: {
                                    removeSupplement(supplement)
                                }
                            case .add:
                                SupplementAddButton(
                                    tint: Color(.systemGray3),
                                    minHeight: NutritionLayout.supplementTileMinHeight
                                ) {
                                    addSupplement()
                                }
                            }
                        }
                        .padding(.bottom, -10)
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, -30)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 48)
    }

    private func toggleSupplement(at index: Int) {
        guard supplements.indices.contains(index) else { return }
        supplements[index].isTaken.toggle()
    }

    private func removeSupplement(_ supplement: SupplementItem) {
        supplements.removeAll { $0.id == supplement.id }
    }

    private func addSupplement() {
        // placeholder flow: append a generic supplement entry for now
        let unit = SupplementMeasurementUnit.allCases[supplements.count % SupplementMeasurementUnit.allCases.count]
        let defaultAmount: Double
        switch unit {
        case .gram:
            defaultAmount = 1.0
        case .milligram:
            defaultAmount = 50
        case .microgram:
            defaultAmount = 100
        }
        let newSupplement = SupplementItem(
            name: "Supplement #\(supplements.count + 1)",
            amount: defaultAmount,
            unit: unit
        )
        supplements.append(newSupplement)
    }
}

private struct ShareProgressCTA: View {
    var accentColor: Color

    private var gradientColors: [Color] {
        [
            accentColor,
            accentColor.opacity(0.75),
            accentColor.opacity(0.35)
        ]
    }

    private var glowColor: Color {
        accentColor.opacity(0.45)
    }

    var body: some View {
        Button {
            // TODO: Hook up to share sheet when backend is ready
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 48, height: 48)
                    Image(systemName: "party.popper.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Share Your Streak")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text("Show friends what you've achieved!")
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.85))
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(accentColor.opacity(0.25))
                    .clipShape(Circle())
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: glowColor, radius: 18, x: 0, y: 18)
            )
        }
        .buttonStyle(.plain)
    }
}

private enum SupplementSummaryItem: Identifiable {
    case supplement(index: Int, item: SupplementItem)
    case add

    var id: String {
        switch self {
        case let .supplement(_, item):
            return item.id.uuidString
        case .add:
            return "supplement-add"
        }
    }
}

private struct SupplementRing: View {
    var item: SupplementItem
    var tint: Color
    var onToggle: () -> Void
    var onRemove: () -> Void

    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .stroke(tint.opacity(0.18), lineWidth: 6)
                        .frame(width: 54, height: 54)
                    Circle()
                        .trim(from: 0, to: item.isTaken ? 1 : 0)
                        .stroke(tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 54, height: 54)
                    Image(systemName: item.isTaken ? "checkmark" : "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tint)
                }
                .padding(.bottom, 10)
                VStack(spacing: 2) {
                    Text(item.measurementDescription)
                          .font(.caption)
                          .foregroundStyle(.tertiary)
                          .padding(.top, 0)
                    Text(item.name)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(.secondary)
                        .frame(minHeight: 32, alignment: .top)
                }
                .frame(minHeight: 60, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, minHeight: NutritionLayout.supplementTileMinHeight, alignment: .top)
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive, action: onRemove) {
                Label("Remove", systemImage: "trash")
            }
        }
    }
}

private struct SupplementAddButton: View {
    var tint: Color
    var minHeight: CGFloat
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .stroke(tint.opacity(0.18), lineWidth: 6)
                        .frame(width: 54, height: 54)
                    Circle()
                        .stroke(style: StrokeStyle(lineWidth: 6, dash: [4]))
                        .foregroundStyle(tint.opacity(0.35))
                        .frame(width: 54, height: 54)
                    Image(systemName: "pencil")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(tint)
                }
                .padding(.bottom, 10)
                Text("Edit Supplement")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .top)
        .buttonStyle(.plain)
    }
}

private struct SupplementItem: Identifiable, Equatable {
    let id: UUID
    let name: String
    let amount: Double
    let unit: SupplementMeasurementUnit
    var isTaken: Bool

    init(id: UUID = UUID(), name: String, amount: Double, unit: SupplementMeasurementUnit, isTaken: Bool = false) {
        self.id = id
        self.name = name
        self.amount = amount
        self.unit = unit
        self.isTaken = isTaken
    }

    var measurementDescription: String {
        let whole = amount.rounded(.towardZero)
        let isWhole = amount.truncatingRemainder(dividingBy: 1) == 0
        let formattedAmount = isWhole ? String(Int(whole)) : String(format: "%.1f", amount)
        return "\(formattedAmount) \(unit.symbol)"
    }

    static let defaultSupplements: [SupplementItem] = [
        SupplementItem(name: "Vitamin C", amount: 1000, unit: .milligram),
        SupplementItem(name: "Vitamin D", amount: 50, unit: .microgram),
        SupplementItem(name: "Zinc", amount: 30, unit: .milligram),
        SupplementItem(name: "Iron", amount: 18, unit: .milligram),
        SupplementItem(name: "Magnesium", amount: 400, unit: .milligram),
        SupplementItem(name: "Magnesium Glycinate", amount: 2.5, unit: .gram),
        SupplementItem(name: "Melatonin", amount: 5, unit: .milligram)
    ]
}

private enum SupplementMeasurementUnit: CaseIterable {
    case gram
    case milligram
    case microgram

    var symbol: String {
        switch self {
        case .gram:
            return "g"
        case .milligram:
            return "mg"
        case .microgram:
            return "μg"
        }
    }
}

private struct FastingProtocolSheet: View {
    @Binding var selectedProtocol: FastingProtocolOption
    @Binding var customHours: String
    @Binding var customMinutes: String
    var tint: Color
    var onDone: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Fasting Window") {
                    ForEach(FastingProtocolOption.allCases, id: \.self) { option in
                        HStack {
                            Text(option.displayName)
                            Spacer()
                            if selectedProtocol == option {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(tint)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selectedProtocol = option }
                    }
                }

                if selectedProtocol == .custom {
                    Section("Custom Duration") {
                        HStack {
                            TextField("Hours", text: $customHours)
                                .keyboardType(.numberPad)
                            Text("hrs")
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            TextField("Minutes", text: $customMinutes)
                                .keyboardType(.numberPad)
                            Text("min")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Fasting Time")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDone() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDone() }
                }
            }
        }
    }
}

private enum FastingProtocolOption: CaseIterable {
    case twelveTwelve
    case fourteenTen
    case sixteenEight
    case custom

    var displayName: String {
        switch self {
        case .twelveTwelve:
            return "12:12"
        case .fourteenTen:
            return "14:10"
        case .sixteenEight:
            return "16:8"
        case .custom:
            return "Custom"
        }
    }
}

public extension NumberFormatter {
    static let withComma: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
}

#Preview {
    NutritionTabView()
        .environmentObject(ThemeManager())
}
