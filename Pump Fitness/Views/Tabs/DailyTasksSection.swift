import SwiftUI
import SwiftData

private enum DailyTasksLayout {
    static let tileMinHeight: CGFloat = 150
}

struct DailyTasksSection: View {
    var accentColorOverride: Color?
    @Binding var tasks: [DailyTaskItem]
    var tileMinHeight: CGFloat = DailyTasksLayout.tileMinHeight
    var onToggle: (String, Bool) -> Void
    var onRemove: (String) -> Void
    // Optional binding to the Day model so the section can read/write the preferred weight unit.
    var day: Binding<Day?>? = nil

    var body: some View {

        VStack(spacing: 16) {
            // Weight unit toggle (per-day preference)
            HStack {
                Spacer()
                WeightUnitToggleView(day: day)
            }
            .padding(.horizontal, 18)

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
                                        DailyTaskCircle(item: task, isCentered: isCentered) {
                                            toggleTask(withId: task.id)
                                        } onCenter: {
                                            withAnimation(.spring()) {
                                                proxy.scrollTo(task.id, anchor: .center)
                                            }
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

    private func toggleTask(withId id: String) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[idx].isCompleted.toggle()
        onToggle(id, tasks[idx].isCompleted)
    }

    private func removeTask(withId id: String) {
        tasks.removeAll { $0.id == id }
        onRemove(id)
    }

    
}

private struct DailyTaskCircle: View {
    var item: DailyTaskItem
    var isCentered: Bool
    var onToggle: () -> Void
    var onCenter: () -> Void
    var onRemove: () -> Void

    var body: some View {
        Button(action: {
            if isCentered {
                onToggle()
            } else {
                onCenter()
            }
        }) {
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

private struct WeightUnitToggleView: View {
    var day: Binding<Day?>?
    @Environment(\.modelContext) private var modelContext
    @State private var weightUnit: String = "kg"

    var body: some View {
        Button(action: toggleUnit) {
            Text(weightUnit.uppercased())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.secondary.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
        .onAppear {
            if let d = day?.wrappedValue, let w = d.weightUnitRaw {
                weightUnit = w
            } else {
                weightUnit = "kg"
            }
        }
    }

    private func toggleUnit() {
        let new = (weightUnit == "kg") ? "lbs" : "kg"
        weightUnit = new
        if let binding = day, let d = binding.wrappedValue {
            d.weightUnitRaw = new
            binding.wrappedValue = d
            do {
                try modelContext.save()
            } catch {
                // ignore save errors here
            }
        }
    }
}


struct DailyTaskItem: Identifiable, Equatable {
    let id: String
    var name: String
    var time: String
    var colorHex: String
    var isCompleted: Bool
    var repeats: Bool

    var color: Color { Color(hex: colorHex) ?? .accentColor }

    init(id: String = UUID().uuidString, name: String, time: String, colorHex: String, isCompleted: Bool = false, repeats: Bool = true) {
        self.id = id
        self.name = name
        self.time = time
        self.colorHex = colorHex
        self.isCompleted = isCompleted
        self.repeats = repeats
    }

    static let defaultTasks: [DailyTaskItem] = [
        DailyTaskItem(name: "Wake Up", time: "07:00", colorHex: "#D84A4A"),
        DailyTaskItem(name: "Hydrate", time: "08:00", colorHex: "#4FB6C6"),
        DailyTaskItem(name: "Stretch", time: "09:00", colorHex: "#7A5FD1"),
        DailyTaskItem(name: "Workout", time: "18:00", colorHex: "#E39A3B"),
        DailyTaskItem(name: "Wind Down", time: "22:00", colorHex: "#4CAF6A")
    ]
}

// MARK: - Preview
#if DEBUG
struct DailyTasksSection_Previews: PreviewProvider {
    static var previews: some View {
        StatefulPreviewWrapper(DailyTaskItem.defaultTasks) { binding in
            DailyTasksSection(accentColorOverride: nil, tasks: binding, onToggle: { _, _ in }, onRemove: { _ in })
                .previewLayout(.sizeThatFits)
        }
    }
}

struct StatefulPreviewWrapper<Value: MutableCollection & RandomAccessCollection & RangeReplaceableCollection>: View where Value: MutableCollection, Value: RangeReplaceableCollection {
    @State var value: Value
    var content: (Binding<Value>) -> any View

    init(_ value: Value, content: @escaping (Binding<Value>) -> any View) {
        _value = State(initialValue: value)
        self.content = content
    }

    var body: some View {
        AnyView(content($value))
    }
}
#endif
