import SwiftUI
import PhotosUI
import UIKit

struct NutritionTabView: View {
    @Binding var account: Account
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var showCalendar = false
    @State private var selectedDate = Date()
    @State private var showAccountsView = false
    @State private var showAddSheet = false
    @State private var showCalorieGoalSheet = false
    @State private var calorieGoal: Int = 2500
    @State private var selectedMacroGoal: MacroFocusOption?
    @State private var showMacroEditorSheet = false
    @State private var macroMetrics: [MacroMetric] = MacroPreset.defaultActiveMetrics
    @State private var selectedMacroForLog: MacroMetric?
    @State private var consumedCalories: Int = 3100
    @State private var showConsumedSheet = false
    @State private var showProtocolSheet = false
    @State private var showSupplementEditor = false
    @State private var supplements: [SupplementItem] = SupplementItem.defaultSupplements
    @State private var nutritionSearchText: String = ""

    // Sample cravings list
    @State private var cravingsList: [CravingItem] = [
        CravingItem(name: "Dick", calories: 2060),
        CravingItem(name: "Spotted Dick", calories: 220),
        CravingItem(name: "Lesbian Sweet Biscuits", calories: 150)
    ]

    // Weekly progress state (lifted so header Add button can open editor)
    @State private var weeklyEntries: [WeeklyProgressEntry] = {
        let cal = Calendar.current
        let today = Date()
        let generated = (0..<7).map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: today) ?? today
            return WeeklyProgressEntry(date: date, weight: Double(165 + offset % 5), imagesCount: offset % 3, waterPercent: offset % 2 == 0 ? Double(60 + offset) : nil, bodyFatPercent: offset % 4 == 0 ? Double(18 + offset % 3) : nil)
        }
        return generated.sorted { $0.date < $1.date }
    }()
    @State private var weeklySelectedEntry: WeeklyProgressEntry? = nil
    @State private var weeklyShowEditor: Bool = false
    @State private var previewImageEntry: WeeklyProgressEntry? = nil
    // store in-memory picked images for entries (id -> image data)
    @State private var weeklyEntryImages: [UUID: Data] = [:]

    // Track which meal schedule cells are checked (by name)
    @State private var checkedMeals: Set<String> = []

    private let maintenanceCalories: Int = 2200

    private let caloriesBurnedToday: Int = 620
    private let caloriesBurnGoal: Int = 800
    private let stepsTakenToday: Int = 8_500
    private let stepsGoalToday: Int = 10_000

    private var stepsProgress: Double {
        guard stepsGoalToday > 0 else { return 0 }
        return min(max(Double(stepsTakenToday) / Double(stepsGoalToday), 0), 1)
    }

    private var formattedStepsTaken: String {
        NumberFormatter.withComma.string(from: NSNumber(value: stepsTakenToday)) ?? "\(stepsTakenToday)"
    }

    private var formattedStepsGoal: String {
        NumberFormatter.withComma.string(from: NSNumber(value: stepsGoalToday)) ?? "\(stepsGoalToday)"
    }
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundView
                ScrollView {
                    VStack(spacing: 0) {
                        HeaderComponent(
                            showCalendar: $showCalendar,
                            selectedDate: $selectedDate,
                            onProfileTap: { showAccountsView = true }
                        )
                        .environmentObject(account)
                        
                        HStack {
                            Text("Calorie Tracking")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)

                            Spacer()

                            Button {
                                showCalorieGoalSheet = true
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

                        CalorieSummary(
                            accentColorOverride: accentOverride,
                            caloriesMaintenance: maintenanceCalories,
                            caloriesConsumed: consumedCalories,
                            calorieGoal: calorieGoal,
                            onEditGoal: { showCalorieGoalSheet = true },
                            onAdjustConsumed: { showConsumedSheet = true }
                        )
                        .padding(.top, 14)

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
                        .padding(.top, 18)
                        .buttonStyle(.plain)

                        HStack {
                            Text("Macro Tracking")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)

                            Spacer()

                            Button {
                                showMacroEditorSheet = true
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

                        MacroSummary(
                            accentColorOverride: accentOverride,
                            macros: macroMetrics,
                            onEditMacros: { showMacroEditorSheet = true },
                            onMacroTap: { metric in
                                selectedMacroForLog = metric
                            }
                        )
                        
                        HStack {
                            Text("Meal Tracking")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)

                            Spacer()

                            Button {
                                // Meal Tracking edit — no action (kept for parity)
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
                        
                        MealScheduleSection(
                            accentColorOverride: accentOverride,
                            checkedMeals: $checkedMeals
                        )

                        DailyMealLogSection(
                            accentColorOverride: accentOverride,
                            weeklyEntries: weeklyEntries,
                            weekStartsOnMonday: false
                        )
                        
                        HStack {
                            Text("Supplement Tracking")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)

                            Spacer()

                            Button {
                                showSupplementEditor = true
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
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 18)
                        .padding(.top, 48)

                        SupplementTrackingView(
                            accentColorOverride: .orange,
                            supplements: $supplements
                        )

                        HStack {
                            Text("Cravings")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)

                            Spacer()

                            Button {
                                
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
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 18)
                        .padding(.top, 48)

                        Text("Craving something? List it below")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 18)
                            .padding(.top, 6)
                        
                        // Cravings list card
                        VStack(spacing: 0) {
                            ForEach(cravingsList.indices, id: \.self) { idx in
                                // Use a button so the entire row is tappable
                                let isChecked = cravingsList[idx].isChecked

                                Button {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                        cravingsList[idx].isChecked.toggle()
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(cravingsList[idx].name)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .strikethrough(isChecked, color: .secondary)
                                                .foregroundStyle(isChecked ? .secondary : .primary)

                                            Text("\(cravingsList[idx].calories) cal")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        ZStack {
                                            Circle()
                                                .fill(isChecked ? (accentOverride ?? .accentColor).opacity(0.16) : Color.clear)
                                                .frame(width: 40, height: 40)

                                            Image(systemName: isChecked ? "checkmark.circle.fill" : "checkmark.circle")
                                                .font(.title3)
                                                .foregroundStyle(isChecked ? (accentOverride ?? .accentColor) : Color(.systemGray3))
                                                .scaleEffect(isChecked ? 1.15 : 1.0)
                                                .rotationEffect(.degrees(isChecked ? 0 : 0))
                                                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isChecked)
                                        }
                                    }
                                    .padding(12)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        Group {
                                            if isChecked {
                                                (accentOverride ?? .accentColor).opacity(0.06)
                                            } else {
                                                Color.clear
                                            }
                                        }
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(.plain)

                                if idx != cravingsList.indices.last {
                                    Divider()
                                        .padding(.leading, 12)
                                }
                            }
                        }
                        .glassEffect(in: .rect(cornerRadius: 16.0))
                        .padding(.horizontal, 18)
                        .padding(.top, 12)

                        HStack {
                            Text("Intermittent Fasting")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)

                            Spacer()

                            Button {
                                showProtocolSheet = true
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
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 18)
                        .padding(.top, 48)

                        FastingTimerCard(
                            accentColorOverride: accentOverride,
                            showProtocolSheet: $showProtocolSheet
                        )
                        .padding(.horizontal, 18)
                        .padding(.top, 12)
                        
                        HStack {
                            Text("Weekly Progress")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)

                            Spacer()

                            Button {
                                showAddSheet = true
                            } label: {
                                Label("Add", systemImage: "plus")
                                    .font(.callout)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .glassEffect(in: .rect(cornerRadius: 18.0))
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 18)
                        .padding(.top, 48)

                        WeeklyProgressCarousel(accentColorOverride: accentOverride,
                                               entries: $weeklyEntries,
                                               selectedEntry: $weeklySelectedEntry,
                                               showEditor: $weeklyShowEditor,
                                               previewImageEntry: $previewImageEntry)
                            .padding(.horizontal, 18)
                            .padding(.top, 12)

                        ShareProgressCTA(accentColor: accentOverride ?? .accentColor)
                            .padding(.horizontal, 18)
                            .padding(.bottom, 24)
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
                AccountsView(account: $account)
            }
        }
        .tint(accentOverride ?? .accentColor)
        .accentColor(accentOverride ?? .accentColor)
        .sheet(isPresented: $showMacroEditorSheet) {
            MacroEditorSheet(
                macros: $macroMetrics,
                tint: accentOverride ?? .accentColor,
                isMultiColourTheme: themeManager.selectedTheme == .multiColour,
                macroFocus: selectedMacroGoal,
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
            WeeklyProgressAddSheet(
                tint: accentOverride ?? .accentColor,
                onSave: { entry, data in
                    weeklyEntries.append(entry)
                    if let d = data {
                        weeklyEntryImages[entry.id] = d
                    }
                    showAddSheet = false
                },
                onCancel: {
                    showAddSheet = false
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSupplementEditor) {
            SupplementEditorSheet(
                supplements: $supplements,
                tint: accentOverride ?? .orange,
                onDone: { showSupplementEditor = false }
            )
            .presentationDetents([.large, .medium])
        }
        .sheet(isPresented: $showConsumedSheet) {
            CalorieConsumedAdjustmentSheet(
                currentCalories: $consumedCalories,
                tint: accentOverride ?? .accentColor
            )
            .presentationDetents([.fraction(0.38)])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedMacroForLog) { metric in
            MacroLogEntrySheet(
                metric: metric,
                initialValue: numericValue(from: metric.currentLabel) ?? 0,
                unitSuffix: inferredUnitSuffix(for: metric)
            ) { newValue in
                updateMacro(metric, with: newValue)
                selectedMacroForLog = nil
            } onCancel: {
                selectedMacroForLog = nil
            }
            .presentationDetents([.fraction(0.38)])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $weeklySelectedEntry) { entry in
            WeeklyProgressAddSheet(
                tint: accentOverride ?? .accentColor,
                initialEntry: entry,
                initialImageData: weeklyEntryImages[entry.id],
                onSave: { updatedEntry, data in
                    if let idx = weeklyEntries.firstIndex(where: { $0.id == updatedEntry.id }) {
                        weeklyEntries[idx] = updatedEntry
                    }
                    if let d = data {
                        weeklyEntryImages[updatedEntry.id] = d
                    } else {
                        weeklyEntryImages.removeValue(forKey: updatedEntry.id)
                    }
                    weeklySelectedEntry = nil
                },
                onCancel: {
                    weeklySelectedEntry = nil
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        
        .fullScreenCover(item: $previewImageEntry) { entry in
            ZStack {
                Color.black.ignoresSafeArea()
                if let data = weeklyEntryImages[entry.id], let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFit()
                        .ignoresSafeArea()
                } else {
                    Image("placeholder")
                        .resizable()
                        .scaledToFit()
                        .ignoresSafeArea()
                }

                // Close button in the top-right corner
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            previewImageEntry = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.white)
                                .opacity(0.95)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 18)
                        .padding(.top, 44)
                    }
                    Spacer()
                }
            }
        }
    }
}

private struct CravingItem: Identifiable {
    let id = UUID()
    var name: String
    var calories: Int
    var isChecked: Bool = false
}
private struct WeeklyProgressAddSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date = Date()
    @State private var weightText: String = ""
    @State private var waterText: String = ""
    @State private var bodyFatText: String = ""

    @State private var photoItem: PhotosPickerItem? = nil
    @State private var photoData: Data? = nil

    var tint: Color = .accentColor
    var initialEntry: WeeklyProgressEntry? = nil
    var initialImageData: Data? = nil
    var onSave: (WeeklyProgressEntry, Data?) -> Void
    var onCancel: () -> Void = {}

    init(
        tint: Color = .accentColor,
        initialEntry: WeeklyProgressEntry? = nil,
        initialImageData: Data? = nil,
        onSave: @escaping (WeeklyProgressEntry, Data?) -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        self.tint = tint
        self.initialEntry = initialEntry
        self.initialImageData = initialImageData
        self.onSave = onSave
        self.onCancel = onCancel

        _date = State(initialValue: initialEntry?.date ?? Date())
        _weightText = State(initialValue: initialEntry != nil ? String(format: "%.1f", initialEntry!.weight) : "")
        _waterText = State(initialValue: initialEntry?.waterPercent != nil ? String(format: "%.0f", initialEntry!.waterPercent!) : "")
        _bodyFatText = State(initialValue: initialEntry?.bodyFatPercent != nil ? String(format: "%.1f", initialEntry!.bodyFatPercent!) : "")
        _photoData = State(initialValue: initialImageData)
        _photoItem = State(initialValue: nil)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        
                        DateComponent(
                            date: Binding(
                                get: { date },
                                set: { date = $0 }
                            ),
                            range: PumpDateRange.birthdate
                        )
                        .surfaceCard(12)
                    }


                    // Weight input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weight")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        HStack {
                            TextField("Weight", text: $weightText)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.plain)
                            Text("kg")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .surfaceCard(16)
                        .frame(maxWidth: .infinity)
                    }

                    HStack {
                        // Water % input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Water")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            HStack {
                                TextField("e.g. 50", text: $waterText)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(.plain)
                                Text("%")
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .surfaceCard(16)
                            .frame(maxWidth: .infinity)
                        }

                        Spacer()

                        // Body fat % input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Body Fat")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            HStack {
                                TextField("e.g. 18.5", text: $bodyFatText)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.plain)
                                Text("%")
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .surfaceCard(16)
                            .frame(maxWidth: .infinity)
                        }
                    }

                    // Photo controls: Upload/Replace (PhotosPicker) and Remove
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Photo")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            let uploadLabel = (photoData == nil) ? "Upload" : "Replace"

                            PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                                SelectablePillComponent(
                                    label: uploadLabel,
                                    isSelected: false,
                                    selectedTint: tint
                                ) {
                                    // PhotosPicker will present the picker when tapped
                                }
                                .allowsHitTesting(false)
                            }

                            if photoData != nil {
                                SelectablePillComponent(
                                    label: "Remove",
                                    isSelected: false,
                                    selectedTint: tint
                                ) {
                                    photoData = nil
                                    photoItem = nil
                                }
                            }
                        }
                        .padding(.bottom, 8)

                        if let data = photoData, let ui = UIImage(data: data) {
                            HStack {
                                Spacer()
                                Image(uiImage: ui)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 180, height: 240)
                                    .aspectRatio(3/4, contentMode: .fill)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(tint.opacity(0.12), lineWidth: 1)
                                    )
                                Spacer()
                            }
                            .padding(.top, 6)
                        } else {
                            HStack {
                                Spacer()
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.primary.opacity(0.05))
                                    .frame(width: 180, height: 240)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(tint.opacity(0.12), lineWidth: 1)
                                    )
                                    .overlay(
                                        Text("No photo")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    )
                                Spacer()
                            }
                            .padding(.top, 6)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
            .navigationTitle(initialEntry != nil ? "Edit Progress" : "Add Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let weight = Double(weightText) ?? 0
                        let images = photoData != nil ? 1 : 0
                        let water = Double(waterText)
                        let bf = Double(bodyFatText)
                        let entry = WeeklyProgressEntry(date: date, weight: weight, imagesCount: images, waterPercent: water, bodyFatPercent: bf)
                        onSave(entry, photoData)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onChange(of: photoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            photoData = data
                        }
                    }
                }
            }
        }
    }
}

private enum NutritionLayout {
    static let macroTileMinHeight: CGFloat = 128
    static let supplementTileMinHeight: CGFloat = 150
}

private enum NutritionMacroLimits {
    static let maxTrackedMacros = 12
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

    func numericValue(from label: String) -> Double? {
        let allowed = CharacterSet(charactersIn: "0123456789.")
        let filteredScalars = label.unicodeScalars.filter { allowed.contains($0) }
        guard !filteredScalars.isEmpty else { return nil }
        return Double(String(String.UnicodeScalarView(filteredScalars)))
    }

    func unitSuffix(from label: String) -> String {
        let disallowed = CharacterSet(charactersIn: "0123456789.").union(.whitespacesAndNewlines)
        let scalars = label.unicodeScalars.filter { !disallowed.contains($0) }
        return String(String.UnicodeScalarView(scalars)).trimmingCharacters(in: .whitespaces)
    }

    func inferredUnitSuffix(for metric: MacroMetric) -> String {
        let currentSuffix = unitSuffix(from: metric.currentLabel)
        if !currentSuffix.isEmpty {
            return currentSuffix
        }
        let targetSuffix = unitSuffix(from: metric.targetLabel)
        return targetSuffix
    }

    func formattedMacroValue(_ value: Double, suffix: String) -> String {
        let isWhole = value.truncatingRemainder(dividingBy: 1) == 0
        let formatted = isWhole ? String(format: "%.0f", value) : String(format: "%.1f", value)
        return suffix.isEmpty ? formatted : "\(formatted)\(suffix)"
    }

    func updateMacro(_ metric: MacroMetric, with newValue: Double) {
        guard let index = macroMetrics.firstIndex(where: { $0.id == metric.id }) else { return }
        let suffix = inferredUnitSuffix(for: metric)
        macroMetrics[index].currentLabel = formattedMacroValue(newValue, suffix: suffix)
        if let targetValue = numericValue(from: macroMetrics[index].targetLabel), targetValue > 0 {
            let percent = min(max(newValue / targetValue, 0), 1)
            macroMetrics[index].percent = percent
        }
    }
}

struct CalorieSummary: View {
    var accentColorOverride: Color?
    var caloriesMaintenance: Int = 2200
    var caloriesConsumed: Int = 3100
    var calorieGoal: Int
    var onEditGoal: () -> Void
    var onAdjustConsumed: () -> Void = {}

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .center, spacing: 2) {
                    Text("Maintenance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(caloriesMaintenance)")
                        .font(.title2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                Button(action: onAdjustConsumed) {
                    VStack(spacing: 2) {
                        Text("Consumed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(caloriesConsumed)")
                            .font(.largeTitle)
                            .fontWeight(.semibold)
                            .foregroundStyle(caloriesConsumed > calorieGoal ? .red : .primary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                Spacer()
                VStack(alignment: .center, spacing: 2) {
                    Text("Goal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    Text("\(calorieGoal)")
                        .font(.title2)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Values are in calories (cal).")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, -8)
            .padding(.bottom, -8)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .padding(.horizontal, 18)
    }
}

struct SupplementEditorSheet: View {
    @Binding var supplements: [SupplementItem]
    var tint: Color
    var onDone: () -> Void

    // local working state
    @State private var working: [SupplementItem] = []
    @State private var newName: String = ""
    @State private var newTarget: String = ""
    @State private var hasLoaded = false

    // presets available in Quick Add (some may not be selected initially)
    private var presets: [SupplementItem] {
        [
            SupplementItem(name: "Vitamin D", amountLabel: "50 μg"),
            SupplementItem(name: "Vitamin B Complex", amountLabel: "50 mg"),
            SupplementItem(name: "Magnesium", amountLabel: "200 mg"),
            SupplementItem(name: "Probiotics", amountLabel: "10 Billion CFU"),
            SupplementItem(name: "Fish Oil", amountLabel: "1000 mg"),
            SupplementItem(name: "Ashwagandha", amountLabel: "500 mg"),
            SupplementItem(name: "Melatonin", amountLabel: "3 mg"),
            SupplementItem(name: "Calcium", amountLabel: "500 mg"),
            SupplementItem(name: "Iron", amountLabel: "18 mg"),
            SupplementItem(name: "Zinc", amountLabel: "15 mg"),
            SupplementItem(name: "Vitamin C", amountLabel: "1000 mg"),
            SupplementItem(name: "Caffeine", amountLabel: "200 mg")
        ]
    }

    private let maxTrackedSupplements = 12

    private var canAddMore: Bool { working.count < maxTrackedSupplements }
    private var canAddCustom: Bool { canAddMore && !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Summary chip
                    MacroEditorSummaryChip(
                        currentCount: working.count,
                        maxCount: maxTrackedSupplements,
                        tint: tint
                    )

                    // Tracked supplements
                    if !working.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            MacroEditorSectionHeader(title: "Tracked Supplements")
                            VStack(spacing: 12) {
                                ForEach(Array(working.enumerated()), id: \ .element.id) { idx, item in
                                    let binding = $working[idx]
                                    VStack(spacing: 8) {
                                        HStack(spacing: 12) {
                                            Circle()
                                                .fill(tint.opacity(0.15))
                                                .frame(width: 44, height: 44)
                                                .overlay(
                                                    Image(systemName: "pills.fill")
                                                        .foregroundStyle(tint)
                                                )

                                            VStack(alignment: .leading, spacing: 6) {
                                                TextField("Name", text: binding.name)
                                                    .font(.subheadline.weight(.semibold))
                                                TextField("Amount or note (e.g. 5 g or 3 scoops)", text: Binding(
                                                    get: { binding.customLabel.wrappedValue ?? item.measurementDescription },
                                                    set: { binding.customLabel.wrappedValue = $0 }
                                                ))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            }

                                            Spacer()

                                            Button(role: .destructive) {
                                                removeSupplement(item.id)
                                            } label: {
                                                Image(systemName: "trash")
                                                    .foregroundStyle(.red)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding()
                                        .surfaceCard(12)
                                    }
                                }
                            }
                        }
                    }

                    // Quick Add
                        if !presets.filter({ !isPresetSelected($0) }).isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                MacroEditorSectionHeader(title: "Quick Add")
                                VStack(spacing: 12) {
                                    ForEach(presets.filter { !isPresetSelected($0) }, id: \ .name) { preset in
                                        HStack(spacing: 14) {
                                            Circle()
                                                .fill(tint.opacity(0.15))
                                                .frame(width: 44, height: 44)
                                                .overlay(
                                                    Image(systemName: "chart.bar.fill")
                                                        .foregroundStyle(tint)
                                                )

                                            VStack(alignment: .leading) {
                                                Text(preset.name)
                                                    .font(.subheadline.weight(.semibold))
                                                Text(preset.measurementDescription)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }

                                            Spacer()

                                            Button(action: { togglePreset(preset) }) {
                                                Image(systemName: "plus.circle.fill")
                                                    .font(.system(size: 24, weight: .semibold))
                                                    .foregroundStyle(tint)
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

                    // Custom composer
                    VStack(alignment: .leading, spacing: 12) {
                        MacroEditorSectionHeader(title: "Custom Supplement")
                        VStack(spacing: 12) {
                            TextField("Supplement name", text: $newName)
                                .textInputAutocapitalization(.words)
                                .padding()
                                .surfaceCard(16)

                            HStack(spacing: 12) {
                                TextField("Amount or note (e.g. 5 g or 3 scoops)", text: $newTarget)
                                    .padding()
                                    .surfaceCard(16)

                                Button(action: addCustomSupplement) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 28, weight: .semibold))
                                        .foregroundStyle(tint)
                                }
                                .buttonStyle(.plain)
                                .disabled(!canAddCustom)
                                .opacity(!canAddCustom ? 0.4 : 1)
                            }

                            Text("Give it a name and amount, then tap plus to add it to your dashboard. You can track up to \(maxTrackedSupplements) supplements.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("Edit Supplements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDone() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        supplements = working
                        onDone()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear(perform: loadInitialState)
    }

    private func loadInitialState() {
        guard !hasLoaded else { return }
        working = supplements
        hasLoaded = true
    }

    private func togglePreset(_ preset: SupplementItem) {
        if isPresetSelected(preset) {
            working.removeAll { $0.name == preset.name }
        } else if canAddMore {
            working.append(preset)
        }
    }

    private func isPresetSelected(_ preset: SupplementItem) -> Bool {
        // Only consider a preset selected if any working item matches its name
        return working.contains { $0.name == preset.name }
    }

    private func removeSupplement(_ id: UUID) {
        // Find the supplement being removed
        guard let item = working.first(where: { $0.id == id }) else { return }
        // Always remove all with that name if it's a preset, so preset returns to Quick Add
        if presets.contains(where: { $0.name == item.name }) {
            working.removeAll { $0.name == item.name }
        } else {
            working.removeAll { $0.id == id }
        }
    }

    private func addCustomSupplement() {
        guard canAddCustom else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let new = SupplementItem(name: trimmed, amountLabel: newTarget.trimmingCharacters(in: .whitespacesAndNewlines), customLabel: newTarget.trimmingCharacters(in: .whitespacesAndNewlines))
        working.append(new)
        newName = ""
        newTarget = ""
    }
}

struct MacroSummary: View {
    var accentColorOverride: Color?
    var macros: [MacroMetric]
    var onEditMacros: () -> Void
    var onMacroTap: (MacroMetric) -> Void

    var body: some View {
        VStack(spacing: 12) {
            let items: [MacroSummaryItem] = macros.map { .metric($0) }

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
                                Button {
                                    onMacroTap(metric)
                                } label: {
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
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.bottom, -30)
                        Spacer(minLength: 0)
                    }
                    .padding(.bottom, 20)
                }
                .padding(.top, 10)
            }
            .padding(.horizontal)
            .padding(.top, 16)
        }
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .padding(.horizontal, 18)
        .padding(.top, 14)
    }
}

private struct CalorieGoalEditorSheet: View {
    @Binding var selectedMacroFocus: MacroFocusOption?
    @Binding var calorieGoal: Int
    var maintenanceCalories: Int
    var tint: Color
    var onDone: () -> Void

    @State private var goalText: String = ""
    @State private var isApplyingPreset = false
    @State private var originalGoal: Int = 0
    @State private var originalFocus: MacroFocusOption?
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
                        .surfaceCard(16)
                    }

                    if let focus = selectedMacroFocus, focus != .custom {
                        let recommendation = CalorieGoalPlanner.recommendation(for: focus, maintenanceCalories: maintenanceCalories)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Recommended for \(focus.displayName)")
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
                    } else if selectedMacroFocus == .custom {
                        Text("Custom targets override the preset strategy.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if maintenanceCalories <= 0 {
                        Text("Maintenance cannot be calculated unless you select \"Male\" or \"Female\".")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Maintenance is calculated with the Mifflin-St Jeor equation plus your workout schedule, then applies the selected macro focus multiplier to reach this calorie target.")
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
        guard option != .custom else { return }
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
        if selectedMacroFocus != .custom {
            selectedMacroFocus = .custom
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

enum CalorieGoalPlanner {
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
        case .custom:
            return 0
        }
    }
}

private enum MacroSummaryItem: Identifiable {
    case metric(MacroMetric)

    var id: String {
        switch self {
        case .metric(let metric):
            return metric.id.uuidString
        }
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
        case .protein: return .red
        case .carbs: return Color(.systemTeal)
        case .fats: return .orange
        case .fibre: return .green
        case .water: return .cyan
        case .sodium: return Color(.systemGray3)
        case .potassium: return Color(.systemPurple)
        case .sugar: return .yellow
        }
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
    var isMultiColourTheme: Bool
    var macroFocus: MacroFocusOption?
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
                        VStack(alignment: .leading, spacing: 12) {
                            MacroEditorSectionHeader(title: "Tracked Macros")
                            VStack(spacing: 16) {
                                ForEach(Array(workingMacros.enumerated()), id: \.element.id) { index, element in
                                    let binding = $workingMacros[index]
                                    let currentMetric = element
                                    MacroTargetEditorRow(
                                        metric: binding,
                                        tint: tint,
                                        displayColor: displayColor(for: currentMetric),
                                        onRemove: { removeMetric(currentMetric.id) }
                                    )
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        MacroEditorSectionHeader(title: "Quick Add")
                        VStack(spacing: 12) {
                            ForEach(MacroPreset.allCases.filter { !isPresetSelected($0) }) { preset in
                                MacroPresetRow(
                                    preset: preset,
                                    isSelected: isPresetSelected(preset),
                                    canAddMore: canAddMoreMacros,
                                    tint: tint,
                                    color: displayColor(for: preset),
                                    onToggle: { togglePreset(preset) }
                                )
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        MacroEditorSectionHeader(title: "Custom Macros")
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

                    MacroCalculationExplainer()
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

    private func displayColor(for metric: MacroMetric) -> Color {
        isMultiColourTheme ? metric.color : tint
    }

    private func displayColor(for preset: MacroPreset) -> Color {
        isMultiColourTheme ? preset.color : tint
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

private struct MacroEditorSectionHeader: View {
    var title: String

    var body: some View {
        Text(title.uppercased())
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
    }
}

private struct MacroPresetRow: View {
    var preset: MacroPreset
    var isSelected: Bool
    var canAddMore: Bool
    var tint: Color
    var color: Color
    var onToggle: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "chart.bar.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(color)
                )

            Text(preset.displayName)
                .font(.subheadline.weight(.semibold))

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
        .surfaceCard(18)
    }
}

private struct MacroTargetEditorRow: View {
    @Binding var metric: MacroMetric
    var tint: Color
    var displayColor: Color
    var onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(displayColor.opacity(0.18))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle()
                            .stroke(displayColor.opacity(0.6), lineWidth: 1)
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
                .padding(.trailing, 8)
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
                .surfaceCard(16)
            }
        }
        .padding(16)
        .surfaceCard(20)
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
            TextField("Macro name", text: $name)
                .textInputAutocapitalization(.words)
                .padding()
                .surfaceCard(16)

            HStack(spacing: 12) {
                TextField("Target (e.g. 30g)", text: $target)
                    .textInputAutocapitalization(.never)
                    .textFieldStyle(.plain)
                    .padding()
                    .surfaceCard(16)

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
        .surfaceCard(18)
    }
}

private struct CalorieConsumedAdjustmentSheet: View {
    @Binding var currentCalories: Int
    var tint: Color

    @Environment(\.dismiss) private var dismiss
    @State private var inputValue: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Adjust Consumed Calories")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Enter the amount to add or remove from today's total.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    TextField("0", text: $inputValue)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.plain)
                    Text("cal")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .surfaceCard(16)

                HStack(spacing: 16) {
                    Button(action: { handleAction(isAddition: false) }) {
                        Label("Remove", systemImage: "minus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button(action: { handleAction(isAddition: true) }) {
                        Label("Add", systemImage: "plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("Consumed Calories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func handleAction(isAddition: Bool) {
        guard let delta = Int(inputValue), delta > 0 else { return }
        let signedDelta = isAddition ? delta : -delta
        currentCalories = max(0, currentCalories + signedDelta)
        dismiss()
    }
}

private struct MacroLogEntrySheet: View {
    var metric: MacroMetric
    var initialValue: Double
    var unitSuffix: String
    var onSave: (Double) -> Void
    var onCancel: () -> Void

    @State private var inputValue: String = ""

    init(metric: MacroMetric, initialValue: Double, unitSuffix: String, onSave: @escaping (Double) -> Void, onCancel: @escaping () -> Void) {
        self.metric = metric
        self.initialValue = max(0, initialValue)
        self.unitSuffix = unitSuffix
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Log \(metric.title)")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Enter the amount to add or remove")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                TextField("0", text: $inputValue)
                    .keyboardType(.decimalPad)
                    .padding()
                    .surfaceCard(16)

                HStack(spacing: 16) {
                    Button(action: { handleAction(isAddition: false) }) {
                        Label("Remove", systemImage: "minus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button(action: { handleAction(isAddition: true) }) {
                        Label("Add", systemImage: "plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle(metric.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onCancel() }
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private func formattedValue(_ value: Double) -> String {
        let isWhole = value.truncatingRemainder(dividingBy: 1) == 0
        let formatted = isWhole ? String(format: "%.0f", value) : String(format: "%.1f", value)
        return unitSuffix.isEmpty ? formatted : "\(formatted)\(unitSuffix)"
    }

    private func handleAction(isAddition: Bool) {
        guard let delta = Double(inputValue), delta > 0 else { return }
        let signedDelta = isAddition ? delta : -delta
        let updatedValue = max(0, initialValue + signedDelta)
        onSave(updatedValue)
    }
}

struct DailyMealLogSection: View {
    var accentColorOverride: Color?
    var weeklyEntries: [WeeklyProgressEntry] = []
    var weekStartsOnMonday: Bool = false
    private let meals: [MealLogEntry] = MealLogEntry.sampleEntries
    @State private var isExpanded = false
    @State private var showWeeklyMacros = false

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
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .padding(.horizontal, 18)

        VStack(alignment: .leading, spacing: 16) {
            // New collapsible Weekly Macros section (separate from meals)
            HStack {
                Spacer()
                Label("Weekly Intake", systemImage: "chart.bar.xaxis")
                    .font(.callout.weight(.semibold))
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showWeeklyMacros.toggle()
                }
            }

            if showWeeklyMacros {
                VStack(alignment: .leading, spacing: 10) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            let cal = Calendar.current
                            let today = Date()
                            let weekday = cal.component(.weekday, from: today) // 1 = Sunday
                            let startIndex = weekStartsOnMonday ? 2 : 1
                            let offsetToStart = (weekday - startIndex + 7) % 7
                            let startOfWeek = cal.date(byAdding: .day, value: -offsetToStart, to: cal.startOfDay(for: today)) ?? today

                            let weekDates: [Date] = (0..<7).compactMap { i in
                                cal.date(byAdding: .day, value: i, to: startOfWeek)
                            }

                            ForEach(weekDates, id: \.self) { day in
                                // Determine whether this day should be considered a "future" day
                                let weekday = Calendar.current.component(.weekday, from: day) // 1 = Sunday, 5 = Thursday
                                let isFutureDay = weekday >= 5

                                if let entry = weeklyEntries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: day) }) {
                                    let idx = weeklyEntries.firstIndex(where: { $0.id == entry.id }) ?? 0
                                    let protein = Int(60 + Double(idx) * 3)
                                    let carbs = Int(140 - Double(idx) * 4)
                                    let fats = Int(30 + Double(idx) * 2)
                                    let calories = Int(1800 + Double(idx) * 120)
                                    let waterLitres = Double(1.8 + Double(idx) * 0.1)
                                    MacroDayColumn(date: day, tint: tint, calories: calories, protein: protein, carbs: carbs, fats: fats, waterLitres: waterLitres, isFuture: isFutureDay)
                                } else {
                                    let idx = Calendar.current.ordinality(of: .day, in: .year, for: day) ?? 0
                                    let protein = 60 + (idx % 5) * 3
                                    let carbs = 140 - (idx % 6) * 4
                                    let fats = 30 + (idx % 4) * 2
                                    let calories = 2000 + (idx % 7) * 100
                                    let waterLitres = 1.8 + Double(idx % 5) * 0.1
                                    MacroDayColumn(date: day, tint: tint, calories: calories, protein: protein, carbs: carbs, fats: fats, waterLitres: waterLitres, isFuture: isFutureDay)
                                }
                            }
                        }
                        .padding(.vertical, 4)
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
}

// New 2x2 Meal Schedule grid section
private struct MealScheduleSection: View {
    var accentColorOverride: Color?
    @Binding var checkedMeals: Set<String>

    private struct MealCell: Identifiable {
        let id = UUID()
        let key: String
        let icon: String
        let displayName: String
        let timeText: String
    }

    private let cells: [MealCell] = [
        MealCell(key: "Breakfast", icon: "sunrise.fill", displayName: "Breakfast", timeText: "7:30 AM"),
        MealCell(key: "Lunch", icon: "fork.knife", displayName: "Lunch", timeText: "12:30 PM"),
        MealCell(key: "Dinner", icon: "moon.stars.fill", displayName: "Dinner", timeText: "7:00 PM"),
        MealCell(key: "Snack", icon: "cup.and.saucer.fill", displayName: "Snack", timeText: "3:30 PM")
    ]

    var body: some View {
        let tint = accentColorOverride ?? .accentColor
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(cells) { cell in
                Button(action: {
                    withAnimation(.easeInOut) {
                        if checkedMeals.contains(cell.key) {
                            checkedMeals.remove(cell.key)
                        } else {
                            checkedMeals.insert(cell.key)
                        }
                    }
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill((checkedMeals.contains(cell.key) ? tint.opacity(0.18) : Color(.systemGray6)))
                                .frame(width: 44, height: 44)
                            if checkedMeals.contains(cell.key) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(tint)
                            } else {
                                Image(systemName: cell.icon)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.primary)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(cell.displayName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(checkedMeals.contains(cell.key) ? tint : .primary)
                            Text(cell.timeText)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(checkedMeals.contains(cell.key) ? tint.opacity(0.08) : Color.clear)
                    )
                    .glassEffect(in: .rect(cornerRadius: 12.0))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct MacroIndicatorRow: View {
    var label: String
    var color: Color
    var value: Double
    var maxValue: Double
    var unit: String = "g"

    private var displayText: String {
        switch unit {
        case "L":
            return String(format: "%.1fL", value)
        case "cal":
            return "\(Int(value))cal"
        default:
            return "\(Int(value))g"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(displayText)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            ProgressView(value: min(maxValue > 0 ? value / maxValue : 0, 1.0))
                .tint(color)
                .frame(height: 6)
        }
    }
}

private struct MacroDayColumn: View {
    var date: Date
    var tint: Color
    var calories: Int
    var protein: Int
    var carbs: Int
    var fats: Int
    var waterLitres: Double
    var isFuture: Bool = false

    private var dayLabel: String {
        let f = DateFormatter()
        f.dateFormat = "E"
        return f.string(from: date)
    }

    var body: some View {
        VStack(spacing: 10) {
            Text(dayLabel)
                .font(.caption)
                .fontWeight(.semibold)

            if isFuture {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Upcoming")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("No data yet")
                        .font(.caption2)
                        .foregroundStyle(.secondary.opacity(0.8))
                }
                Spacer()
            } else {
                VStack(spacing: 10) {
                    MacroIndicatorRow(label: "Calories", color: .primary, value: Double(calories), maxValue: 4000, unit: "cal")
                    MacroIndicatorRow(label: "Protein", color: .red, value: Double(protein), maxValue: 200)
                    MacroIndicatorRow(label: "Carbs", color: Color(.systemTeal), value: Double(carbs), maxValue: 400)
                    MacroIndicatorRow(label: "Fats", color: .orange, value: Double(fats), maxValue: 150)
                    MacroIndicatorRow(label: "Water", color: .cyan, value: waterLitres, maxValue: 4.0, unit: "L")
                }
                Spacer()
            }
        }
        .padding(EdgeInsets(top: 28, leading: 12, bottom: 12, trailing: 12))
        .frame(width: 140, height: 220)
        .liquidGlass(cornerRadius: 14)
    }
}

private struct LiquidGlassModifier: ViewModifier {
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 6)
    }
}

extension View {
    func liquidGlass(cornerRadius: CGFloat = 14) -> some View {
        modifier(LiquidGlassModifier(cornerRadius: cornerRadius))
    }
}

private struct MealLogEntry: Identifiable {
    let id = UUID()
    let title: String
    let items: [String]
    let iconName: String

    var itemsSummary: String {
        items.joined(separator: ", ")
    }

    static let sampleEntries: [MealLogEntry] = [
        MealLogEntry(title: "Breakfast", items: ["Overnight oats", "Blueberries", "Cold brew"], iconName: "sunrise.fill"),
        MealLogEntry(title: "Lunch", items: ["Chicken power bowl", "Roasted veggies"], iconName: "fork.knife"),
        MealLogEntry(title: "Dinner", items: ["Salmon + quinoa", "Side salad", "Sparkling water"], iconName: "moon.stars.fill"),
        MealLogEntry(title: "Snack", items: ["Greek yogurt", "Almonds"], iconName: "cup.and.saucer.fill")
    ]
}

struct FastingTimerCard: View {
    var accentColorOverride: Color?
    @Binding var showProtocolSheet: Bool
    let fastingState: String = "FASTING"
    let hoursElapsed: Double = 12.5
    let nextMeal: String = "Starts at 11:10 AM"
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
            Text("\(protocolDisplayText)")
                .font(.title)
                .fontWeight(.semibold)

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
                    .glassEffect(accentColorOverride == nil ? .regular.tint(tint) : .regular, in: .rect(cornerRadius: 16.0))
            }
        }
        .padding(20)
        .glassEffect(in: .rect(cornerRadius: 16.0))
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

private struct FastingProtocolSheet: View {
    @Binding var selectedProtocol: FastingProtocolOption
    @Binding var customHours: String
    @Binding var customMinutes: String
    var tint: Color
    var onDone: () -> Void
    private let pillColumns = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Fasting Window")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: pillColumns, alignment: .leading, spacing: 12) {
                            ForEach(FastingProtocolOption.allCases, id: \.self) { option in
                                SelectablePillComponent(
                                    label: option.displayName,
                                    isSelected: selectedProtocol == option,
                                    selectedTint: tint
                                ) {
                                    selectedProtocol = option
                                }
                            }
                        }
                    }

                    // Always-visible custom inputs so user can immediately edit hours/minutes.
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Custom Duration")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            HStack {
                                TextField("Hours", text: $customHours)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(.plain)
                                    .onChange(of: customHours) { _, _ in
                                        if selectedProtocol != .custom {
                                            selectedProtocol = .custom
                                        }
                                    }
                                Text("hrs")
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .surfaceCard(16)
                            .frame(maxWidth: .infinity)

                            HStack {
                                TextField("Minutes", text: $customMinutes)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(.plain)
                                    .onChange(of: customMinutes) { _, _ in
                                        if selectedProtocol != .custom {
                                            selectedProtocol = .custom
                                        }
                                    }
                                Text("min")
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .surfaceCard(16)
                            .frame(maxWidth: .infinity)
                        }
                    }

                    Text("Choose a fasting window that fits your routine. The custom option lets you specify an exact duration.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
            .navigationTitle("Fasting Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDone() }
                        .fontWeight(.semibold)
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

struct WeeklyProgressEntry: Identifiable, Equatable {
    let id: UUID
    var date: Date
    var weight: Double
    var imagesCount: Int
    var waterPercent: Double?
    var bodyFatPercent: Double?

    init(id: UUID = UUID(), date: Date, weight: Double, imagesCount: Int = 0, waterPercent: Double? = nil, bodyFatPercent: Double? = nil) {
        self.id = id
        self.date = date
        self.weight = weight
        self.imagesCount = imagesCount
        self.waterPercent = waterPercent
        self.bodyFatPercent = bodyFatPercent
    }
}

private struct WeeklyProgressCarousel: View {
    var accentColorOverride: Color?

    @Binding var entries: [WeeklyProgressEntry]
    @Binding var selectedEntry: WeeklyProgressEntry?
    @Binding var showEditor: Bool
    @Binding var previewImageEntry: WeeklyProgressEntry?
    
    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "E, MMM d"
        return f
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    let tint = accentColorOverride ?? .accentColor

                    ForEach(entries) { entry in
                        VStack(alignment: .center, spacing: 8) {
                            // Date centered at top
                            Text(dateFormatter.string(from: entry.date))
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 8)

                            Spacer()

                            // Weight always shown
                            Text(String(format: "%.1f kg", entry.weight))
                                .font(.title2)
                                .fontWeight(.semibold)

                            // Optional additional info — reserve a fixed height so absence
                            // of both values doesn't shift the weight vertically.
                            HStack(spacing: 10) {
                                if let water = entry.waterPercent {
                                    HStack(spacing: 6) {
                                        Image(systemName: "drop.fill")
                                            .foregroundStyle(tint)
                                        Text(String(format: "%.0f%%", water))
                                    }
                                }

                                if let bf = entry.bodyFatPercent {
                                    HStack(spacing: 6) {
                                        Image(systemName: "scalemass")
                                            .foregroundStyle(tint)
                                        Text(String(format: "%.1f%%", bf))
                                    }
                                }

                                // If neither metric is present, add an invisible placeholder
                                // that preserves the row height to avoid layout shifts.
                                if entry.waterPercent == nil && entry.bodyFatPercent == nil {
                                    Color.clear
                                        .frame(height: 18)
                                }
                            }
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(minHeight: 18)

                            // Photo (placed under the additional info)
                            if entry.imagesCount > 0 {
                                Image("placeholder")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 180, height: 240)
                                    .aspectRatio(3/4, contentMode: .fill)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(tint.opacity(0.12), lineWidth: 1)
                                    )
                                    .onTapGesture {
                                        previewImageEntry = entry
                                    }
                                    .accessibilityLabel("Progress photo")
                                    .padding(.top, 6)
                            } else {
                                // Rounded Rectangle placeholder with .glassEffect
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.primary.opacity(0.05))
                                    .frame(width: 180, height: 240)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(tint.opacity(0.12), lineWidth: 1)
                                    )
                                    .overlay(
                                        Text("No Photo")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    )
                                    .padding(.top, 6)
                            }

                            HStack {
                                Spacer()
                                Button {
                                    selectedEntry = entry
                                    showEditor = true
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                        .font(.callout)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .glassEffect(in: .rect(cornerRadius: 18.0))
                                }
                                .buttonStyle(.plain)
                                Spacer()
                            }
                            .padding(.top, 8)
                            .padding(.bottom, 8)
                        }
                        .padding(16)
                        .frame(width: 220)
                        .glassEffect(in: .rect(cornerRadius: 16.0))
                        .id(entry.id)
                    }

                    // Upcoming tile: shows next expected entry date (last entry date + 7 days)
                    VStack(alignment: .center, spacing: 8) {
                        Text("Upcoming")
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 8)

                        Spacer()

                        // Compute next expected date (7 days after last entry)
                        let baseDate = entries.last?.date ?? Date()
                        let nextDate = Calendar.current.date(byAdding: .day, value: 7, to: baseDate) ?? baseDate

                        VStack(spacing: 12) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 28))
                                .foregroundStyle(tint)

                            Text("Next expected:")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text(dateFormatter.string(from: nextDate))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }

                        Spacer()
                    }
                    .padding(16)
                    .frame(width: 220)
                    .glassEffect(in: .rect(cornerRadius: 16.0))
                    .id("weekly-upcoming")
                }
                .padding(.vertical, 6)
                .padding(.leading, 2)
            }
            .onAppear {
                if let last = entries.last {
                    proxy.scrollTo(last.id, anchor: .trailing)
                }
            }
            .onChange(of: entries) { _, newEntries in
                if let last = newEntries.last {
                    withAnimation(.easeOut) {
                        proxy.scrollTo(last.id, anchor: .trailing)
                    }
                }
            }
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
