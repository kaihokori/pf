import SwiftUI
import UIKit
import Photos
import SwiftData

struct ShareProgressSheet: View {
    var caloriesConsumed: Int
    var calorieGoal: Int
    var maintenanceCalories: Int
    var macros: [MacroMetric]
    var supplements: [Supplement]
    var takenSupplements: Set<String>
    var cravings: [CravingItem]
    var fastingMinutes: Int
    var selectedDate: Date
    var trackedMacros: [TrackedMacro]
    var accentColor: Color
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var showShareSheet = false
    @State private var sharePayload: ShareProgressPayload? = nil
    @State private var mealEntries: [MealIntakeEntry] = []
    
    // Toggles
    @State private var showCalories = true
    @State private var showMacros = true
    @State private var showSupplements = true
    @State private var showMeals = true
    @State private var showCravings = true
    
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 40, height: 5)
                        .padding(.top, 12)
                    
                    Text("Share Your Achievements")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .padding(.bottom, 16)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Controls
                        VStack(spacing: 0) {
                            ToggleRow(title: "Calories", isOn: $showCalories, icon: "flame.fill", color: .orange)
                            Divider().padding(.leading, 44)
                            ToggleRow(title: "Macros", isOn: $showMacros, icon: "chart.pie.fill", color: .blue)
                            Divider().padding(.leading, 44)
                            if !supplements.isEmpty {
                                ToggleRow(title: "Supplements", isOn: $showSupplements, icon: "pills.fill", color: .green)
                                Divider().padding(.leading, 44)
                            }
                            if !mealEntries.isEmpty {
                                ToggleRow(title: "Meals", isOn: $showMeals, icon: "fork.knife", color: .yellow)
                                Divider().padding(.leading, 44)
                            }
                            if !cravings.isEmpty {
                                ToggleRow(title: "Cravings", isOn: $showCravings, icon: "shield.fill", color: .pink)
                                Divider().padding(.leading, 44)
                            }
                            
                        }
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 20)

                        // Card Preview
                        CustomizableShareCard(
                            caloriesConsumed: caloriesConsumed,
                            calorieGoal: calorieGoal,
                            maintenanceCalories: maintenanceCalories,
                            macros: macros,
                            supplements: supplements,
                            takenSupplements: takenSupplements,
                            mealEntries: mealEntries,
                            cravings: cravings,
                            showCalories: showCalories,
                            showMacros: showMacros,
                            showSupplements: showSupplements,
                            showMeals: showMeals,
                            showCravings: showCravings,
                            accentColor: accentColor
                        )
                        .dynamicTypeSize(.medium)
                        .environment(\.sizeCategory, .medium)
                        .padding(.horizontal, 20)
                        .shadow(color: Color.black.opacity(0.1), radius: 15, x: 0, y: 8)
                    }
                    .padding(.bottom, 40) // Space for button
                }
                
                // Share Button
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
                            LinearGradient(colors: [accentColor, accentColor.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
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
        .onAppear {
            fetchMeals()
        }
    }
    
    private func fetchMeals() {
        let day = Day.fetchOrCreate(for: selectedDate, in: modelContext, trackedMacros: trackedMacros)
        mealEntries = day.mealIntakes
    }
    
    @MainActor
    private func renderCurrentCard() -> UIImage? {
        let width: CGFloat = 540

        // Render without an explicit background so exported image is transparent.
        let renderView = ZStack {
            CustomizableShareCard(
                caloriesConsumed: caloriesConsumed,
                calorieGoal: calorieGoal,
                maintenanceCalories: maintenanceCalories,
                macros: macros,
                supplements: supplements,
                takenSupplements: takenSupplements,
                mealEntries: mealEntries,
                cravings: cravings,
                showCalories: showCalories,
                showMacros: showMacros,
                showSupplements: showSupplements,
                showMeals: showMeals,
                showCravings: showCravings,
                accentColor: accentColor,
                isExporting: true
            )
        }
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
        guard let url = saveImageToTempPNG(image, prefix: "progress") else { return }
        sharePayload = ShareProgressPayload(items: [url])
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

struct ToggleRow: View {
    var title: String
    @Binding var isOn: Bool
    var icon: String
    var color: Color
    
    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 24)
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .tint(color)
    }
}

struct CustomizableShareCard: View {
    var caloriesConsumed: Int
    var calorieGoal: Int
    var maintenanceCalories: Int
    var macros: [MacroMetric]
    var supplements: [Supplement]
    var takenSupplements: Set<String>
    var mealEntries: [MealIntakeEntry]
    var cravings: [CravingItem]
    var showCalories: Bool
    var showMacros: Bool
    var showSupplements: Bool
    var showMeals: Bool
    var showCravings: Bool
    
    var accentColor: Color
    var isExporting: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DAILY SUMMARY")
                        .font(.caption2)
                        .fontWeight(.black)
                        .foregroundStyle(accentColor)
                        .tracking(0.5)

                    Text(Date().formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }
                Spacer()
                PumpBranding()
                    .scaleEffect(0.85)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(accentColor.opacity(0.05))
            
            VStack(spacing: 24) {
                if showCalories {
                    CaloriesSection(
                        consumed: caloriesConsumed,
                        goal: calorieGoal,
                        maintenance: maintenanceCalories,
                        color: accentColor
                    )
                }
                
                if showMacros {
                    MacrosSection(macros: macros, color: .blue)
                }
                
                if showMeals && !mealEntries.isEmpty {
                    MealsSection(meals: mealEntries, color: .yellow)
                }
                
                if showSupplements && !supplements.isEmpty {
                    SupplementsSection(
                        supplements: supplements,
                        takenIDs: takenSupplements,
                        color: .green
                    )
                }
                
                if showCravings && !cravings.isEmpty {
                    CravingsSection(cravings: cravings, color: .pink)
                }
                
                
            }
            .padding(24)
        }
        .dynamicTypeSize(.medium)
        .environment(\.sizeCategory, .medium)
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

// MARK: - Sections

struct CaloriesSection: View {
    var consumed: Int
    var goal: Int
    var maintenance: Int
    var color: Color
    
    var body: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "CALORIES", icon: "flame.fill", color: color)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Consumed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(consumed)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(color)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Goal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(goal)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                VStack(alignment: .trailing) {
                    Text("Maint.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(maintenance)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(color.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct MacrosSection: View {
    var macros: [MacroMetric]
    var color: Color
    
    var body: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "MACROS", icon: "chart.pie.fill", color: color)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(macros.prefix(4)) { macro in
                    HStack {
                        ZStack {
                            Circle()
                                .stroke(macro.color.opacity(0.2), lineWidth: 4)
                            Circle()
                                .trim(from: 0, to: macro.percent)
                                .stroke(macro.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Text("\(Int(macro.percent * 100))%")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .frame(width: 36, height: 36)
                        
                        VStack(alignment: .leading, spacing: 0) {
                            Text(macro.title)
                                .font(.caption)
                                .fontWeight(.bold)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Text(macro.currentLabel)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
}

struct MealsSection: View {
    var meals: [MealIntakeEntry]
    var color: Color
    
    var body: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "MEALS", icon: "fork.knife", color: color)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(meals) { meal in
                    HStack {
                        Text(meal.itemName.isEmpty ? meal.mealType.displayName : meal.itemName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(meal.calories) cal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    Divider()
                }
            }
        }
    }
}

struct SupplementsSection: View {
    var supplements: [Supplement]
    var takenIDs: Set<String>
    var color: Color
    
    var body: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "SUPPLEMENTS", icon: "pills.fill", color: color)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                let displayLimit = supplements.count > 4 ? 3 : min(supplements.count, 4)

                ForEach(supplements.prefix(displayLimit)) { supplement in
                    HStack(spacing: 8) {
                        Image(systemName: takenIDs.contains(supplement.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(takenIDs.contains(supplement.id) ? color : .secondary)
                        Text(supplement.name)
                            .font(.subheadline)
                            .strikethrough(takenIDs.contains(supplement.id))
                            .foregroundStyle(takenIDs.contains(supplement.id) ? .secondary : .primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer()
                    }
                    .padding(8)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                if supplements.count > 4 {
                    let moreCount = supplements.count - 3
                    HStack(spacing: 8) {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(color)
                        Text("+ \(moreCount) more")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(8)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
}

struct CravingsSection: View {
    var cravings: [CravingItem]
    var color: Color
    
    var body: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "CRAVINGS", icon: "shield.fill", color: color)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                let displayLimit = cravings.count > 4 ? 3 : min(cravings.count, 4)

                ForEach(cravings.prefix(displayLimit)) { craving in
                    HStack {
                        Image(systemName: craving.isChecked ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(craving.isChecked ? color : .secondary)
                        Text(craving.name)
                            .font(.subheadline)
                            .strikethrough(craving.isChecked)
                            .foregroundStyle(craving.isChecked ? .secondary : .primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer()
                    }
                    .padding(8)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                if cravings.count > 4 {
                    let moreCount = cravings.count - 3
                    HStack(spacing: 8) {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(color)
                        Text("+ \(moreCount) more")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(8)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
}



struct SectionHeader: View {
    var title: String
    var icon: String
    var color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

struct PumpBranding: View {
    var body: some View {
        HStack(spacing: 6) {
            Image("logo")
                .resizable()
                .renderingMode(.original)
                .aspectRatio(contentMode: .fit)
                .frame(height: 28)
            Text("Trackerio")
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .foregroundStyle(.secondary.opacity(0.7))
        .padding(.top, 2)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

fileprivate struct ShareProgressPayload: Identifiable {
    let id = UUID()
    let items: [Any]
}
