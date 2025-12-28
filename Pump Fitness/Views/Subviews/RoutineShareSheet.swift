import SwiftUI

struct RoutineHabitSnapshot: Identifiable {
    let id: UUID
    let name: String
    let isCompleted: Bool
    let color: Color
}

struct RoutineExpenseBar: Identifiable {
    let id: Date
    let label: String
    let total: Double
}

struct RoutineShareSheet: View {
    var accentColor: Color
    var taskCompletionPercent: Int
    var completedGoals: [GoalItem]
    var habitStatuses: [RoutineHabitSnapshot]
    var expenseBars: [RoutineExpenseBar]
    var expenseCategories: [ExpenseCategory] = []

    @Environment(\.dismiss) private var dismiss

    @State private var showTasks = true
    @State private var showGoals = true
    @State private var showHabits = true
    @State private var showExpenses = true

    @State private var sharePayload: RoutineSharePayload?

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 40, height: 5)
                        .padding(.top, 12)

                    Text("Share Routine Snapshot")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .padding(.bottom, 16)

                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 0) {
                            ToggleRow(title: "Daily Tasks", isOn: $showTasks, icon: "checklist", color: .orange)
                            Divider().padding(.leading, 44)
                            ToggleRow(title: "Goals", isOn: $showGoals, icon: "target", color: .pink)
                            Divider().padding(.leading, 44)
                            ToggleRow(title: "Habits", isOn: $showHabits, icon: "sparkles", color: .blue)
                            Divider().padding(.leading, 44)
                            ToggleRow(title: "Expenses", isOn: $showExpenses, icon: "chart.bar.fill", color: .green)
                        }
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 20)

                        RoutineShareCard(
                            accentColor: accentColor,
                            taskCompletionPercent: taskCompletionPercent,
                            goals: completedGoals,
                            habits: habitStatuses,
                            expenseBars: expenseBars,
                            expenseCategories: expenseCategories,
                            showTasks: showTasks,
                            showGoals: showGoals,
                            showHabits: showHabits,
                            showExpenses: showExpenses,
                            isExporting: false
                        )
                        .dynamicTypeSize(.medium)
                        .environment(\.sizeCategory, .medium)
                        .padding(.horizontal, 20)
                        .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 8)
                        .padding(.bottom, 60)
                    }
                }

                VStack {
                    Button {
                        shareCurrentCard()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title2)
                            Text("Share")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            LinearGradient(colors: [accentColor, accentColor.opacity(0.85)], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal, 20)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 20)
                .background(Color(UIColor.systemBackground).ignoresSafeArea())
            }
        }
        .background(Color(UIColor.systemBackground))
        .presentationDetents([.large])
        .sheet(item: $sharePayload) { payload in
            ShareSheet(activityItems: payload.items)
        }
    }

    @MainActor
    private func renderCurrentCard() -> UIImage? {
        // Force export width to 540, allow flexible height up to 960
        let width: CGFloat = 540

        let renderView = RoutineShareCard(
            accentColor: accentColor,
            taskCompletionPercent: taskCompletionPercent,
            goals: completedGoals,
            habits: habitStatuses,
            expenseBars: expenseBars,
            showTasks: showTasks,
            showGoals: showGoals,
            showHabits: showHabits,
            showExpenses: showExpenses,
            isExporting: true
        )
        .frame(width: width)
        .frame(maxHeight: 960)
        .dynamicTypeSize(.medium)
        .environment(\.sizeCategory, .medium)

        let renderer = ImageRenderer(content: renderView)
        renderer.scale = 3.0
        return renderer.uiImage
    }

    private func shareCurrentCard() {
        guard let image = renderCurrentCard() else { return }
        guard let url = saveImageToTempPNG(image, prefix: "routine") else { return }
        sharePayload = RoutineSharePayload(items: [url])
    }

    private func saveImageToTempPNG(_ image: UIImage, prefix: String = "share") -> URL? {
        guard let data = image.pngData() else { return nil }
        let tmp = FileManager.default.temporaryDirectory
        let filename = "\(prefix)-\(UUID().uuidString).png"
        let url = tmp.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

private struct RoutineShareCard: View {
    var accentColor: Color
    var taskCompletionPercent: Int
    var goals: [GoalItem]
    var habits: [RoutineHabitSnapshot]
    var expenseBars: [RoutineExpenseBar]
    var expenseCategories: [ExpenseCategory] = []

    var showTasks: Bool
    var showGoals: Bool
    var showHabits: Bool
    var showExpenses: Bool

    var isExporting: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ROUTINE SUMMARY")
                        .font(.caption2)
                        .fontWeight(.black)
                        .foregroundStyle(accentColor)
                        .tracking(0.5)
                    Text(Date().formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                Spacer()
                PumpBranding()
                    .scaleEffect(0.85)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(accentColor.opacity(0.05))

            VStack(spacing: 18) {
                if showTasks {
                    TasksSection(percent: taskCompletionPercent, color: accentColor)
                }

                if showGoals && !goals.isEmpty {
                    GoalsShareSection(goals: goals.prefix(5).map { $0 }, color: .pink)
                }

                if showHabits && !habits.isEmpty {
                    HabitsShareSection(habits: habits, color: .blue)
                }

                if showExpenses && !expenseBars.isEmpty {
                    ExpensesShareSection(bars: expenseBars, categories: expenseCategories, color: .green)
                }
            }
            .padding(20)
        }
        .background {
            if isExporting {
                Color.clear
            } else {
                GeometryReader { geo in
                    // Gradient originates from the bottom and fades to transparent at the top
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.74, green: 0.43, blue: 0.97).opacity(0.3),
                            Color(red: 0.83, green: 0.99, blue: 0.94).opacity(0.3),
                            Color.clear
                        ]),
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .frame(height: max(0, geo.size.height * 0.7))
                    .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(accentColor.opacity(0.1), lineWidth: 1)
        )
    }
}

private struct TasksSection: View {
    var percent: Int
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "DAILY TASKS", icon: "checklist", color: color)
            HStack {
                Text("Completion")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(percent)%")
                    .font(.subheadline.weight(.bold))
            }
            ProgressView(value: Double(percent), total: 100)
                .tint(color)
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct GoalsShareSection: View {
    var goals: [GoalItem]
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "GOALS", icon: "target", color: color)
            let columns = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(goals.prefix(5)) { goal in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(color)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(goal.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Text(goal.dueDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(8)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct HabitsShareSection: View {
    var habits: [RoutineHabitSnapshot]
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "HABITS", icon: "sparkles", color: color)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(habits.prefix(4)) { habit in
                    HStack(spacing: 8) {
                        Image(systemName: habit.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(habit.isCompleted ? habit.color : .secondary)
                        Text(habit.name)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer()
                    }
                    .padding(8)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct ExpensesShareSection: View {
    var bars: [RoutineExpenseBar]
    var categories: [ExpenseCategory]
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "EXPENSES (USD)", icon: "chart.bar.fill", color: color)
            GeometryReader { geo in
                let maxValue = max(bars.map { $0.total }.max() ?? 0, 1)
                let colCount = max(bars.count, 1)
                let rawWidth = (geo.size.width / CGFloat(colCount)) - 12
                let barWidth = max(4, rawWidth)
                VStack(spacing: 8) {
                    HStack(alignment: .bottom, spacing: 10) {
                        ForEach(bars) { bar in
                            VStack(spacing: 6) {
                                Text(String(format: "%.0f", bar.total))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(color.opacity(0.85))
                                    .frame(width: barWidth, height: CGFloat(bar.total / maxValue) * 110)
                                Text(bar.label)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .frame(height: 160)
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct RoutineSharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}
