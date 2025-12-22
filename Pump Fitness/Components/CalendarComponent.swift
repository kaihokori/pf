import SwiftUI

struct CalendarComponent: View {
    @Binding var selectedDate: Date
    @Binding var showCalendar: Bool

    private let calendar = Calendar.current
    // Weekday labels rotated to start on Monday
    private var daysOfWeek: [String] {
        let symbols = DateFormatter().veryShortStandaloneWeekdaySymbols ?? DateFormatter().veryShortWeekdaySymbols ?? ["M","T","W","T","F","S","S"]
        // DateFormatter.weekdaySymbols start with Sunday; rotate so Monday is first
        let sundayFirst = symbols
        let mondayIndex = 1 // Monday position when Sunday is index 0
        return Array(sundayFirst[mondayIndex..<sundayFirst.count] + sundayFirst[0..<mondayIndex])
    }

    @State private var currentMonth: Date = Date()
    @Namespace private var calendarAnim
    @State private var isVisible: Bool = false
    @State private var showMonthPicker: Bool = false
    @State private var showYearPicker: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Month/Year Picker logic
            HStack {
                Button(action: {
                    withAnimation(.easeInOut) {
                        currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                    }
                }) {
                    Image(systemName: "chevron.left")
                }
                .padding(.leading, 15)
                Spacer()
                Text(monthYearString(currentMonth))
                    .font(.headline)
                    .matchedGeometryEffect(id: "monthLabel", in: calendarAnim)
                Spacer()
                Button(action: {
                    withAnimation(.easeInOut) {
                        currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                    }
                }) {
                    Image(systemName: "chevron.right")
                }
                .padding(.trailing, 15)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 8)
            .padding(.horizontal)
            .padding(.top, 16)

            if showYearPicker {
                // Year Picker
                let currentYear = calendar.component(.year, from: currentMonth)
                let years = (currentYear-50...currentYear+10).map { $0 }
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                        ForEach(years, id: \ .self) { year in
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
                                    .background(calendar.component(.year, from: currentMonth) == year ? Color.accentColor.opacity(0.2) : Color.clear)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: 340)
            } else if showMonthPicker {
                // Month Picker
                let months = DateFormatter().monthSymbols ?? []
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                        ForEach(months.indices, id: \ .self) { idx in
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
                                    .background(calendar.component(.month, from: currentMonth) == idx + 1 ? Color.accentColor.opacity(0.2) : Color.clear)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: 340)
            } else {
                // Calendar Days
                HStack {
                    ForEach(daysOfWeek, id: \ .self) { day in
                        Text(day)
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 12)
                let days = daysInMonth(currentMonth)
                // Compute offset so the grid starts on Monday
                let firstOfMonthDate = firstOfMonth(currentMonth)
                let rawFirstWeekday = calendar.component(.weekday, from: firstOfMonthDate) // 1 = Sunday
                // We want Monday to be index 0
                let firstWeekday = (rawFirstWeekday - 2 + 7) % 7
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(0..<(days + firstWeekday), id: \ .self) { i in
                        if i < firstWeekday {
                            Color.clear.frame(height: 32)
                        } else {
                            let day = i - firstWeekday + 1
                            let date = dateForDay(day, in: currentMonth)
                            Button(action: {
                                withAnimation(.easeInOut) {
                                    selectedDate = date
                                    isVisible = false
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    showCalendar = false
                                }
                            }) {
                                Text("\(day)")
                                    .frame(maxWidth: .infinity, minHeight: 32)
                                    .background(calendar.isDate(date, inSameDayAs: selectedDate) ? Color.accentColor.opacity(0.2) : Color.clear)
                                    .clipShape(Circle())
                            }
                            .foregroundColor(calendar.isDate(date, inSameDayAs: selectedDate) ? .accentColor : .primary)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .padding(24)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.95)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isVisible)
        .onAppear {
            isVisible = true
        }
        .onChange(of: showCalendar) { newValue, _ in
            if !newValue {
                isVisible = false
            }
        }
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

#Preview {
    CalendarComponent(selectedDate: .constant(Date()), showCalendar: .constant(true))
}
