import SwiftUI

struct GoalsSection: View {
    var accentColorOverride: Color?
    @Binding var goals: [GoalItem]

    private var tint: Color {
        accentColorOverride ?? .accentColor
    }

    private let cardWidth: CGFloat = 280

    private var groupedGoals: [GoalBucket: [GoalItem]] {
        Dictionary(grouping: goals, by: { $0.bucket })
    }

    var body: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    goalCard(title: "Today", systemImage: "sun.max.fill", bucket: .today)
                    goalCard(title: "This Week", systemImage: "calendar", bucket: .thisWeek)
                    goalCard(title: "This Month", systemImage: "calendar.badge.clock", bucket: .thisMonth)
                    goalCard(title: "Far Future", systemImage: "sparkles", bucket: .farFuture)
                }
                .padding(.vertical, 6)
                .padding(.leading, 6)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }

    @ViewBuilder
    private func goalCard(title: String, systemImage: String, bucket: GoalBucket) -> some View {
        let items = groupedGoals[bucket] ?? []

        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Label(title, systemImage: systemImage)
                    .font(.callout.weight(.semibold))
                Spacer()
            }
            .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 12) {
                if items.isEmpty {
                    HStack {
                        Text("No goals yet")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .padding(.vertical, 8)
                } else {
                    ForEach(items) { goal in
                        Button(action: {
                            toggleCompletion(goal.id)
                        }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .stroke(tint.opacity(0.12), lineWidth: 2)
                                        .frame(width: 36, height: 36)
                                    if goal.isCompleted {
                                        Circle()
                                            .fill(tint)
                                            .frame(width: 36, height: 36)
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(goal.title)
                                        .font(.subheadline.weight(.semibold))
                                    if !goal.note.isEmpty {
                                        Text(goal.note)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)

                        if goal.id != items.last?.id {
                            Divider()
                                .overlay(Color.white.opacity(0.06))
                        }
                    }
                }
            }
            .padding(.vertical, 6)
        }
        .padding(16)
        .frame(width: cardWidth)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .glassEffect(in: .rect(cornerRadius: 16.0))
    }

    private func toggleCompletion(_ id: UUID) {
        if let idx = goals.firstIndex(where: { $0.id == id }) {
            goals[idx].isCompleted.toggle()
        }
    }
}

enum GoalBucket {
    case today
    case thisWeek
    case thisMonth
    case farFuture
}

struct GoalItem: Identifiable, Equatable {
    let id: UUID
    var title: String
    var note: String
    var isCompleted: Bool
    var dueDate: Date

    var bucket: GoalBucket {
        let cal = Calendar.current
        if cal.isDateInToday(dueDate) { return .today }
        if cal.isDate(dueDate, equalTo: Date(), toGranularity: .weekOfYear) { return .thisWeek }
        if cal.isDate(dueDate, equalTo: Date(), toGranularity: .month) { return .thisMonth }
        return .farFuture
    }

    init(id: UUID = UUID(), title: String, note: String = "", isCompleted: Bool = false, dueDate: Date = Date()) {
        self.id = id
        self.title = title
        self.note = note
        self.isCompleted = isCompleted
        self.dueDate = dueDate
    }

    static func sampleDefaults() -> [GoalItem] {
        let cal = Calendar.current
        let today = Date()
        let weekAhead = cal.date(byAdding: .day, value: 3, to: today) ?? today
        let monthAhead = cal.date(byAdding: .day, value: 15, to: today) ?? today
        let future = cal.date(byAdding: .day, value: 45, to: today) ?? today
        return [
            GoalItem(title: "10 min Walk", note: "Post-breakfast", dueDate: today),
            GoalItem(title: "Drink 2L water/day", note: "Hydration", dueDate: weekAhead),
            GoalItem(title: "Lose 2 lbs", note: "Weight target", dueDate: monthAhead),
            GoalItem(title: "Run 50 km", note: "Cumulative", dueDate: monthAhead),
            GoalItem(title: "Achieve 10% bodyfat", note: "Long term", dueDate: future)
        ]
    }
}

#if DEBUG
struct GoalsSection_Previews: PreviewProvider {
    static var previews: some View {
        StatefulPreviewWrapper(GoalItem.sampleDefaults()) { binding in
            GoalsSection(accentColorOverride: .accentColor, goals: binding)
        }
            .previewLayout(.sizeThatFits)
    }
}
#endif
