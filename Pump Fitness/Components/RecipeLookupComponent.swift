import SwiftUI

struct RecipeLookupComponent: View {
    var accentColor: Color
    var onAdd: (RecipeLookupItem) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText: String = ""
    @State private var results: [RecipeLookupItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var searchFocused: Bool
    @State private var detailItem: RecipeLookupItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recipe Lookup")
                            .font(.title3.weight(.semibold))
                        Text("Search recipes from your Cloudflare D1 catalog")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    HStack(spacing: 10) {
                        TextField("Search recipes...", text: $searchText)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                            .padding(12)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                            .focused($searchFocused)
                            .onSubmit { runSearch() }

                        Button(action: runSearch) {
                            Image(systemName: "magnifyingglass")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(accentColor, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)

                    if isLoading {
                        ProgressView().padding(.top, 20)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 20)
                    }

                    LazyVStack(spacing: 12) {
                        ForEach(results) { item in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .top, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.title)
                                            .font(.headline)
                                            .fixedSize(horizontal: false, vertical: true)
                                        if let first = item.steps.first {
                                            Text(first)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                    }

                                    Spacer()

                                    Button {
                                        detailItem = item
                                    } label: {
                                        Image(systemName: "chevron.forward.circle")
                                            .font(.title3.weight(.semibold))
                                            .foregroundStyle(accentColor)
                                            .padding(6)
                                            .background(accentColor.opacity(0.12))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                }

                                HStack(spacing: 12) {
                                    macroPill(label: "Calories", value: item.calories, unit: "cal")
                                    macroPill(label: "Protein", value: item.protein, unit: "g")
                                    macroPill(label: "Carbs", value: item.carbs, unit: "g")
                                    macroPill(label: "Fats", value: item.fats, unit: "g")
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground).opacity(colorScheme == .dark ? 0.2 : 1.0))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(accentColor.opacity(0.15), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 4)
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.vertical, 10)
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("Lookup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismissSelf()
                    }
                }
            }
            .onAppear {
                searchFocused = true
            }
            .sheet(item: $detailItem) { item in
                detailSheet(for: item)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    private func dismissSelf() {
        dismiss()
    }

    private func runSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            results = []
            errorMessage = nil
            return
        }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let items = try await RecipesD1Service.shared.searchRecipes(query: query)
                await MainActor.run {
                    results = items
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    results = []
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    @ViewBuilder
    private func macroPill(label: String, value: Double, unit: String) -> some View {
        let show = value > 0
        if show {
            HStack(spacing: 4) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(formatNutrition(value: value))\(unit)")
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(accentColor.opacity(0.12), in: Capsule())
        }
    }

    private func formatNutrition(value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        if rounded.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(rounded))
        }
        var s = String(format: "%.2f", rounded)
        while s.last == "0" {
            s.removeLast()
        }
        if s.last == "." {
            s.removeLast()
        }
        return s
    }

    @ViewBuilder
    private func detailSheet(for item: RecipeLookupItem) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection(for: item)
                    macroSection(for: item)
                    ingredientsSection(for: item)
                    stepsSection(for: item)
                }
                .padding()
            }
            .navigationTitle("Recipe details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        detailItem = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(item)
                        detailItem = nil
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    @ViewBuilder
    private func headerSection(for item: RecipeLookupItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.title)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            if let first = item.steps.first {
                Text(first)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func macroSection(for item: RecipeLookupItem) -> some View {
        let metrics: [(String, Double, String, Bool)] = [
            ("Calories", item.calories, "kcal", true),
            ("Protein", item.protein, "g", false),
            ("Carbs", item.carbs, "g", false),
            ("Fats", item.fats, "g", false)
        ]

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(metrics, id: \.0) { label, value, unit, emphasize in
                VStack(alignment: .leading, spacing: 6) {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(formatNutrition(value: value)) \(unit)")
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
    private func ingredientsSection(for item: RecipeLookupItem) -> some View {
        if !item.ingredients.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Ingredients")
                    .font(.subheadline.weight(.semibold))

                ForEach(item.ingredients, id: \.self) { ing in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(accentColor.opacity(0.15))
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ing.name)
                                .font(.body)
                            if !ing.quantity.trimmingCharacters(in: .whitespaces).isEmpty {
                                Text(ing.quantity)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func stepsSection(for item: RecipeLookupItem) -> some View {
        if !item.steps.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Method")
                    .font(.subheadline.weight(.semibold))

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(item.steps.enumerated()), id: \.0) { idx, step in
                        HStack(alignment: .center, spacing: 8) {
                            Text("\(idx + 1)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(accentColor)
                                .frame(width: 22)
                                .offset(y: 2)
                            Text(step)
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground).opacity(colorScheme == .dark ? 0.3 : 1.0))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}
