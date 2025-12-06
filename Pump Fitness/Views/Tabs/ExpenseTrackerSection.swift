import SwiftUI
import Charts

struct ExpenseEntry: Identifiable {
    let id = UUID()
    var date: Date
    var name: String
    var amount: Double
    var category: String
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

    @State private var entries: [ExpenseEntry] = {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return [
            ExpenseEntry(date: today, name: "Coffee", amount: 4.5, category: "Food"),
            ExpenseEntry(date: today, name: "Lunch", amount: 12.0, category: "Food"),
            ExpenseEntry(date: cal.date(byAdding: .day, value: -1, to: today)!, name: "Groceries", amount: 45.2, category: "Groceries"),
            ExpenseEntry(date: cal.date(byAdding: .day, value: -1, to: today)!, name: "Taxi", amount: 8.0, category: "Transport"),
            ExpenseEntry(date: cal.date(byAdding: .day, value: -2, to: today)!, name: "Subscription", amount: 9.99, category: "Bills"),
            ExpenseEntry(date: cal.date(byAdding: .day, value: -4, to: today)!, name: "Dinner", amount: 26.35, category: "Food"),
            ExpenseEntry(date: cal.date(byAdding: .day, value: -5, to: today)!, name: "Snacks", amount: 6.2, category: "Groceries")
        ]
    }()

    @State private var editingEntry: ExpenseEntry? = nil

    private let historyDays: Int = 7

    private var tint: Color {
        accentColorOverride ?? .accentColor
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

        // collect all categories present in entries
        let categories: [String] = Array(Set(entries.map { $0.category })).sorted()

        var results: [DailyCategoryTotal] = []

        for date in displayDates {
            let dayEntries = entries.filter { cal.isDate($0.date, inSameDayAs: date) }
            for category in categories {
                let total = dayEntries.filter { $0.category == category }.reduce(0) { $0 + $1.amount }
                // include zero totals so every day/category has a bar (keeps adjacency consistent)
                results.append(DailyCategoryTotal(date: date, category: category, total: total))
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

    private var categoryColorMap: [String: Color] {
        // map categories to colours; extend as needed
        var map: [String: Color] = [:]
        map["Food"] = .orange
        map["Groceries"] = .green
        map["Transport"] = .blue
        map["Bills"] = .purple
        return map
    }

    private func formattedCurrency(_ value: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        return fmt.string(from: NSNumber(value: value)) ?? String(format: "$%.2f", value)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Chart showing daily totals
            Chart {
                ForEach(dailyCategoryTotals) { item in
                    BarMark(
                        x: .value("Day", DateFormatter.shortDate.string(from: item.date)),
                        y: .value("Amount", item.total)
                    )
                    .foregroundStyle(by: .value("Category", item.category))
                    .position(by: .value("Category", item.category), axis: .horizontal)
                    .cornerRadius(4)
                }
            }
            .chartForegroundStyleScale(["Food": Color.orange, "Groceries": Color.green, "Transport": Color.blue, "Bills": Color.purple])
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
                ForEach(displayDates.reversed(), id: \.self) { day in
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
            NavigationStack {
                VStack {
                    Text("Edit expense")
                        .font(.title3)
                        .padding()

                    Spacer()
                }
                .navigationTitle("Edit")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            editingEntry = nil
                        }
                    }
                }
            }
        }
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
        ExpenseTrackerSection(accentColorOverride: .accentColor)
            .previewLayout(.sizeThatFits)
    }
}
#endif
