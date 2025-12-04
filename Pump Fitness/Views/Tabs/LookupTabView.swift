import SwiftUI

// Simple food model for the lookup list
private struct FoodItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int

    static let sampleData: [FoodItem] = [
        FoodItem(name: "Chicken Breast", calories: 165, protein: 31, carbs: 0, fat: 4),
        FoodItem(name: "Chicken Thigh", calories: 209, protein: 26, carbs: 0, fat: 10),
        FoodItem(name: "Chicken Wings", calories: 203, protein: 27, carbs: 0, fat: 8),
        FoodItem(name: "Chicken Drumstick", calories: 185, protein: 22, carbs: 0, fat: 9),
        FoodItem(name: "Chicken Nuggets", calories: 290, protein: 15, carbs: 20, fat: 18),
        FoodItem(name: "Grilled Chicken Salad", calories: 350, protein: 30, carbs: 15, fat: 20),
        FoodItem(name: "Chicken Stir Fry", calories: 400, protein: 35, carbs: 30, fat: 15),
        FoodItem(name: "Chicken Soup", calories: 150, protein: 20, carbs: 10, fat: 5),
        FoodItem(name: "Chicken Sandwich", calories: 450, protein: 40, carbs: 35, fat: 15),
        FoodItem(name: "Chicken Curry", calories: 500, protein: 45, carbs: 25, fat: 20),
        FoodItem(name: "Avocado Toast", calories: 250, protein: 6, carbs: 20, fat: 18),
        FoodItem(name: "Banana Smoothie", calories: 300, protein: 8, carbs: 50, fat: 5),
        FoodItem(name: "Quinoa Salad", calories: 350, protein: 12, carbs: 45, fat: 10),
        FoodItem(name: "Greek Yogurt", calories: 100, protein: 10, carbs: 5, fat: 0),
        FoodItem(name: "Oatmeal Bowl", calories: 200, protein: 6, carbs: 30, fat: 4)
    ]
}

struct LookupTabView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var showCalendar = false
    @State private var selectedDate = Date()
    @State private var showAccountsView = false

    // Search state
    @State private var searchText: String = ""
    @State private var foundItems: [FoodItem] = FoodItem.sampleData

    // Detail sheet
    @State private var showDetail = false
    @State private var selectedItem: FoodItem?

    var body: some View {
        ZStack {
            backgroundView
            ScrollView {
                VStack(spacing: 12) {
                    HeaderComponent(showCalendar: $showCalendar, selectedDate: $selectedDate, profileImage: Image("profile"), onProfileTap: { showAccountsView = true })

                    // Search bar + button
                    HStack(spacing: 8) {
                        TextField("Search foods...", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .onSubmit {
                                performSearch()
                            }

                        Button(action: { performSearch() }) {
                            Text("Search")
                                .bold()
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(currentAccent.opacity(0.15))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)

                    // Results
                    LazyVStack(spacing: 10, pinnedViews: []) {
                        ForEach(foundItems) { item in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(item.name)
                                        .font(.headline)
                                    Spacer()
                                    Button {
                                        selectedItem = item
                                        showDetail = true
                                    } label: {
                                        Image(systemName: "info.circle")
                                            .imageScale(.large)
                                    }
                                    .buttonStyle(.plain)
                                }

                                HStack(spacing: 12) {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(Color.primary.opacity(0.8))
                                            .frame(width: 8, height: 8)
                                        Text("\(item.calories) cal")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }

                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(.red)
                                            .frame(width: 8, height: 8)
                                        Text("\(item.protein)g")
                                            .font(.caption2)
                                    }

                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(Color(.systemTeal))
                                            .frame(width: 8, height: 8)
                                        Text("\(item.carbs)g")
                                            .font(.caption2)
                                    }

                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(.orange)
                                            .frame(width: 8, height: 8)
                                        Text("\(item.fat)g")
                                            .font(.caption2)
                                    }

                                    Spacer()
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground).opacity(colorScheme == .dark ? 0.08 : 0.9))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 24)
                }
                .padding(.top)
                .onAppear {
                    // When testing, default the search to "Chicken" so related items show up immediately
                    if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        searchText = "Chicken"
                        performSearch()
                    }
                }
            }
        }
        .sheet(isPresented: $showDetail) {
            if let selectedItem = selectedItem {
                NutritionDetailView(item: selectedItem)
            }
        }
    }
}

private extension LookupTabView {
    var currentAccent: Color {
        if themeManager.selectedTheme == .multiColour {
            return .accentColor
        }
        return themeManager.selectedTheme.accent(for: colorScheme)
    }

    @ViewBuilder
    var backgroundView: some View {
        if themeManager.selectedTheme == .multiColour {
            GradientBackground(theme: .lookup)
        } else {
            themeManager.selectedTheme.background(for: colorScheme)
                .ignoresSafeArea()
        }
    }

    func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            foundItems = FoodItem.sampleData
        } else {
            foundItems = FoodItem.sampleData.filter { $0.name.localizedCaseInsensitiveContains(query) }
        }
    }
}

// Simple nutrition detail view shown in a sheet when tapping the info button
private struct NutritionDetailView: View {
    let item: FoodItem
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text(item.name)
                    .font(.largeTitle)
                    .bold()

                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Calories: \(item.calories)")
                        Text("Protein: \(item.protein) g")
                        Text("Carbs: \(item.carbs) g")
                        Text("Fat: \(item.fat) g")
                    }
                    Spacer()
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Nutrition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}

#Preview {
    LookupTabView()
        .environmentObject(ThemeManager())
}
