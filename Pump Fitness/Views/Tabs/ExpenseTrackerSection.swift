import SwiftUI
import Charts
import TipKit

private func currentCurrencySymbol() -> String {
    if let symbol = Locale.current.currencySymbol, !symbol.isEmpty {
        return symbol
    }
    if let id = Locale.current.currency?.identifier, !id.isEmpty {
        return id
    }
    return "$"
}

private struct DailyCategoryTotal: Identifiable {
    let id = UUID()
    let date: Date
    let category: String
    let total: Double
}

struct ExpenseTrackerSection: View {
    var accentColorOverride: Color?
    var currencySymbol: String
    @Binding var categories: [ExpenseCategory]
    @Binding var weekEntries: [ExpenseEntry]
    var anchorDate: Date
    var onSaveEntry: (ExpenseEntry) -> Void
    var onDeleteEntry: (UUID) -> Void

    @State private var editingEntry: ExpenseEntry? = nil
    @State private var showingAddSheet: Bool = false
    @State private var addSheetDate: Date? = nil

    private let historyDays: Int = 7

    private var tint: Color {
        accentColorOverride ?? .accentColor
    }

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    private var displayedCurrencySymbol: String {
        let trimmed = currencySymbol.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? currentCurrencySymbol() : trimmed
    }

    private var weekDisplayDates: [Date] {
        let cal = Calendar.current
        let anchor = cal.startOfDay(for: anchorDate)
        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: anchor)
        comps.weekday = 2 // Monday
        guard let startOfWeek = cal.date(from: comps) else { return [] }
        return (0..<historyDays).compactMap { offset in
            cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: startOfWeek))
        }
    }

    private var dailyCategoryTotals: [DailyCategoryTotal] {
        let cal = Calendar.current
        var results: [DailyCategoryTotal] = []

        for date in weekDisplayDates {
            let dayEntries = weekEntries.filter { cal.isDate($0.date, inSameDayAs: date) }
            for category in orderedCategories {
                let total = dayEntries.filter { $0.categoryId == category.id }.reduce(0.0) { $0 + $1.amount }
                if total > 0 {
                    results.append(
                        DailyCategoryTotal(
                            date: date,
                            category: categoryName(for: category.id),
                            total: total
                        )
                    )
                }
            }
        }

        return results.sorted { $0.date < $1.date }
    }

    private var labelStep: Int {
        let targetLabels = 6
        return max(1, historyDays / targetLabels)
    }

    private var orderedCategories: [ExpenseCategory] {
        // Merge provided categories with defaults so we always have the full set
        let defaults = ExpenseCategory.defaultCategories()
        var normalized: [ExpenseCategory] = []
        for idx in 0..<defaults.count {
            if let existing = categories.first(where: { $0.id == idx }) {
                let name = existing.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaults[idx].name : existing.name
                let color = existing.colorHex.isEmpty ? defaults[idx].colorHex : existing.colorHex
                normalized.append(ExpenseCategory(id: idx, name: name, colorHex: color))
            } else {
                normalized.append(defaults[idx])
            }
        }
        return normalized
    }

    private var categoryDomain: [String] {
        orderedCategories.map { categoryName(for: $0.id) }
    }

    private var categoryColors: [Color] {
        orderedCategories.map { cat in
            if themeManager.selectedTheme != .multiColour {
                return themeManager.selectedTheme.accent(for: colorScheme)
            }
            return Color(hex: cat.colorHex) ?? tint
        }
    }

    private func effectiveCategoryColor(for category: ExpenseCategory) -> Color {
        if themeManager.selectedTheme != .multiColour {
            return themeManager.selectedTheme.accent(for: colorScheme)
        }
        return Color(hex: category.colorHex) ?? tint
    }

    private func categoryName(for id: Int) -> String {
        let defaultName = "Category \(id + 1)"
        guard let category = orderedCategories.first(where: { $0.id == id }) else { return defaultName }
        let trimmed = category.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultName : trimmed
    }

    private func formattedCurrency(_ value: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.locale = Locale.current
        fmt.currencySymbol = displayedCurrencySymbol
        if let s = fmt.string(from: NSNumber(value: value)) {
            return s
        }
        return String(format: "%@%.2f", displayedCurrencySymbol, value)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Chart {
                if orderedCategories.isEmpty {
                    // No categories configured: render empty bars for each day so x-axis shows 7 days
                    ForEach(weekDisplayDates, id: \.self) { day in
                        BarMark(
                            x: .value("Day", DateFormatter.shortDate.string(from: day)),
                            y: .value("Amount (\(displayedCurrencySymbol))", 0.0)
                        )
                        .foregroundStyle(Color.primary.opacity(0.08))
                        .cornerRadius(4)
                    }
                } else {
                    ForEach(orderedCategories, id: \.id) { cat in
                        ForEach(weekDisplayDates, id: \.self) { day in
                            let total = weekEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: day) && $0.categoryId == cat.id }
                                .reduce(0.0) { $0 + $1.amount }
                            BarMark(
                                x: .value("Day", DateFormatter.shortDate.string(from: day)),
                                y: .value("Amount (\(displayedCurrencySymbol))", total)
                            )
                            .foregroundStyle(by: .value("Category", categoryName(for: cat.id)))
                            .position(by: .value("Category", categoryName(for: cat.id)), axis: .horizontal)
                            .cornerRadius(4)
                        }
                    }
                }
            }
            .chartForegroundStyleScale(domain: categoryDomain, range: categoryColors)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                // Always show all 7 day ticks (short date labels)
                let labels = weekDisplayDates.map { DateFormatter.shortDate.string(from: $0) }
                AxisMarks(values: labels) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label)
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 200)

            VStack(spacing: 0) {
                ForEach(weekDisplayDates, id: \.self) { day in
                    let dayEntries = entries(for: day)
                    Section(header:
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(DateFormatter.weekdayFull.string(from: day))
                                    .font(.subheadline.weight(.semibold))
                                Text(DateFormatter.longDate.string(from: day))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(formattedCurrency(dayEntries.reduce(0) { $0 + $1.amount }))
                                .font(.subheadline.weight(.semibold))
                            
                            if day == weekDisplayDates.first {
                                Button {
                                    addSheetDate = day
                                    showingAddSheet = true
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.callout)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .adaptiveGlassEffect(in: .rect(cornerRadius: 18.0))
                                }
                                .buttonStyle(.plain)
                            } else {
                                Button {
                                    addSheetDate = day
                                    showingAddSheet = true
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.callout)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .adaptiveGlassEffect(in: .rect(cornerRadius: 18.0))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 8)
                    ) {
                        if dayEntries.isEmpty {
                            Text("No expenses")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(dayEntries) { entry in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.name)
                                            .font(.subheadline)
                                        Text(formattedCurrency(entry.amount))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text(categoryName(for: entry.categoryId))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary.opacity(0.8))
                                    }

                                    Spacer()

                                    Text(DateFormatter.time.string(from: entry.date))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)

                                    Menu {
                                        Button("Edit") { editingEntry = entry }
                                        Button("Delete", role: .destructive) {
                                            onDeleteEntry(entry.id)
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis.circle")
                                            .font(.callout)
                                            .foregroundStyle(.primary)
                                    }
                                    .menuStyle(.borderlessButton)
                                    .padding(.leading, 8)
                                }
                                .padding(.vertical, 8)
                                if entry.id != dayEntries.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .adaptiveGlassEffect(in: .rect(cornerRadius: 16.0))
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .sheet(item: $editingEntry) { entry in
            ExpenseEntryEditorView(categories: categories, day: entry.date, entry: entry, currencySymbol: displayedCurrencySymbol) { updated in
                onSaveEntry(updated)
                editingEntry = nil
            } onDelete: { id in
                onDeleteEntry(id)
                editingEntry = nil
            } onCancel: {
                editingEntry = nil
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            if let targetDay = addSheetDate {
                ExpenseEntryEditorView(categories: categories, day: targetDay, entry: nil, currencySymbol: displayedCurrencySymbol) { newEntry in
                    onSaveEntry(newEntry)
                    showingAddSheet = false
                } onDelete: { _ in
                    showingAddSheet = false
                } onCancel: {
                    showingAddSheet = false
                }
            }
        }
    }

    private func entries(for day: Date) -> [ExpenseEntry] {
        let cal = Calendar.current
        return weekEntries.filter { cal.isDate($0.date, inSameDayAs: day) }.sorted { $0.date < $1.date }
    }
}

private struct ExpenseEntryEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    var categories: [ExpenseCategory]
    var day: Date
    var entry: ExpenseEntry?
    var onSave: (ExpenseEntry) -> Void
    var onDelete: (UUID) -> Void
    var onCancel: () -> Void
    var currencySymbol: String

    @State private var name: String
    @State private var amount: String
    @State private var selectedCategoryId: Int
    @State private var time: Date

    private var title: String { entry == nil ? "Add Expense" : "Edit Expense" }
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && Double(amount) != nil
    }

    private var orderedCategories: [ExpenseCategory] {
        // Merge provided categories with defaults so we always have the full set
        let defaults = ExpenseCategory.defaultCategories()
        var normalized: [ExpenseCategory] = []
        for idx in 0..<defaults.count {
            if let existing = categories.first(where: { $0.id == idx }) {
                let name = existing.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaults[idx].name : existing.name
                let color = existing.colorHex.isEmpty ? defaults[idx].colorHex : existing.colorHex
                normalized.append(ExpenseCategory(id: idx, name: name, colorHex: color))
            } else {
                normalized.append(defaults[idx])
            }
        }
        return normalized
    }

    init(categories: [ExpenseCategory], day: Date, entry: ExpenseEntry?, currencySymbol: String, onSave: @escaping (ExpenseEntry) -> Void, onDelete: @escaping (UUID) -> Void, onCancel: @escaping () -> Void) {
        self.categories = categories
        self.day = Calendar.current.startOfDay(for: day)
        self.entry = entry
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel
        self.currencySymbol = currencySymbol

        let fallbackCategory = categories.first?.id ?? 0
        _name = State(initialValue: entry?.name ?? "")
        _amount = State(initialValue: entry.map { String(format: "%.2f", $0.amount) } ?? "")
        _selectedCategoryId = State(initialValue: entry?.categoryId ?? fallbackCategory)
        _time = State(initialValue: entry?.date ?? day)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Category")
                            .font(.subheadline.weight(.semibold))

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 10) {
                                ForEach(orderedCategories, id: \.id) { category in
                                    let isSelected = category.id == selectedCategoryId
                                    let color: Color = {
                                        if themeManager.selectedTheme != .multiColour {
                                            return themeManager.selectedTheme.accent(for: colorScheme)
                                        }
                                        return Color(hex: category.colorHex) ?? .accentColor
                                    }()

                                    Button {
                                        selectedCategoryId = category.id
                                    } label: {
                                        HStack(spacing: 8) {
                                            Circle()
                                                .fill(color.opacity(0.6))
                                                .frame(width: 14, height: 14)

                                            Text(category.name)
                                                .font(.footnote.weight(.semibold))
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(
                                            (isSelected ? color.opacity(0.15) : Color.secondary.opacity(0.08)),
                                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(color.opacity(isSelected ? 0.6 : 0.15), lineWidth: isSelected ? 1.2 : 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Details")
                            .font(.subheadline.weight(.semibold))

                        VStack(spacing: 12) {
                            TextField("Name", text: $name)
                                .textInputAutocapitalization(.words)
                                .padding()
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

                            HStack(spacing: 12) {
                                TextField("Amount", text: $amount)
                                    .keyboardType(.decimalPad)
                                    .padding()
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

                                DatePicker("Time", selection: $time, displayedComponents: [.hourAndMinute])
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .padding(.horizontal)
                                    .padding(.vertical, 12)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel(); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { savePressed() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
        }
    }

    private func savePressed() {
        guard isValid else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let amt = Double(amount) else { return }

        var comps = Calendar.current.dateComponents([.hour, .minute], from: time)
        let baseDay = Calendar.current.startOfDay(for: day)
        comps.year = Calendar.current.component(.year, from: baseDay)
        comps.month = Calendar.current.component(.month, from: baseDay)
        comps.day = Calendar.current.component(.day, from: baseDay)
        let finalDate = Calendar.current.date(from: comps) ?? baseDay

        if let existing = entry {
            let updated = ExpenseEntry(id: existing.id, date: finalDate, name: trimmed, amount: amt, categoryId: selectedCategoryId)
            onSave(updated)
        } else {
            let newEntry = ExpenseEntry(date: finalDate, name: trimmed, amount: amt, categoryId: selectedCategoryId)
            onSave(newEntry)
        }
        dismiss()
    }
}

private extension DateFormatter {
    static let shortDate: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEE d"
        return df
    }()

    static let weekdayFull: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEEE"
        return df
    }()

    static let longDate: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MMMM d"
        return df
    }()

    static let time: DateFormatter = {
        let df = DateFormatter()
        df.timeStyle = .short
        return df
    }()
}

#if DEBUG
struct ExpenseTrackerSection_Previews: PreviewProvider {
    static var previews: some View {
        ExpenseTrackerSection(
            accentColorOverride: .accentColor,
            currencySymbol: "$",
            categories: .constant(ExpenseCategory.defaultCategories()),
            weekEntries: .constant([]),
            anchorDate: Date(),
            onSaveEntry: { _ in },
            onDeleteEntry: { _ in }
        )
        .previewLayout(.sizeThatFits)
        .environmentObject(ThemeManager())
    }
}
#endif
