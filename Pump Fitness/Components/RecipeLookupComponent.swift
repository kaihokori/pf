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
    @State private var showSafari = false
    @State private var safariURL: URL?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                  VStack(spacing: 12) {
                      HStack(spacing: 8) {
                          TextField("Search recipes...", text: $searchText)
                              .textInputAutocapitalization(.words)
                              .disableAutocorrection(true)
                              .padding()
                              .adaptiveGlassEffect(in: .rect(cornerRadius: 8.0))
                              .focused($searchFocused)
                              .onSubmit { runSearch() }
                      }
                      .padding(.horizontal)

                      HStack {
                          Button(action: { runSearch() }) {
                              Label("Search", systemImage: "magnifyingglass")
                                  .font(.callout.weight(.semibold))
                                  .frame(maxWidth: .infinity, minHeight: 44)
                                  .padding(.vertical, 8)
                                  .adaptiveGlassEffect(in: .rect(cornerRadius: 12.0))
                          }
                          .padding(.horizontal, 18)
                          .buttonStyle(.plain)
                      }
                    }

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

                                let pillColumns = [GridItem(.flexible()), GridItem(.flexible())]
                                LazyVGrid(columns: pillColumns, spacing: 12) {
                                    macroPill(label: "Calories", value: item.calories, unit: "cal")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    macroPill(label: "Protein", value: item.protein, unit: "g")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    macroPill(label: "Carbs", value: item.carbs, unit: "g")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    macroPill(label: "Fats", value: item.fats, unit: "g")
                                        .frame(maxWidth: .infinity, alignment: .leading)
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
                .padding(.top, 12)
            }
            .navigationTitle("Recipe Lookup")
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
                    .presentationDragIndicator(.hidden)
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
                Spacer()
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
                          // View Source button (only for resolvable http/https URLs)
                          if let url = item.sourceURL,
                              let scheme = url.scheme?.lowercased(),
                              scheme == "http" || scheme == "https" {
                        // Button {
                        //     safariURL = url
                        //     showSafari = true
                        // } label: {
                        //     HStack(spacing: 8) {
                        //         Image(systemName: "link")
                        //         Text("View Source")
                        //     }
                        //     .frame(maxWidth: .infinity, minHeight: 44)
                        // }
                        // .buttonStyle(.borderedProminent)
                        // .tint(accentColor)
                        // .padding(.top, 6)
                    }
                }
                .padding()
            }
            .navigationTitle("Recipe details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Return") {
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
            .sheet(isPresented: $showSafari) {
                Group {
                    if let url = safariURL {
                        SafariView(url: url)
                    } else {
                        EmptyView()
                    }
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

            Text("Nutrition: Per 100g serving")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
                    HStack(alignment: .center, spacing: 8) {
                        Circle()
                            .fill(accentColor)
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
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(idx + 1)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(accentColor)
                                .frame(width: 22)
                                .offset(y: 4)
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
