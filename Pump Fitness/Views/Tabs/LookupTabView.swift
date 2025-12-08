import SwiftUI

// Simple food model for the lookup list
private struct FoodItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
}

struct LookupTabView: View {
        // Focus state for search field
        @FocusState private var searchFieldIsFocused: Bool
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var showCalendar = false
    @State private var selectedDate = Date()
    @State private var showAccountsView = false

    // Search state
    @State private var searchText: String = ""
    @State private var foundItems: [FoodItem] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var portionSizeGrams: String = "100"

    // Detail sheet
    @State private var showDetail = false
    @State private var selectedItem: FoodItem?

    var body: some View {
        ZStack {
            backgroundView
            ScrollView {
                VStack(spacing: 12) {
                    HeaderComponent(showCalendar: $showCalendar, selectedDate: $selectedDate, profileImage: Image("profile"), onProfileTap: { showAccountsView = true })

                    // Search bar + portion size + button (inline)
                    HStack(spacing: 8) {
                        // styled search field with prompt
                        TextField("", text: $searchText, prompt: Text("Search foods..."))
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                            .padding()
                            .glassEffect(in: .rect(cornerRadius: 8.0))
                            .focused($searchFieldIsFocused)
                            .onSubmit {
                                performSearch()
                            }

                        // Portion size input (inline)
                        HStack {
                            TextField("0", text: $portionSizeGrams)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.plain)
                            Text("g")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(width: 100)
                        .glassEffect(in: .rect(cornerRadius: 8.0))
                        .onChange(of: portionSizeGrams) { _, newValue in
                            // keep only digits
                            let filtered = newValue.filter { "0123456789".contains($0) }
                            if filtered != newValue {
                                portionSizeGrams = filtered
                            }
                            if portionSizeGrams.isEmpty {
                                portionSizeGrams = "0"
                            }
                        }

                    }
                    .padding(.horizontal)
                    .padding(.top, 48)
                        // .onAppear removed: no automatic focus on search field

                    // Full-width search button on its own line (thinner, with icon)
                    Button(action: { performSearch() }) {
                        Label("Search", systemImage: "magnifyingglass")
                            .font(.callout.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .padding(.vertical, 8)
                            .glassEffect(in: .rect(cornerRadius: 12.0))
                    }
                    .padding(.horizontal, 18)
                    // .padding(.top, 8)
                    .buttonStyle(.plain)

                    // Attribution / disclaimer for USDA data
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Data sourced from the U.S. Department of Agriculture")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)

                    // Loading / error / empty state (wrapped in Group so modifiers apply)
                    Group {
                        if isLoading {
                            HStack { Spacer(); ProgressView().padding(); Spacer() }
                        } else if let msg = errorMessage {
                            HStack { Spacer(); Text(msg).foregroundColor(.red).font(.caption); Spacer() }
                        }
                    }
                    .padding(.top, 48)

                    // Results
                    LazyVStack(spacing: 10, pinnedViews: []) {
                        ForEach(foundItems) { item in
                        // compute scaled macros for the selected portion size (visible to entire row)
                        let grams = Double(portionSizeGrams) ?? 100.0
                        let scaledCalories = Int(round(Double(item.calories) * grams / 100.0))
                        let scaledProtein = Int(round(Double(item.protein) * grams / 100.0))
                        let scaledCarbs = Int(round(Double(item.carbs) * grams / 100.0))
                        let scaledFat = Int(round(Double(item.fat) * grams / 100.0))

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(item.name)
                                        .font(.headline)

                                    Text("\(Int(grams))g")
                                        .font(.caption2)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 6)
                                        .background(currentAccent.opacity(0.15))
                                        .cornerRadius(6)

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
                                        Text("\(scaledCalories) cal")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }

                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(.red)
                                            .frame(width: 8, height: 8)
                                        Text("\(scaledProtein)g")
                                            .font(.caption2)
                                    }

                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(Color(.systemTeal))
                                            .frame(width: 8, height: 8)
                                        Text("\(scaledCarbs)g")
                                            .font(.caption2)
                                    }

                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(.orange)
                                            .frame(width: 8, height: 8)
                                        Text("\(scaledFat)g")
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
            }
            if showCalendar {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture { showCalendar = false }
                CalendarComponent(selectedDate: $selectedDate, showCalendar: $showCalendar)
            }
        }
        .navigationDestination(isPresented: $showAccountsView) {
            AccountsView()
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
            foundItems = []
            return
        }

        // Run async fetch to USDA Food API
        isLoading = true
        errorMessage = nil
        Task {
            print("LookupTabView: performSearch -> \(query)")
            do {
                let results = try await fetchUSDA(query: query)
                if results.isEmpty {
                    foundItems = []
                    errorMessage = "No results found for \(query)."
                } else {
                    foundItems = results
                    errorMessage = nil
                }
            } catch {
                errorMessage = error.localizedDescription
                foundItems = []
                print("LookupTabView: fetchUSDA error -> \(error)")
            }
            isLoading = false
        }
    }

    // Fetch USDA FoodData Central search results (requires API key in Info.plist under `USDA_API_KEY` or env `USDA_API_KEY`)
    func fetchUSDA(query: String) async throws -> [FoodItem] {
        // read API key from multiple sources: Info.plist, environment variables, UserDefaults
        let candidates = [
            "USDA_API_KEY",
            "INFOPLIST_KEY_USDA_API_KEY"
        ]

        var apiKey: String? = nil
        for key in candidates {
            if let val = Bundle.main.object(forInfoDictionaryKey: key) as? String, !val.isEmpty {
                apiKey = val
                break
            }
            if let val = ProcessInfo.processInfo.environment[key], !val.isEmpty {
                apiKey = val
                break
            }
            if let val = Bundle.main.infoDictionary?[key] as? String, !val.isEmpty {
                apiKey = val
                break
            }
            if let val = UserDefaults.standard.string(forKey: key), !val.isEmpty {
                apiKey = val
                break
            }
        }

        // treat placeholder values as missing
        if let k = apiKey, k == "REPLACE_ME_USDA_API_KEY" {
            apiKey = nil
        }

        guard let apiKey = apiKey, !apiKey.isEmpty else {
            let guidance = "USDA API key not found. Add `USDA_API_KEY` as an environment variable in your Xcode scheme (Edit Scheme → Run → Environment Variables) or add a build setting `INFOPLIST_KEY_USDA_API_KEY` (set value in target Build Settings)."
            throw NSError(domain: "USDA", code: 0, userInfo: [NSLocalizedDescriptionKey: guidance])
        }

        guard let url = URL(string: "https://api.nal.usda.gov/fdc/v1/foods/search?api_key=\(apiKey)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "query": query,
            "pageSize": 25
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let msg = String(data: data, encoding: .utf8) ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw NSError(domain: "USDA", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
        }

        struct SearchResponse: Codable {
            let foods: [FoodData]?
        }

        struct FoodData: Codable {
            let description: String?
            let foodNutrients: [Nutrient]?
        }

        struct Nutrient: Codable {
            let nutrientName: String?
            let value: Double?
        }

        let decoder = JSONDecoder()
        let resp = try decoder.decode(SearchResponse.self, from: data)
        let foods = resp.foods ?? []

        // Map USDA foods to local FoodItem model by picking nutrient values heuristically
        let rawMapped: [FoodItem] = foods.compactMap { f in
            let name = f.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown"
            var calories = 0
            var protein = 0
            var carbs = 0
            var fat = 0

            if let nutrients = f.foodNutrients {
                for n in nutrients {
                    guard let nName = n.nutrientName?.lowercased(), let val = n.value else { continue }
                    if nName.contains("energy") || nName.contains("kcal") || nName.contains("calorie") {
                        calories = Int(round(val))
                    } else if nName.contains("protein") {
                        protein = Int(round(val))
                    } else if nName.contains("carbohydrate") || nName.contains("carb") {
                        carbs = Int(round(val))
                    } else if nName.contains("fat") || nName.contains("lipid") {
                        fat = Int(round(val))
                    }
                }
            }

            return FoodItem(name: name, calories: calories, protein: protein, carbs: carbs, fat: fat)
        }

        // Deduplicate by normalized description (case-insensitive). When duplicates occur, prefer the item
        // with the larger sum of nutrient values (more complete data).
        var deduped: [String: FoodItem] = [:]
        func score(_ item: FoodItem) -> Int {
            return item.calories + item.protein + item.carbs + item.fat
        }

        for item in rawMapped {
            let key = item.name.lowercased()
            if let existing = deduped[key] {
                if score(item) > score(existing) {
                    deduped[key] = item
                }
            } else {
                deduped[key] = item
            }
        }

        let mapped = deduped.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return mapped
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
