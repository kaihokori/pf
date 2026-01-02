import SwiftUI
import UIKit
import Photos
import SwiftData
import UniformTypeIdentifiers

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
                        ZStack {
                            Rectangle()
                                .fill(Color.white)
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
                        }
                        .dynamicTypeSize(.medium)
                        .environment(\.sizeCategory, .medium)
                        .environment(\.colorScheme, .light)
                        .frame(maxWidth: 480)
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
        let width: CGFloat = 350

        let renderView = ZStack {
            Rectangle()
                .fill(Color.white)
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
        .fixedSize(horizontal: false, vertical: true)
        .dynamicTypeSize(.medium)
        .environment(\.sizeCategory, .medium)
        .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: renderView)
        renderer.scale = 3.0
        renderer.isOpaque = false
        return renderer.uiImage
    }
    
    private func shareCurrentCard() {
        guard let image = renderCurrentCard() else { return }
        let itemSource = ShareImageItemSource(image: image)
        sharePayload = ShareProgressPayload(items: [itemSource])
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
            .background(Color(UIColor.secondarySystemBackground))
            
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
                    MacrosSection(macros: macros, color: .green)
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
            GradientBackground(theme: .other)
        }
        .cornerRadius(isExporting ? 0 : 24)
        .overlay(
            RoundedRectangle(cornerRadius: isExporting ? 0 : 24)
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
            .background(Color(UIColor.secondarySystemBackground))
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
                .foregroundStyle(.black)
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
                .frame(height: 30)
            Text("Trackerio")
                .font(.headline)
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

/// Ensures exported images are advertised as PNGs so the share sheet shows photo targets (e.g., Photos, Instagram, Messenger).
final class ShareImageItemSource: NSObject, UIActivityItemSource {
    private let image: UIImage

    init(image: UIImage) {
        self.image = image
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        image
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        image
    }

    func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        UTType.png.identifier
    }
}

fileprivate struct ShareProgressPayload: Identifiable {
    let id = UUID()
    let items: [Any]
}
