import SwiftUI

struct LookupResultItem: Identifiable, Hashable {
    let id = UUID()
    let fatSecretId: String?
    let name: String
    let brand: String?
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let sugar: Int
    let sodium: Int
    let potassium: Int

    func scaled(to grams: Double) -> LookupResultItem {
        let factor = grams / 100.0
        return LookupResultItem(
            fatSecretId: fatSecretId,
            name: name,
            brand: brand,
            calories: Int(round(Double(calories) * factor)),
            protein: Int(round(Double(protein) * factor)),
            carbs: Int(round(Double(carbs) * factor)),
            fat: Int(round(Double(fat) * factor)),
            sugar: Int(round(Double(sugar) * factor)),
            sodium: Int(round(Double(sodium) * factor)),
            potassium: Int(round(Double(potassium) * factor))
        )
    }
}

struct LookupComponent: View {
    var accentColor: Color

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var searchFieldIsFocused: Bool

    @State private var searchText: String = ""
    @State private var foundItems: [LookupResultItem] = []
    @State private var isLoading: Bool = false
    @State private var showingScanner: Bool = false
    @State private var scannedBarcode: String?
    @State private var scannedItem: LookupResultItem?
    @State private var errorMessage: String?
    @State private var portionSizeGrams: String = "100"
    @State private var detailItem: LookupResultItem?
    @State private var detailPortion: Int = 100
    @State private var detailNutrition: FatSecretFoodDetail?
    @State private var detailIsLoading: Bool = false
    @State private var detailError: String?

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Food Lookup")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 48)
            .padding(.bottom, 8)

            HStack(spacing: 8) {
                TextField("", text: $searchText, prompt: Text("Search foods..."))
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                    .padding()
                    .glassEffect(in: .rect(cornerRadius: 8.0))
                    .focused($searchFieldIsFocused)
                    .onSubmit { performSearch() }

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

            HStack {
                Button(action: { performSearch() }) {
                    Label("Search", systemImage: "magnifyingglass")
                        .font(.callout.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.vertical, 8)
                        .glassEffect(in: .rect(cornerRadius: 12.0))
                }
                .padding(.leading, 18)
                .buttonStyle(.plain)

                Button(action: {
                    searchFieldIsFocused = false
                    errorMessage = nil
                    showingScanner = true
                }) {
                    Image(systemName: "barcode")
                        .font(.title2.weight(.semibold))
                        .frame(minWidth: 64, minHeight: 44)
                        .padding(.vertical, 8)
                        .glassEffect(in: .rect(cornerRadius: 12.0))
                }
                .padding(.trailing, 18)
                .buttonStyle(.plain)
            }

            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Data sourced from FatSecret")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)

            if let scannedBarcode, !scannedBarcode.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.caption)
                        .foregroundStyle(accentColor)
                    Text("Scanned: \(scannedBarcode)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
            }

            if let scannedItem {
                let grams = Double(portionSizeGrams) ?? 100.0
                let scaled = scannedItem.scaled(to: grams)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(scaled.name)
                                .font(.title3.weight(.semibold))
                                .lineLimit(2)

                            if let brand = scaled.brand, !brand.isEmpty {
                                Text(brand)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Text("\(Int(grams))g")
                            .font(.caption2.weight(.medium))
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(accentColor.opacity(0.15))
                            .cornerRadius(10)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        let metrics: [(String, String)] = [
                            ("Calories", "\(scaled.calories) cal"),
                            ("Protein", "\(scaled.protein) g"),
                            ("Carbs", "\(scaled.carbs) g"),
                            ("Fat", "\(scaled.fat) g"),
                            ("Sugar", "\(scaled.sugar) g"),
                            ("Sodium", "\(scaled.sodium) mg"),
                            ("Potassium", "\(scaled.potassium) mg")
                        ]

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(metrics, id: \.0) { label, value in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(label)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(value)
                                        .font(.body.weight(.medium))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(.regularMaterial)
                                .cornerRadius(10)
                            }
                        }
                    }
                }
                .padding()
                .glassEffect(in: .rect(cornerRadius: 16.0))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
                .padding(.horizontal)
            }

            LazyVStack(spacing: 12, pinnedViews: []) {
                ForEach(foundItems) { item in
                    let grams = Double(portionSizeGrams) ?? 100.0

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.headline)
                                    .lineLimit(2)

                                if let brand = item.brand, !brand.isEmpty {
                                    Text(brand)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                // Show macronutrients text per the metric serving size (fallback to per 100g)
                                let metricText: String = {
                                    if let detail = detailNutrition, let dItem = detailItem, dItem.fatSecretId == item.fatSecretId {
                                        if let amount = detail.metricServingAmount, let unit = detail.metricServingUnit {
                                            return "per \(Int(amount))\(unit)"
                                        }
                                        if let measure = detail.measurementDescription, !measure.isEmpty {
                                            return "per \(measure)"
                                        }
                                    }
                                    return "per 100g"
                                }()

                                let calVal: Int = {
                                    if let detail = detailNutrition, let dItem = detailItem, dItem.fatSecretId == item.fatSecretId, let amount = detail.metricServingAmount {
                                        let scaled = detail.scaled(to: Double(amount))
                                        return Int(round(scaled.calories))
                                    }
                                    return item.calories
                                }()

                                let protVal: Int = {
                                    if let detail = detailNutrition, let dItem = detailItem, dItem.fatSecretId == item.fatSecretId, let amount = detail.metricServingAmount {
                                        let scaled = detail.scaled(to: Double(amount))
                                        return Int(round(scaled.protein))
                                    }
                                    return item.protein
                                }()

                                let carbVal: Int = {
                                    if let detail = detailNutrition, let dItem = detailItem, dItem.fatSecretId == item.fatSecretId, let amount = detail.metricServingAmount {
                                        let scaled = detail.scaled(to: Double(amount))
                                        return Int(round(scaled.carbs))
                                    }
                                    return item.carbs
                                }()

                                let fatVal: Int = {
                                    if let detail = detailNutrition, let dItem = detailItem, dItem.fatSecretId == item.fatSecretId, let amount = detail.metricServingAmount {
                                        let scaled = detail.scaled(to: Double(amount))
                                        return Int(round(scaled.fat))
                                    }
                                    return item.fat
                                }()

                                Text("\(calVal) cal • \(protVal) g protein • \(carbVal) g carbs • \(fatVal) g fat \(metricText)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                showDetail(for: item, portion: grams)
                            } label: {
                                Image(systemName: "info.circle")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(accentColor)
                                    .padding(6)
                                    .background(accentColor.opacity(0.12))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground).opacity(colorScheme == .dark ? 0.12 : 0.95))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(accentColor.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 4)
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 24)

            Group {
                if isLoading {
                    HStack { Spacer(); ProgressView().padding(); Spacer() }
                } else if let msg = errorMessage {
                    HStack { Spacer(); Text(msg).foregroundColor(.red).font(.caption); Spacer() }
                }
            }
            .padding(.top, 48)
        }
        .sheet(isPresented: $showingScanner) {
            BarcodeScannerView(
                onCodeFound: { code in
                    showingScanner = false
                    handleBarcode(code)
                },
                onError: { message in
                    showingScanner = false
                    errorMessage = message
                }
            )
            .ignoresSafeArea()
        }
        .sheet(item: $detailItem) { item in
            detailSheet(for: item)
                .presentationDetents([.medium, .large])
        }
    }
}

private extension LookupComponent {
    func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            foundItems = []
            return
        }

        isLoading = true
        errorMessage = nil
        scannedItem = nil

        Task {
            print("LookupComponent: performSearch -> \(query)")
            do {
                let results = try await fetchFatSecret(query: query)
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
                print("LookupComponent: fetchFatSecret error -> \(error)")
            }
            isLoading = false
        }
    }

    func handleBarcode(_ code: String) {
        let barcode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        if barcode.isEmpty {
            errorMessage = "Invalid barcode"
            return
        }

        isLoading = true
        errorMessage = nil
        scannedBarcode = barcode
        scannedItem = nil
        searchFieldIsFocused = false

        Task {
            do {
                if let item = try await OpenFoodFactsService.shared.lookup(barcode: barcode) {
                    scannedItem = item
                } else {
                    errorMessage = "No product found for barcode \(barcode)."
                }
            } catch {
                errorMessage = error.localizedDescription
                print("LookupComponent: barcode lookup error -> \(error)")
            }
            isLoading = false
        }
    }

    func fetchFatSecret(query: String) async throws -> [LookupResultItem] {
        let results = try await FatSecretService.shared.searchFoods(query: query)
        return results.map { item in
            LookupResultItem(
                fatSecretId: item.id,
                name: item.name,
                brand: item.brand,
                calories: item.calories,
                protein: item.protein,
                carbs: item.carbs,
                fat: item.fat,
                sugar: item.sugar,
                sodium: item.sodium,
                potassium: item.potassium
            )
        }
    }

    func showDetail(for item: LookupResultItem, portion: Double) {
        detailPortion = Int(portion)
        detailItem = item.scaled(to: portion)
        detailNutrition = nil
        detailError = nil

        guard let id = item.fatSecretId else {
            detailIsLoading = false
            return
        }

        detailIsLoading = true

        Task {
            do {
                let detail = try await FatSecretService.shared.getFoodDetail(id: id)
                await MainActor.run {
                    detailNutrition = detail
                    detailIsLoading = false
                }
            } catch {
                await MainActor.run {
                    detailError = error.localizedDescription
                    detailIsLoading = false
                }
            }
        }
    }

    @ViewBuilder
    func detailSheet(for item: LookupResultItem) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerSection(for: item)

                    if detailIsLoading {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    } else if let detailError {
                        Text(detailError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    } else {
                        macroSection(for: item)
                        detailSection()
                    }
                }
                .padding()
            }
            .navigationTitle("Food details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { detailItem = nil }
                        .tint(accentColor)
                }
            }
        }
    }

    @ViewBuilder
    func headerSection(for item: LookupResultItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.name)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            if let brand = item.brand, !brand.isEmpty {
                Text(brand)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Show portion plus optional metric/measurement details in a single line
            let supplemental: String? = {
                guard let detail = detailNutrition else { return nil }
                if let amount = detail.metricServingAmount,
                   let unit = detail.metricServingUnit,
                   let measure = detail.measurementDescription,
                   !measure.isEmpty {
                    return "\(Int(amount))\(unit) per \(measure)"
                }
                if let measure = detail.measurementDescription, !measure.isEmpty {
                    return "per \(measure)"
                }
                return nil
            }()

            if let sup = supplemental {
                Text("Portion: \(detailPortion)g (\(sup))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Portion: \(detailPortion)g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    func macroSection(for item: LookupResultItem) -> some View {
        let grams = Double(detailPortion)
        let base = item.scaled(to: grams)
        let detail = detailNutrition?.scaled(to: grams)

        let metrics: [(String, Double?, String, Bool)] = [
            ("Calories", detail?.calories ?? Double(base.calories), "kcal", true),
            ("Protein", detail?.protein ?? Double(base.protein), "g", false),
            ("Carbs", detail?.carbs ?? Double(base.carbs), "g", false),
            ("Fat", detail?.fat ?? Double(base.fat), "g", false)
        ]

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(metrics, id: \.0) { label, value, unit, emphasize in
                VStack(alignment: .leading, spacing: 6) {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatted(value, unit: unit))
                        .font(emphasize ? .title3.weight(.semibold) : .body.weight(.semibold))
                        .foregroundStyle(emphasize ? accentColor : .primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    @ViewBuilder
    func detailSection() -> some View {
        if let detail = detailNutrition {
            let grams = Double(detailPortion)
            let scaled = detail.scaled(to: grams)

            let secondary: [(String, Double?, String)] = [
                ("Fiber", scaled.fiber, "g"),
                ("Sugars", scaled.sugar, "g"),
                ("Saturated Fat", scaled.saturatedFat, "g"),
                ("Polyunsaturated Fat", scaled.polyunsaturatedFat, "g"),
                ("Monounsaturated Fat", scaled.monounsaturatedFat, "g"),
                ("Trans Fat", scaled.transFat, "g"),
                ("Cholesterol", scaled.cholesterol, "mg"),
                ("Sodium", scaled.sodium, "mg"),
                ("Potassium", scaled.potassium, "mg")
            ]

            VStack(alignment: .leading, spacing: 12) {
                Text("More info")
                    .font(.subheadline.weight(.semibold))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(secondary, id: \.0) { label, value, unit in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(label)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(formatted(value, unit: unit))
                                .font(.callout.weight(.medium))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(Color(.secondarySystemBackground).opacity(colorScheme == .dark ? 0.3 : 1.0))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    func pill(_ text: String, color: Color? = nil) -> some View {
        let bg = (color ?? accentColor).opacity(0.12)
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(bg)
            .clipShape(Capsule())
    }

    func formatted(_ value: Double?, unit: String) -> String {
        guard let value else { return "–" }
        let isWhole = value.truncatingRemainder(dividingBy: 1) == 0
        let number = isWhole ? String(format: "%.0f", value) : String(format: "%.1f", value)
        return "\(number) \(unit)"
    }
}
