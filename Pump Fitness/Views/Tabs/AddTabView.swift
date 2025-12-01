import SwiftUI

struct QuickAddSheetView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @Binding private var selectedAction: QuickAddAction
    init(selectedAction: Binding<QuickAddAction>) {
        _selectedAction = selectedAction
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundView

                VStack(spacing: 20) {
                    ScrollView {
                        VStack(spacing: 24) {
                            actionContent
                        }
                        .padding(.bottom, 12)
                    }
                    .scrollIndicators(.hidden)

                    Button(action: dismiss.callAsFunction) {
                        Text("Done")
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .glassEffect(in: .rect(cornerRadius: 16.0))
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .tint(currentAccent)
    }
}

struct QuickAddSectionCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: .rect(cornerRadius: 16.0))
    }
}

private extension QuickAddSheetView {
    var currentAccent: Color {
        if themeManager.selectedTheme == .multiColour {
            return .accentColor
        }
        return themeManager.selectedTheme.accent(for: colorScheme)
    }

    @ViewBuilder
    var backgroundView: some View {
        if themeManager.selectedTheme == .multiColour {
            GradientBackground(theme: .add)
        } else {
            themeManager.selectedTheme.background(for: colorScheme)
                .ignoresSafeArea()
        }
    }

    func toggleAction() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            selectedAction = selectedAction == .nutrition ? .workout : .nutrition
        }
    }

    @ViewBuilder
    var actionContent: some View {
        switch selectedAction {
        case .nutrition:
            QuickAddSectionCard {
                Text("Nutrition shortcuts")
                    .font(.headline)
                    .fontWeight(.semibold)
                Text("Log meals, hydration, or supplements without leaving the current screen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                quickActionList(for: nutritionQuickActions)
            }
        case .workout:
            QuickAddSectionCard {
                Text("Workout shortcuts")
                    .font(.headline)
                    .fontWeight(.semibold)
                Text("Schedule sessions or record sets in a couple taps.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                quickActionList(for: workoutQuickActions)
            }
        }
    }

    @ViewBuilder
    private func quickActionList(for options: [QuickAddOption]) -> some View {
        VStack(spacing: 12) {
            ForEach(options) { option in
                Button(action: {}) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(option.tint.opacity(0.16))
                                .frame(width: 44, height: 44)
                            Image(systemName: option.iconName)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(option.tint)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(option.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .glassEffect(in: .rect(cornerRadius: 14.0))
                }
                .tint(option.tint)
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }

    var nutritionQuickActions: [QuickAddOption] {
        [
            QuickAddOption(
                title: "Log Meal",
                subtitle: "Search USDA foods or scan a barcode",
                iconName: "fork.knife.circle.fill",
                tint: .orange
            ),
            QuickAddOption(
                title: "Track Water",
                subtitle: "Add the last bottle or glass",
                iconName: "drop.circle.fill",
                tint: .cyan
            ),
            QuickAddOption(
                title: "Supplements",
                subtitle: "Record vitamins or creatine",
                iconName: "pills.circle.fill",
                tint: .purple
            )
        ]
    }

    var workoutQuickActions: [QuickAddOption] {
        [
            QuickAddOption(
                title: "Start Workout",
                subtitle: "Open your latest routine",
                iconName: "figure.strengthtraining.traditional",
                tint: .green
            ),
            QuickAddOption(
                title: "Log Set",
                subtitle: "Add weight + reps quickly",
                iconName: "dumbbell.fill",
                tint: .blue
            ),
            QuickAddOption(
                title: "Schedule Session",
                subtitle: "Block time with your coach",
                iconName: "calendar.badge.plus",
                tint: .pink
            )
        ]
    }
}

private struct QuickAddOption: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let iconName: String
    let tint: Color
}

enum QuickAddAction: String, CaseIterable, Identifiable {
    case nutrition
    case workout

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nutrition: return "Nutrition"
        case .workout: return "Workout"
        }
    }
}


#Preview {
    struct PreviewWrapper: View {
        @State private var action: QuickAddAction = .nutrition

        var body: some View {
            QuickAddSheetView(selectedAction: $action)
                .environmentObject(ThemeManager())
        }
    }

    return PreviewWrapper()
}
