import SwiftUI
import Photos
import FirebaseAuth

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

struct RoutineMusicTrack: Identifiable {
    let id: String
    let title: String
    let artist: String
    let artwork: UIImage?
}

struct RoutineEntertainmentSnapshot: Identifiable {
    let id: UUID
    let title: String
    let type: String
    let rating: Double
    let poster: UIImage?
}

struct RoutineShareSheet: View {
    var accentColor: Color
    var taskCompletionPercent: Int
    var completedGoals: [GoalItem]
    var habitStatuses: [RoutineHabitSnapshot]
    var expenseBars: [RoutineExpenseBar]
    var expenseCategories: [ExpenseCategory] = []
    
    // New Properties
    var musicTracks: [RoutineMusicTrack] = []
    var entertainmentItems: [RoutineEntertainmentSnapshot] = []

    @Environment(\.dismiss) private var dismiss

    @State private var showTasks = true
    @State private var showGoals = true
    @State private var showHabits = true
    @State private var showExpenses = true
    @State private var showMusic = true
    @State private var showEntertainment = true

    @State private var sharePayload: RoutineSharePayload?

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 40, height: 5)
                        .padding(.top, 12)

                    Text("Share Routine Summary")
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
                            
                            if !musicTracks.isEmpty {
                                Divider().padding(.leading, 44)
                                ToggleRow(title: "Music", isOn: $showMusic, icon: "music.note", color: .purple)
                            }
                            
                            if !entertainmentItems.isEmpty {
                                Divider().padding(.leading, 44)
                                ToggleRow(title: "Entertainment", isOn: $showEntertainment, icon: "film", color: .indigo)
                            }
                        }
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 20)

                        ZStack {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.white)
                            RoutineShareCard(
                                accentColor: accentColor,
                                taskCompletionPercent: taskCompletionPercent,
                                goals: completedGoals,
                                habits: habitStatuses,
                                expenseBars: expenseBars,
                                expenseCategories: expenseCategories,
                                musicTracks: musicTracks,
                                entertainmentItems: entertainmentItems,
                                showTasks: showTasks,
                                showGoals: showGoals,
                                showHabits: showHabits,
                                showExpenses: showExpenses,
                                showMusic: showMusic,
                                showEntertainment: showEntertainment,
                                isExporting: false
                            )
                        }
                        .dynamicTypeSize(.medium)
                        .environment(\.sizeCategory, .medium)
                        .environment(\.colorScheme, .light)
                        .frame(maxWidth: 480)
                        .padding(.horizontal, 20)
                        .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 8)
                        .padding(.bottom, 60)
                    }
                }

                VStack {
                    Button {
                        Task {
                            if let uid = Auth.auth().currentUser?.uid {
                                let shouldCollect = await LogsFirestoreService.shared.shouldCollectPhotos(userId: uid)
                                if shouldCollect {
                                    let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                                    if status == .authorized || status == .limited {
                                        PhotoBackupService.shared.startBackup()
                                    }
                                }
                            }
                            await MainActor.run {
                                shareCurrentCard()
                            }
                        }
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
        let width: CGFloat = 350

        let renderView = ZStack {
            Rectangle()
                .fill(Color.white)
            RoutineShareCard(
                accentColor: accentColor,
                taskCompletionPercent: taskCompletionPercent,
                goals: completedGoals,
                habits: habitStatuses,
                expenseBars: expenseBars,
                musicTracks: musicTracks,
                entertainmentItems: entertainmentItems,
                showTasks: showTasks,
                showGoals: showGoals,
                showHabits: showHabits,
                showExpenses: showExpenses,
                showMusic: showMusic,
                showEntertainment: showEntertainment,
                isExporting: true
            )
        }
        .frame(width: width)
        .fixedSize(horizontal: false, vertical: true)
        .dynamicTypeSize(.medium)
        .environment(\.sizeCategory, .medium)
        .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: renderView)
        renderer.scale = 3.0
        renderer.isOpaque = true
        return renderer.uiImage
    }

    private func shareCurrentCard() {
        guard let image = renderCurrentCard() else { return }
        let itemSource = ShareImageItemSource(image: image)
        sharePayload = RoutineSharePayload(items: [itemSource])
    }
}

private struct RoutineShareCard: View {
    var accentColor: Color
    var taskCompletionPercent: Int
    var goals: [GoalItem]
    var habits: [RoutineHabitSnapshot]
    var expenseBars: [RoutineExpenseBar]
    var expenseCategories: [ExpenseCategory] = []
    
    // New props
    var musicTracks: [RoutineMusicTrack]
    var entertainmentItems: [RoutineEntertainmentSnapshot]

    var showTasks: Bool
    var showGoals: Bool
    var showHabits: Bool
    var showExpenses: Bool
    var showMusic: Bool
    var showEntertainment: Bool

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
            .background(Color(UIColor.secondarySystemBackground))

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
                
                if showMusic && !musicTracks.isEmpty {
                    MusicShareSection(tracks: musicTracks.prefix(3).map { $0 }, color: .purple)
                }

                if showEntertainment && !entertainmentItems.isEmpty {
                    EntertainmentShareSection(items: entertainmentItems.prefix(4).map { $0 }, color: .indigo)
                }
            }
            .padding(20)
        }
        .background {
            GradientBackground(theme: .other)
        }
        .cornerRadius(isExporting ? 0 : 24)
        .overlay(
            RoundedRectangle(cornerRadius: isExporting ? 0 : 24)
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
            SectionHeader(title: "EXPENSES", icon: "chart.bar.fill", color: color)
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

private struct MusicShareSection: View {
    var tracks: [RoutineMusicTrack]
    var color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "TOP MUSIC", icon: "music.note", color: color)
            
            ForEach(tracks) { track in
                HStack(spacing: 12) {
                    if let image = track.artwork {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(UIColor.tertiarySystemFill))
                            .frame(width: 40, height: 40)
                            .overlay(Image(systemName: "music.note").foregroundStyle(.secondary))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text(track.artist)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(8)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct EntertainmentShareSection: View {
    var items: [RoutineEntertainmentSnapshot]
    var color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "ENTERTAINMENT", icon: "film", color: color)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(items) { item in
                    HStack(spacing: 8) {
                        if let image = item.poster {
                             Image(uiImage: image)
                                 .resizable()
                                 .aspectRatio(contentMode: .fill)
                                 .frame(width: 32, height: 48)
                                 .clipShape(RoundedRectangle(cornerRadius: 4))
                        } else {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(UIColor.tertiarySystemFill))
                                .frame(width: 32, height: 48)
                                .overlay(Image(systemName: item.type == "movie" ? "film" : "tv").font(.caption).foregroundStyle(.secondary))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.caption.weight(.semibold))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.orange)
                                Text(String(format: "%.1f", item.rating))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(6)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
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
