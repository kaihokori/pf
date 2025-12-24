import SwiftUI

struct GoalsSection: View {
    var accentColorOverride: Color?
    @Binding var goals: [GoalItem]

    private var tint: Color {
        accentColorOverride ?? .accentColor
    }

    private let cardWidth: CGFloat = 280

    private var groupedGoals: [GoalBucket: [GoalItem]] {
        // Group only non-completed goals so completed ones appear only
        // in the `Completed` column.
        Dictionary(grouping: goals.filter { !$0.isCompleted }, by: { $0.bucket })
    }

    private var overdueGoals: [GoalItem] {
        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)
        return goals.filter { !$0.isCompleted && $0.dueDate < startOfToday }
    }

    private var completedGoals: [GoalItem] {
        goals.filter { $0.isCompleted }
    }

    var body: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    if !overdueGoals.isEmpty {
                        overdueCard()
                    }
                    if !completedGoals.isEmpty {
                        completedCard()
                    }
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

    @ViewBuilder
    private func overdueCard() -> some View {
        let items = overdueGoals

        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Label("Overdue", systemImage: "exclamationmark.circle.fill")
                    .font(.callout.weight(.semibold))
                Spacer()
            }
            .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 12) {
                if items.isEmpty {
                    HStack {
                        Text("No overdue goals")
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

    @ViewBuilder
    private func completedCard() -> some View {
        let items = completedGoals

        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Label("Completed", systemImage: "checkmark.circle.fill")
                    .font(.callout.weight(.semibold))
                Spacer()
            }
            .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 12) {
                if items.isEmpty {
                    HStack {
                        Text("No completed goals")
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
