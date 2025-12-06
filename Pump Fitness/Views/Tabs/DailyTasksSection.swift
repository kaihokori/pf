import SwiftUI

private enum DailyTasksLayout {
    static let tileMinHeight: CGFloat = 150
}

struct DailyTasksSection: View {
    var accentColorOverride: Color?
    var initialTasks: [DailyTaskItem] = DailyTaskItem.defaultTasks
    var tileMinHeight: CGFloat = DailyTasksLayout.tileMinHeight

    @State private var tasks: [DailyTaskItem]

    

    init(accentColorOverride: Color? = nil, initialTasks: [DailyTaskItem] = DailyTaskItem.defaultTasks, tileMinHeight: CGFloat = DailyTasksLayout.tileMinHeight) {
        self.accentColorOverride = accentColorOverride
        self.initialTasks = initialTasks
        self.tileMinHeight = tileMinHeight
        _tasks = State(initialValue: initialTasks)
    }

    var body: some View {

        VStack(spacing: 16) {
            // GeometryReader to compute center of the viewport for scaling
            GeometryReader { outerGeo in
                let centerX = outerGeo.frame(in: .global).midX

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        // allow first and last items to center by adding side insets
                        let sideInset = max(0, (outerGeo.size.width - 92) / 2 - 22)
                        HStack(spacing: 12) {
                            Spacer(minLength: 8)


                            ForEach(tasks) { task in
                                GeometryReader { itemGeo in
                                    let itemMidX = itemGeo.frame(in: .global).midX
                                    let distance = abs(itemMidX - centerX)
                                    // snap between two discrete scales (snappy behavior)
                                    let maxScale: CGFloat = 1.6
                                    let minScale: CGFloat = 0.85
                                    let threshold: CGFloat = 40 // within this many pts we consider the item "centered"
                                    let isCentered = distance < threshold
                                    let scale = isCentered ? maxScale : minScale

                                    VStack(spacing: 4) {
                                        DailyTaskCircle(item: task) {
                                            toggleTask(withId: task.id)
                                        } onRemove: {
                                            removeTask(withId: task.id)
                                        }
                                        Text(task.name)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.center)
                                            .lineLimit(2)
                                            .minimumScaleFactor(0.8)
                                            .frame(width: 92, alignment: .top)
                                    }
                                    .padding(.top, 30)
                                    .frame(width: 92)
                                    .scaleEffect(scale)
                                    .animation(.interactiveSpring(response: 0.18, dampingFraction: 0.7, blendDuration: 0), value: isCentered)
                                }
                                .frame(width: 92, height: tileMinHeight)
                            }

                            Spacer(minLength: 8)
                        }
                        .padding(.vertical, 6)
                        .padding(.leading, sideInset)
                        .padding(.trailing, sideInset)
                    }
                    .padding(.horizontal, 6)
                    .onAppear {
                        // Start scrolled to the center task
                        guard !tasks.isEmpty else { return }
                        let middleIndex = tasks.count / 2
                        if middleIndex < tasks.count {
                            let targetId = tasks[middleIndex].id
                            DispatchQueue.main.async {
                                proxy.scrollTo(targetId, anchor: .center)
                            }
                        }
                    }
                }
            }
            .frame(height: tileMinHeight)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.top, 10)
    }

    private func toggleTask(withId id: UUID) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[idx].isCompleted.toggle()
    }

    private func removeTask(withId id: UUID) {
        tasks.removeAll { $0.id == id }
    }

    
}

private struct DailyTaskCircle: View {
    var item: DailyTaskItem
    var onToggle: () -> Void
    var onRemove: () -> Void

    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 2) {
                ZStack {
                    // base ring
                    Circle()
                        .stroke(item.color.opacity(0.18), lineWidth: 6)
                        .frame(width: 54, height: 54)

                    // progress ring (trim) — matches SupplementRing style
                    Circle()
                        .trim(from: 0, to: item.isCompleted ? 1 : 0)
                        .stroke(item.color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 54, height: 54)

                    // content: checkmark when completed, otherwise the time
                    if item.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(item.color)
                    } else {
                        Text(item.time)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(item.color)
                    }
                }
                .padding(.bottom, 2)
            }
        }
        .frame(width: 92, alignment: .top)
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive, action: onRemove) {
                Label("Remove", systemImage: "trash")
            }
        }
        .animation(.spring(), value: item.isCompleted)
    }
}

struct DailyTaskItem: Identifiable, Equatable {
    let id: UUID
    let name: String
    let time: String
    var color: Color
    var isCompleted: Bool

    init(id: UUID = UUID(), name: String, time: String, color: Color, isCompleted: Bool = false) {
        self.id = id
        self.name = name
        self.time = time
        self.color = color
        self.isCompleted = isCompleted
    }

    static let defaultTasks: [DailyTaskItem] = [
        DailyTaskItem(name: "Hookup", time: "2:00", color: .pink),
        DailyTaskItem(name: "Morning Wood", time: "9:30", color: .green),
        DailyTaskItem(name: "Jerk Off", time: "14:00", color: .purple),
        DailyTaskItem(name: "Workout", time: "19:30", color: .orange),
        DailyTaskItem(name: "Shower", time: "23:00", color: .blue)
    ]
}

// MARK: - Preview
#if DEBUG
struct DailyTasksSection_Previews: PreviewProvider {
    static var previews: some View {
        DailyTasksSection()
            .previewLayout(.sizeThatFits)
    }
}
#endif
