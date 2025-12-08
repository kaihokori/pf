import SwiftUI

struct GoalsSection: View {
    var accentColorOverride: Color?

    // Always expanded - no collapse toggles

    @State private var thisWeekGoals: [GoalItem] = [
        GoalItem(title: "Complete 3 workouts", note: "Aim for 3 sessions"),
        GoalItem(title: "Sleep 7+ hours/night", note: "Daily target"),
        GoalItem(title: "Drink 2L water/day", note: "Hydration")
    ]

    @State private var thisMonthGoals: [GoalItem] = [
        GoalItem(title: "Run 50 km", note: "Cumulative"),
        GoalItem(title: "Lose 2 lbs", note: "Weight target")
    ]

    @State private var farFutureGoals: [GoalItem] = [
        GoalItem(title: "Complete a half marathon", note: "Training plan"),
        GoalItem(title: "Achieve 10% bodyfat", note: "Long term")
    ]

    @State private var todayGoals: [GoalItem] = [
        GoalItem(title: "Log Breakfast", note: "Protein + carbs"),
        GoalItem(title: "Take Vitamins", note: "Multivitamin"),
        GoalItem(title: "10 min Walk", note: "Post-breakfast")
    ]

    private var tint: Color {
        accentColorOverride ?? .accentColor
    }

    private let cardWidth: CGFloat = 280

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                // Today card
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Spacer()
                        Label("Today", systemImage: "sun.max.fill")
                            .font(.callout.weight(.semibold))
                        Spacer()
                    }
                    .padding(.bottom, 8)

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(todayGoals.indices, id: \.self) { idx in
                            let goal = todayGoals[idx]
                            Button(action: {
                                todayGoals[idx].isCompleted.toggle()
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

                                    Text(goal.title)
                                        .font(.subheadline.weight(.semibold))

                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)

                            if idx != todayGoals.indices.last {
                                Divider()
                                    .overlay(Color.white.opacity(0.06))
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
                .padding(16)
                .frame(width: cardWidth)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .glassEffect(in: .rect(cornerRadius: 16.0))

                // This Week card
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Spacer()
                        Label("This Week", systemImage: "calendar")
                            .font(.callout.weight(.semibold))
                        Spacer()
                    }
                    .padding(.bottom, 8)

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(thisWeekGoals.indices, id: \.self) { idx in
                            let goal = thisWeekGoals[idx]
                            Button(action: {
                                thisWeekGoals[idx].isCompleted.toggle()
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

                                    Text(goal.title)
                                        .font(.subheadline.weight(.semibold))

                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)

                            if idx != thisWeekGoals.indices.last {
                                Divider()
                                    .overlay(Color.white.opacity(0.06))
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
                .padding(16)
                .frame(width: cardWidth)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .glassEffect(in: .rect(cornerRadius: 16.0))

                // This Month card
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Spacer()
                        Label("This Month", systemImage: "calendar.badge.clock")
                            .font(.callout.weight(.semibold))
                        Spacer()
                    }
                    .padding(.bottom, 8)

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(thisMonthGoals.indices, id: \.self) { idx in
                            let goal = thisMonthGoals[idx]
                            Button(action: {
                                thisMonthGoals[idx].isCompleted.toggle()
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

                                    Text(goal.title)
                                        .font(.subheadline.weight(.semibold))

                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)

                            if idx != thisMonthGoals.indices.last {
                                Divider()
                                    .overlay(Color.white.opacity(0.06))
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
                .padding(16)
                .frame(width: cardWidth)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .glassEffect(in: .rect(cornerRadius: 16.0))

                // Far Future card
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Spacer()
                        Label("Far Future", systemImage: "sparkles")
                            .font(.callout.weight(.semibold))
                        Spacer()
                    }
                    .padding(.bottom, 8)

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(farFutureGoals.indices, id: \.self) { idx in
                            let goal = farFutureGoals[idx]
                            Button(action: {
                                farFutureGoals[idx].isCompleted.toggle()
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

                                    Text(goal.title)
                                        .font(.subheadline.weight(.semibold))

                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)

                            if idx != farFutureGoals.indices.last {
                                Divider()
                                    .overlay(Color.white.opacity(0.06))
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
            .padding(.vertical, 6)
            .padding(.leading, 6)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }
}

struct GoalItem: Identifiable, Equatable {
    let id: UUID
    var title: String
    var note: String
    var isCompleted: Bool

    init(id: UUID = UUID(), title: String, note: String = "", isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.note = note
        self.isCompleted = isCompleted
    }
}

#if DEBUG
struct GoalsSection_Previews: PreviewProvider {
    static var previews: some View {
        GoalsSection(accentColorOverride: .accentColor)
            .previewLayout(.sizeThatFits)
    }
}
#endif
