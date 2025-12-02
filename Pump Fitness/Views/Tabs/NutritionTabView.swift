import SwiftUI

struct NutritionTabView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var showCalendar = false
    @State private var selectedDate = Date()
    @State private var showAccountsView = false
    @State private var showAddSheet = false
    @State private var showCalorieGoalSheet = false
    @State private var calorieGoal: Int = 2500
    @State private var selectedMacroGoal: MacroFocusOption = .balanced
    @State private var showMacroEditorSheet = false
    @State private var macroMetrics: [MacroMetric] = MacroPreset.defaultActiveMetrics

    private let maintenanceCalories: Int = 2200
    private let consumedCalories: Int = 3100

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
                            accentColorOverride: accentOverride,
                            caloriesMaintenance: maintenanceCalories,
                            caloriesConsumed: consumedCalories,
                            calorieGoal: calorieGoal,
                            onEditGoal: { showCalorieGoalSheet = true }
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
                            accentColorOverride: accentOverride,
                            macros: macroMetrics,
                            onEditMacros: { showMacroEditorSheet = true }
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
        .sheet(isPresented: $showMacroEditorSheet) {
            MacroEditorSheet(
                macros: $macroMetrics,
                tint: accentOverride ?? .accentColor,
                onDone: { showMacroEditorSheet = false }
            )
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showCalorieGoalSheet) {
            CalorieGoalEditorSheet(
                selectedMacroFocus: $selectedMacroGoal,
                calorieGoal: $calorieGoal,
                maintenanceCalories: maintenanceCalories,
                tint: accentOverride ?? .accentColor,
                onDone: { showCalorieGoalSheet = false }
            )
            .presentationDetents([.medium, .large])
        }
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

private enum NutritionMacroLimits {
    static let maxTrackedMacros = 11
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
    var caloriesMaintenance: Int = 2200
    var caloriesConsumed: Int = 3100
    var calorieGoal: Int
    var onEditGoal: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Maintenance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(caloriesMaintenance)")
                        .font(.title2)
                }
                Spacer()
                VStack {
                    Text("Consumed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(caloriesConsumed)")
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
                        Button(action: onEditGoal) {
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
    var macros: [MacroMetric]
    var onEditMacros: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            let items: [MacroSummaryItem] = macros.map { .metric($0) } + [.add]

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
                            case let .metric(metric):
                                let displayColor = accentColorOverride ?? metric.color
                                VStack(spacing: 2) {
                                    ZStack {
                                        Circle()
                                            .stroke(displayColor.opacity(0.18), lineWidth: 6)
                                            .frame(width: 54, height: 54)
                                        Circle()
                                            .trim(from: 0, to: metric.percent)
                                            .stroke(displayColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                            .rotationEffect(.degrees(-90))
                                            .frame(width: 54, height: 54)
                                        Text(metric.consumedLabel)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(displayColor)
                                    }
                                    .padding(.bottom, 10)
                                    Text("\(metric.allowedLabel)")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                    Text(metric.title)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 0)
                                }
                                .frame(maxWidth: .infinity, minHeight: NutritionLayout.macroTileMinHeight, alignment: .top)
                            case .add:
                                MacroEditButton(
                                    tint: Color(.systemGray3),
                                    minHeight: NutritionLayout.macroTileMinHeight,
                                    action: onEditMacros
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

private struct CalorieGoalEditorSheet: View {
    @Binding var selectedMacroFocus: MacroFocusOption
    @Binding var calorieGoal: Int
    var maintenanceCalories: Int
    var tint: Color
    var onDone: () -> Void

    @State private var goalText: String = ""
    @State private var isApplyingPreset = false
    @State private var originalGoal: Int = 0
    @State private var originalFocus: MacroFocusOption = .balanced
    @FocusState private var isGoalFieldFocused: Bool

    private let pillColumns = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Macro goal")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        LazyVGrid(columns: pillColumns, alignment: .leading, spacing: 12) {
                            ForEach(MacroFocusOption.allCases) { option in
                                SelectablePillComponent(
                                    label: option.displayName,
                                    isSelected: selectedMacroFocus == option,
                                    selectedTint: tint
                                ) {
                                    handleMacroSelection(option)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Daily calorie goal")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        HStack {
                            TextField("0", text: $goalText)
                                .keyboardType(.numberPad)
                                .focused($isGoalFieldFocused)
                                .textFieldStyle(.plain)
                            Text("cal")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .glassEffect(in: .rect(cornerRadius: 16.0))
                    }

                    if selectedMacroFocus != .other {
                        let recommendation = CalorieGoalPlanner.recommendation(for: selectedMacroFocus, maintenanceCalories: maintenanceCalories)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Recommended for \(selectedMacroFocus.displayName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(maintenanceCalories) cal \(recommendation.adjustmentSymbol) \(recommendation.adjustmentPercentText) = \(recommendation.value) cal")
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundStyle(tint)
                            Text("Based on your maintenance of \(maintenanceCalories) cal. Adjust manually if you need a custom target.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Custom targets override the preset strategy.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
            .navigationTitle("Edit Calorie Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        cancelEditing()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        commitGoal()
                        onDone()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            goalText = String(calorieGoal)
            originalGoal = calorieGoal
            originalFocus = selectedMacroFocus
        }
        .onChange(of: goalText) { _, newValue in
            handleGoalTextChange(newValue)
        }
    }

    private func handleMacroSelection(_ option: MacroFocusOption) {
        selectedMacroFocus = option
        guard option != .other else { return }
        let recommended = CalorieGoalPlanner.recommendation(for: option, maintenanceCalories: maintenanceCalories).value
        isApplyingPreset = true
        goalText = String(recommended)
        calorieGoal = recommended
    }

    private func handleGoalTextChange(_ newValue: String) {
        let sanitized = newValue.filter { $0.isNumber }
        if sanitized != newValue {
            goalText = sanitized
            return
        }

        guard !isApplyingPreset else {
            isApplyingPreset = false
            return
        }

        guard let value = Int(sanitized), value > 0 else { return }
        calorieGoal = value
        if selectedMacroFocus != .other {
            selectedMacroFocus = .other
        }
    }

    private func commitGoal() {
        if let value = Int(goalText), value > 0 {
            calorieGoal = value
        }
    }

    private func cancelEditing() {
        calorieGoal = originalGoal
        selectedMacroFocus = originalFocus
        onDone()
    }
}

private enum CalorieGoalPlanner {
    struct Recommendation {
        let value: Int
        let adjustmentPercent: Double

        var adjustmentSymbol: String {
            adjustmentPercent >= 0 ? "+" : "-"
        }

        var adjustmentPercentText: String {
            let absolutePercent = abs(adjustmentPercent * 100)
            let formatted = absolutePercent.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", absolutePercent) : String(format: "%.1f", absolutePercent)
            return "\(formatted)%"
        }
    }

    static func recommendation(for focus: MacroFocusOption, maintenanceCalories: Int) -> Recommendation {
        guard maintenanceCalories > 0 else {
            return Recommendation(value: 0, adjustmentPercent: 0)
        }

        let adjustment = adjustmentPercent(for: focus)
        let baseline = Double(maintenanceCalories)
        let adjusted = baseline * (1 + adjustment)
        let clamped = min(max(adjusted, 1200), 4500)
        let rounded = Int(clamped.rounded())
        return Recommendation(value: rounded, adjustmentPercent: adjustment)
    }

    static func recommendedCalories(for focus: MacroFocusOption, maintenanceCalories: Int) -> Int {
        recommendation(for: focus, maintenanceCalories: maintenanceCalories).value
    }

    private static func adjustmentPercent(for focus: MacroFocusOption) -> Double {
        switch focus {
        case .highProtein:
            return 0.05
        case .balanced:
            return 0
        case .lowCarb:
            return -0.1
        case .other:
            return 0
        }
    }
}

private enum MacroSummaryItem: Identifiable {
    case metric(MacroMetric)
    case add

    var id: String {
        switch self {
        case .metric(let metric):
            return metric.id.uuidString
        case .add:
            return "macro-add-button"
        }
    }
}

private struct MacroEditButton: View {
    var tint: Color
    var minHeight: CGFloat
    var action: () -> Void
    var body: some View {
        Button(action: action) {
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

struct MacroMetric: Identifiable {
    enum Source: Equatable {
        case preset(MacroPreset)
        case custom
    }

    let id: UUID
    var title: String
    var percent: Double
    var currentLabel: String
    var targetLabel: String
    var color: Color
    var source: Source

    init(
        id: UUID = UUID(),
        title: String,
        percent: Double,
        currentLabel: String,
        targetLabel: String,
        color: Color,
        source: Source
    ) {
        self.id = id
        self.title = title
        self.percent = percent
        self.currentLabel = currentLabel
        self.targetLabel = targetLabel
        self.color = color
        self.source = source
    }

    var isCustom: Bool {
        if case .custom = source { return true }
        return false
    }

    var consumedLabel: String { currentLabel }
    var allowedLabel: String { targetLabel }
}

enum MacroPreset: String, CaseIterable, Identifiable {
    case protein
    case carbs
    case fats
    case fibre
    case water
    case sodium
    case potassium
    case sugar

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .protein: return "Protein"
        case .carbs: return "Carbs"
        case .fats: return "Fats"
        case .fibre: return "Fibre"
        case .water: return "Water"
        case .sodium: return "Sodium"
        case .potassium: return "Potassium"
        case .sugar: return "Sugar"
        }
    }

    var consumedLabel: String {
        switch self {
        case .protein: return "72g"
        case .carbs: return "110g"
        case .fats: return "38g"
        case .fibre: return "22g"
        case .water: return "2.0L"
        case .sodium: return "1.8g"
        case .potassium: return "3.1g"
        case .sugar: return "35g"
        }
    }

    var allowedLabel: String {
        switch self {
        case .protein: return "100g"
        case .carbs: return "200g"
        case .fats: return "70g"
        case .fibre: return "30g"
        case .water: return "2.5L"
        case .sodium: return "2.3g"
        case .potassium: return "4.7g"
        case .sugar: return "50g"
        }
    }

    var percent: Double {
        switch self {
        case .protein: return 0.72
        case .carbs: return 0.55
        case .fats: return 0.43
        case .fibre: return 0.6
        case .water: return 0.8
        case .sodium: return 0.78
        case .potassium: return 0.66
        case .sugar: return 0.7
        }
    }

    var color: Color {
        switch self {
        case .protein: return .green
        case .carbs: return .blue
        case .fats: return .orange
        case .fibre: return Color(.systemTeal)
        case .water: return .cyan
        case .sodium: return .pink
        case .potassium: return Color(.systemPurple)
        case .sugar: return .red
        }
    }

    var detail: String {
        "Target \(allowedLabel)"
    }
}

private extension MacroPreset {
    static var defaultActiveMetrics: [MacroMetric] {
        [.preset(.protein), .preset(.carbs), .preset(.fats), .preset(.water)]
    }
}

private extension MacroMetric {
    static func preset(_ preset: MacroPreset) -> MacroMetric {
        MacroMetric(
            title: preset.displayName,
            percent: preset.percent,
            currentLabel: preset.consumedLabel,
            targetLabel: preset.allowedLabel,
            color: preset.color,
            source: .preset(preset)
        )
    }

    static func custom(name: String, targetLabel: String, tint: Color) -> MacroMetric {
        MacroMetric(
            title: name,
            percent: 0.4,
            currentLabel: "–",
            targetLabel: targetLabel,
            color: tint.opacity(0.9),
            source: .custom
        )
    }
}

struct MacroEditorSheet: View {
    @Binding var macros: [MacroMetric]
    var tint: Color
    var onDone: () -> Void

    @State private var workingMacros: [MacroMetric] = []
    @State private var newCustomName: String = ""
    @State private var newCustomTarget: String = ""
    @State private var hasLoadedState = false

    private var canAddMoreMacros: Bool {
        workingMacros.count < NutritionMacroLimits.maxTrackedMacros
    }

    private var canAddCustomMacro: Bool {
        canAddMoreMacros && !newCustomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !newCustomTarget.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    MacroEditorSummaryChip(
                        currentCount: workingMacros.count,
                        maxCount: NutritionMacroLimits.maxTrackedMacros,
                        tint: tint
                    )

                    if !workingMacros.isEmpty {
                        MacroEditorSection(title: "Tracked Macros") {
                            VStack(spacing: 16) {
                                ForEach($workingMacros) { $metric in
                                    MacroTargetEditorRow(
                                        metric: $metric,
                                        tint: tint,
                                        onRemove: { removeMetric(metric.id) }
                                    )
                                }
                            }
                        }
                    }

                    MacroEditorSection(title: "Quick Add") {
                        VStack(spacing: 12) {
                            ForEach(MacroPreset.allCases) { preset in
                                MacroPresetRow(
                                    preset: preset,
                                    isSelected: isPresetSelected(preset),
                                    canAddMore: canAddMoreMacros,
                                    tint: tint,
                                    onToggle: { togglePreset(preset) }
                                )
                            }
                        }
                    }

                    MacroEditorSection(title: "Custom Macros") {
                        VStack(spacing: 16) {
                            CustomMacroComposer(
                                name: $newCustomName,
                                target: $newCustomTarget,
                                tint: tint,
                                isDisabled: !canAddCustomMacro,
                                canAddMore: canAddMoreMacros,
                                onAdd: addCustomMetric
                            )

                            Text("Give it a name and target, then tap plus to add it to your dashboard. You can track up to \(NutritionMacroLimits.maxTrackedMacros) macros.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("Edit Macros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDone() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        macros = workingMacros
                        onDone()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear(perform: loadInitialState)
    }

    private func loadInitialState() {
        guard !hasLoadedState else { return }
        workingMacros = macros
        hasLoadedState = true
    }

    private func togglePreset(_ preset: MacroPreset) {
        if isPresetSelected(preset) {
            workingMacros.removeAll { metric in
                if case .preset(preset) = metric.source { return true }
                return false
            }
        } else if canAddMoreMacros {
            workingMacros.append(.preset(preset))
        }
    }

    private func isPresetSelected(_ preset: MacroPreset) -> Bool {
        workingMacros.contains { metric in
            if case .preset(preset) = metric.source { return true }
            return false
        }
    }

    private func removeMetric(_ id: UUID) {
        workingMacros.removeAll { $0.id == id }
    }

    private func addCustomMetric() {
        guard canAddCustomMacro else { return }
        let trimmedName = newCustomName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTarget = newCustomTarget.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedTarget.isEmpty else { return }

        let newMetric = MacroMetric.custom(name: trimmedName, targetLabel: trimmedTarget, tint: tint)
        workingMacros.append(newMetric)
        newCustomName = ""
        newCustomTarget = ""
    }
}

private struct MacroEditorSection<Content: View>: View {
    var title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 16, content: content)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassEffect(in: .rect(cornerRadius: 20.0))
    }
}

private struct MacroPresetRow: View {
    var preset: MacroPreset
    var isSelected: Bool
    var canAddMore: Bool
    var tint: Color
    var onToggle: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(preset.color.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "chart.bar.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(preset.color)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(preset.displayName)
                    .font(.subheadline.weight(.semibold))
                Text(preset.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onToggle) {
                Image(systemName: isSelected ? "minus.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.red : tint)
            }
            .buttonStyle(.plain)
            .disabled(!isSelected && !canAddMore)
            .opacity(!isSelected && !canAddMore ? 0.3 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassEffect(in: .rect(cornerRadius: 18.0))
    }
}

private struct MacroTargetEditorRow: View {
    @Binding var metric: MacroMetric
    var tint: Color
    var onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(metric.color.opacity(0.18))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle()
                            .stroke(metric.color.opacity(0.6), lineWidth: 1)
                    )

                if metric.isCustom {
                    TextField("Custom macro", text: $metric.title)
                        .textInputAutocapitalization(.words)
                        .textFieldStyle(.plain)
                } else {
                    Text(metric.title)
                        .font(.headline)
                }

                Spacer()

                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .semibold))
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Target / Max")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                HStack {
                    TextField("e.g. 100g", text: $metric.targetLabel)
                        .textFieldStyle(.plain)
                }
                .padding()
                .glassEffect(in: .rect(cornerRadius: 16.0))
            }
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 20.0))
    }
}

private struct CustomMacroComposer: View {
    @Binding var name: String
    @Binding var target: String
    var tint: Color
    var isDisabled: Bool
    var canAddMore: Bool
    var onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Create your own")
                .font(.footnote)
                .foregroundStyle(.secondary)

            TextField("Macro name", text: $name)
                .textInputAutocapitalization(.words)
                .padding()
                .glassEffect(in: .rect(cornerRadius: 16.0))

            HStack(spacing: 12) {
                TextField("Target (e.g. 30g)", text: $target)
                    .textInputAutocapitalization(.never)
                    .textFieldStyle(.plain)
                    .padding()
                    .glassEffect(in: .rect(cornerRadius: 16.0))

                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(
                            Circle()
                                .fill(isDisabled ? Color.gray.opacity(0.4) : tint)
                        )
                }
                .buttonStyle(.plain)
                .disabled(isDisabled)
            }

            if !canAddMore {
                Text("You've reached the maximum number of macros.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}

private struct MacroEditorSummaryChip: View {
    var currentCount: Int
    var maxCount: Int
    var tint: Color

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Tracked Macros")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("\(currentCount) / \(maxCount)")
                    .font(.title3.weight(.semibold))
            }
            Spacer()
            ProgressView(value: Double(currentCount), total: Double(maxCount))
                .tint(tint)
                .frame(width: 120)
        }
        .padding()
        .glassEffect(in: .rect(cornerRadius: 18.0))
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
