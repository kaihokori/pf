import SwiftUI
import Charts

private func currentCurrencySymbol() -> String {
    if let symbol = Locale.current.currencySymbol, !symbol.isEmpty {
        return symbol
    }
    if let id = Locale.current.currency?.identifier, !id.isEmpty {
        return id
    }
    return "$"
}

struct ExpenseCategory: Identifiable, Equatable {
    let id: Int
    var name: String
    var colorHex: String

    static func defaultCategories() -> [ExpenseCategory] {
        [
            ExpenseCategory(id: 0, name: "Food", colorHex: "#E39A3B"),
            ExpenseCategory(id: 1, name: "Groceries", colorHex: "#4CAF6A"),
            ExpenseCategory(id: 2, name: "Transport", colorHex: "#4FB6C6"),
            ExpenseCategory(id: 3, name: "Bills", colorHex: "#7A5FD1")
        ]
    }
}

struct ExpenseEntry: Identifiable {
    let id = UUID()
    var date: Date
    var name: String
    var amount: Double
    var categoryId: Int
}

private struct DailyCategoryTotal: Identifiable {
    let id = UUID()
    let date: Date
    let category: String
    let total: Double
}

private struct DailyTotal: Identifiable {
    let id = UUID()
    let date: Date
    let total: Double
}

struct ExpenseTrackerSection: View {
    var accentColorOverride: Color?
    var categories: [ExpenseCategory]

    @State private var entries: [ExpenseEntry] = {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return [
            ExpenseEntry(date: today, name: "Coffee", amount: 4.5, categoryId: 0),
            ExpenseEntry(date: today, name: "Lunch", amount: 12.0, categoryId: 0),
            ExpenseEntry(date: cal.date(byAdding: .day, value: -1, to: today)!, name: "Groceries", amount: 45.2, categoryId: 1),
            ExpenseEntry(date: cal.date(byAdding: .day, value: -1, to: today)!, name: "Taxi", amount: 8.0, categoryId: 2),
            ExpenseEntry(date: cal.date(byAdding: .day, value: -2, to: today)!, name: "Subscription", amount: 9.99, categoryId: 3),
            ExpenseEntry(date: cal.date(byAdding: .day, value: -4, to: today)!, name: "Dinner", amount: 26.35, categoryId: 0),
            ExpenseEntry(date: cal.date(byAdding: .day, value: -5, to: today)!, name: "Snacks", amount: 6.2, categoryId: 1)
        ]
    }()

    @State private var editingEntry: ExpenseEntry? = nil
    @State private var showingAddSheet: Bool = false
    @State private var addSheetDate: Date? = nil

    @State private var currencyOverride: String = "$"

    private let historyDays: Int = 7

    private var tint: Color {
        accentColorOverride ?? .accentColor
    }

    private var displayedCurrencySymbol: String {
        let trimmed = currencyOverride.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? currentCurrencySymbol() : trimmed
    }

    private var dailyCategoryTotals: [DailyCategoryTotal] {
        let cal = Calendar.current

        // compute current week starting Monday
        let today = Date()
        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        comps.weekday = 2 // Monday
        guard let startOfWeek = cal.date(from: comps) else { return [] }
        let displayDates: [Date] = (0..<historyDays).compactMap { offset in
            cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: startOfWeek))
        }

        var results: [DailyCategoryTotal] = []

        for date in displayDates {
            let dayEntries = entries.filter { cal.isDate($0.date, inSameDayAs: date) }
            for category in orderedCategories {
                let total = dayEntries.filter { $0.categoryId == category.id }.reduce(0) { $0 + $1.amount }
                let categoryName = categoryName(for: category.id)
                // include zero totals so every day/category has a bar (keeps adjacency consistent)
                results.append(DailyCategoryTotal(date: date, category: categoryName, total: total))
            }
        }

        return results.sorted { $0.date < $1.date }
    }

    private var displayDates: [Date] {
        let cal = Calendar.current
        let today = Date()
        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        comps.weekday = 2 // Monday
        guard let startOfWeek = cal.date(from: comps) else { return [] }
        return (0..<historyDays).compactMap { offset in
            cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: startOfWeek))
        }
    }

    // Adaptive label step: show roughly `targetLabels` labels across the history window
    private var labelStep: Int {
        let targetLabels = 6
        return max(1, historyDays / targetLabels)
    }

    private var dailyTotals: [DailyTotal] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: entries) { (entry) -> Date in
            cal.startOfDay(for: entry.date)
        }
        // return totals for the displayDates (last `historyDays` days)
        let dates = displayDates
        return dates.map { day in
            let items = grouped[day] ?? []
            return DailyTotal(date: day, total: items.reduce(0) { $0 + $1.amount })
        }
    }

    private var orderedCategories: [ExpenseCategory] {
        categories.sorted { $0.id < $1.id }
    }

    private var categoryDomain: [String] {
        orderedCategories.map { categoryName(for: $0.id) }
    }

    private var categoryColors: [Color] {
        orderedCategories.map { Color(hex: $0.colorHex) ?? tint }
    }

    private func categoryName(for id: Int) -> String {
        let defaultName = "Category \(id + 1)"
        guard let category = categories.first(where: { $0.id == id }) else { return defaultName }
        let trimmed = category.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultName : trimmed
    }

    private func formattedCurrency(_ value: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.locale = Locale.current
        if let s = fmt.string(from: NSNumber(value: value)) {
            return s
        }
        return String(format: "%@%.2f", currentCurrencySymbol(), value)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Chart {
                ForEach(dailyCategoryTotals) { item in
                    BarMark(
                        x: .value("Day", DateFormatter.shortDate.string(from: item.date)),
                        y: .value("Amount (\(displayedCurrencySymbol))", item.total)
                    )
                    .foregroundStyle(by: .value("Category", item.category))
                    .position(by: .value("Category", item.category), axis: .horizontal)
                    .cornerRadius(4)
                }
            }
            .chartForegroundStyleScale(domain: categoryDomain, range: categoryColors)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                let labels = displayDates.enumerated().compactMap { idx, d in
                    (idx % labelStep == 0) ? DateFormatter.shortDate.string(from: d) : nil
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
            .frame(height: 140)

            // Detailed entries for this week (Monday - Sunday)
            VStack(spacing: 0) {
                ForEach(displayDates, id: \.self) { day in
                    let dayEntries = entries.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
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
                            Button {
                                addSheetDate = day
                                showingAddSheet = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(.callout)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .glassEffect(in: .rect(cornerRadius: 18.0))
                            }
                            .buttonStyle(.plain)
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

                                    Button {
                                        editingEntry = entry
                                    } label: {
                                        Image(systemName: "pencil")
                                            .font(.callout)
                                            .foregroundStyle(.primary)
                                    }
                                    .buttonStyle(.plain)
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
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .sheet(item: $editingEntry) { entry in
            ExpenseEntryEditorView(categories: categories, day: entry.date, entry: entry, currencySymbol: displayedCurrencySymbol) { updated in
                if let idx = entries.firstIndex(where: { $0.id == updated.id }) {
                    entries[idx] = updated
                }
                editingEntry = nil
            } onCancel: {
                editingEntry = nil
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            if let targetDay = addSheetDate {
                ExpenseEntryEditorView(categories: categories, day: targetDay, entry: nil, currencySymbol: displayedCurrencySymbol) { newEntry in
                    entries.append(newEntry)
                    showingAddSheet = false
                } onCancel: {
                    showingAddSheet = false
                }
            }
        }
    }
}

private struct ExpenseEntryEditorView: View {
    @Environment(\.dismiss) private var dismiss

    var categories: [ExpenseCategory]
    var day: Date
    var entry: ExpenseEntry?
    var onSave: (ExpenseEntry) -> Void
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
        categories.sorted { $0.id < $1.id }
    }

    init(categories: [ExpenseCategory], day: Date, entry: ExpenseEntry?, currencySymbol: String, onSave: @escaping (ExpenseEntry) -> Void, onCancel: @escaping () -> Void) {
        self.categories = categories
        self.day = Calendar.current.startOfDay(for: day)
        self.entry = entry
        self.onSave = onSave
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
                                Button {
                                    selectedCategoryId = category.id
                                } label: {
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill((Color(hex: category.colorHex) ?? .accentColor).opacity(0.6))
                                            .frame(width: 14, height: 14)

                                        Text(category.name)
                                            .font(.footnote.weight(.semibold))
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        (isSelected ? (Color(hex: category.colorHex) ?? .accentColor).opacity(0.15) : Color.secondary.opacity(0.08)),
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke((Color(hex: category.colorHex) ?? .accentColor).opacity(isSelected ? 0.6 : 0.15), lineWidth: isSelected ? 1.2 : 1)
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
                                TextField("Amount (\(currencySymbol))", text: $amount)
                                    .keyboardType(.decimalPad)
                                    .padding()
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

                                DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                                    .padding(.horizontal)
                                    .padding(.vertical, 10)
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
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                    .opacity(isValid ? 1 : 0.4)
                }
            }
        }
    }

    private func save() {
        guard let amt = Double(amount) else { return }
        let finalDate = combinedDate(day: day, time: time)
        var updated = entry ?? ExpenseEntry(date: finalDate, name: name, amount: amt, categoryId: selectedCategoryId)
        updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.amount = amt
        updated.categoryId = selectedCategoryId
        updated.date = finalDate
        onSave(updated)
        dismiss()
    }

    private func combinedDate(day: Date, time: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute, .second], from: time)
        return cal.date(bySettingHour: comps.hour ?? 0, minute: comps.minute ?? 0, second: comps.second ?? 0, of: day) ?? day
    }
}

private extension DateFormatter {
    static var shortDate: DateFormatter = {
        let df = DateFormatter()
            df.dateFormat = "EEE" // weekday short (Mon, Tue)
        return df
    }()

    static var longDate: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }()

    static var weekdayFull: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEEE" // full weekday name
        return df
    }()

    static var time: DateFormatter = {
        let df = DateFormatter()
        df.timeStyle = .short
        df.dateStyle = .none
        return df
    }()
}

#if DEBUG
struct ExpenseTrackerSection_Previews: PreviewProvider {
    static var previews: some View {
        ExpenseTrackerSection(accentColorOverride: .accentColor, categories: ExpenseCategory.defaultCategories())
            .previewLayout(.sizeThatFits)
    }
}
#endif
