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
    @State private var shareItems: [Any] = []
    @State private var mealEntries: [MealIntakeEntry] = []
    
    // Toggles
    @State private var showCalories = true
    @State private var showMacros = true
    @State private var showSupplements = true
    @State private var showMeals = true
    @State private var showCravings = true
    @State private var showFasting = true
    
    var body: some View {
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
                        if fastingMinutes > 0 {
                            ToggleRow(title: "Fasting", isOn: $showFasting, icon: "clock.fill", color: .purple)
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
                        fastingMinutes: fastingMinutes,
                        showCalories: showCalories,
                        showMacros: showMacros,
                        showSupplements: showSupplements,
                        showMeals: showMeals,
                        showCravings: showCravings,
                        showFasting: showFasting,
                        accentColor: accentColor
                    )
                    .padding(.horizontal, 20)
                    .shadow(color: Color.black.opacity(0.1), radius: 15, x: 0, y: 8)
                }
                .padding(.bottom, 100) // Space for button
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
        .background(Color(UIColor.systemBackground))
        .presentationDetents([.large])
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: shareItems)
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
        let width: CGFloat = 375
        let height: CGFloat = 667 // 9:16 aspect ratio
        
        let renderView = ZStack {
            Color(UIColor.systemBackground)
            
            CustomizableShareCard(
                caloriesConsumed: caloriesConsumed,
                calorieGoal: calorieGoal,
                maintenanceCalories: maintenanceCalories,
                macros: macros,
                supplements: supplements,
                takenSupplements: takenSupplements,
                mealEntries: mealEntries,
                cravings: cravings,
                fastingMinutes: fastingMinutes,
                showCalories: showCalories,
                showMacros: showMacros,
                showSupplements: showSupplements,
                showMeals: showMeals,
                showCravings: showCravings,
                showFasting: showFasting,
                accentColor: accentColor
            )
            .padding()
        }
        .frame(width: width, height: height)
        
        let renderer = ImageRenderer(content: renderView)
        renderer.scale = 3.0
        return renderer.uiImage
    }
    
    private func shareCurrentCard() {
        guard let image = renderCurrentCard() else { return }
        shareItems = [image]
        showShareSheet = true
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
    var fastingMinutes: Int
    
    var showCalories: Bool
    var showMacros: Bool
    var showSupplements: Bool
    var showMeals: Bool
    var showCravings: Bool
    var showFasting: Bool
    
    var accentColor: Color
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DAILY SUMMARY")
                        .font(.caption)
                        .fontWeight(.black)
                        .foregroundStyle(accentColor)
                        .tracking(1)
                    
                    Text(Date().formatted(date: .abbreviated, time: .omitted))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                }
                Spacer()
                PumpBranding()
            }
            .padding(24)
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
                
                if showFasting && fastingMinutes > 0 {
                    FastingSection(minutes: fastingMinutes, color: .purple)
                }
            }
            .padding(24)
        }
        .background(Color(UIColor.systemBackground))
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
                            Text(macro.currentLabel)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
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
            
            VStack(spacing: 8) {
                ForEach(supplements.prefix(4)) { supplement in
                    HStack {
                        Image(systemName: takenIDs.contains(supplement.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(takenIDs.contains(supplement.id) ? color : .secondary)
                        Text(supplement.name)
                            .font(.subheadline)
                            .strikethrough(takenIDs.contains(supplement.id))
                            .foregroundStyle(takenIDs.contains(supplement.id) ? .secondary : .primary)
                        Spacer()
                    }
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
            
            VStack(spacing: 8) {
                ForEach(cravings.prefix(3)) { craving in
                    HStack {
                        Image(systemName: craving.isChecked ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(craving.isChecked ? color : .secondary)
                        Text(craving.name)
                            .font(.subheadline)
                            .strikethrough(craving.isChecked)
                            .foregroundStyle(craving.isChecked ? .secondary : .primary)
                        Spacer()
                    }
                }
            }
        }
    }
}

struct FastingSection: View {
    var minutes: Int
    var color: Color
    
    var hours: Int { minutes / 60 }
    var mins: Int { minutes % 60 }
    
    var body: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "FASTING", icon: "clock.fill", color: color)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Protocol")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(hours):\(String(format: "%02d", mins))")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                Spacer()
                Image(systemName: "timer")
                    .font(.largeTitle)
                    .foregroundStyle(color.opacity(0.5))
            }
            .padding(16)
            .background(color.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
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
                .frame(height: 18)
            Text("Trackerio")
                .font(.caption)
                .fontWeight(.bold)
                .textCase(.uppercase)
        }
        .foregroundStyle(.secondary.opacity(0.7))
        .padding(.top, 8)
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
