import Foundation

struct RecipeIngredient: Codable, Hashable {
    var name: String
    var quantity: String
}

struct RecipeLookupItem: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var ingredients: [RecipeIngredient]
    var steps: [String]
    var calories: Double
    var protein: Double
    var carbs: Double
    var fats: Double

    init(
        id: UUID = UUID(),
        title: String,
        ingredients: [RecipeIngredient] = [],
        steps: [String] = [],
        calories: Double = 0,
        protein: Double = 0,
        carbs: Double = 0,
        fats: Double = 0
    ) {
        self.id = id
        self.title = title
        self.ingredients = ingredients
        self.steps = steps
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fats = fats
    }
}

/// Lightweight client to query Cloudflare D1 for recipes. Expects a Cloudflare API token with D1 query scope.
/// Configure `accountId`, `databaseId`, and `apiToken` via app secrets or build settings.
final class RecipesD1Service {
    static let shared = RecipesD1Service()

    // Inject via build settings / secrets
    var accountId: String = ProcessInfo.processInfo.environment["CLOUDFLARE_ACCOUNT_ID"] ?? "f7bfeae6c831098cfb95e8733f8bb855"
    var databaseId: String = ProcessInfo.processInfo.environment["CLOUDFLARE_RECIPES_DB_ID"] ?? "837b742f-db0e-41ad-a2bd-2a420f1b1eb7"
    var apiToken: String = ProcessInfo.processInfo.environment["CLOUDFLARE_API_TOKEN"] ?? "i_DTxvDICbKS18f-db7wAMv4uSbE1LfVnyMuoNiO"

    private init() {}

    enum ServiceError: Error, LocalizedError {
        case missingConfig
        case badResponse

        var errorDescription: String? {
            switch self {
            case .missingConfig: return "Cloudflare credentials not configured."
            case .badResponse: return "Failed to decode recipes."
            }
        }
    }

    struct D1QueryResponse: Decodable {
        struct StatementResult: Decodable {
            let results: [[String: D1Value]]?
        }
        let success: Bool
        let result: [StatementResult]?
    }

    enum D1Value: Decodable {
        case string(String)
        case number(Double)
        case bool(Bool)
        case null

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if container.decodeNil() {
                self = .null
            } else if let b = try? container.decode(Bool.self) {
                self = .bool(b)
            } else if let d = try? container.decode(Double.self) {
                self = .number(d)
            } else if let s = try? container.decode(String.self) {
                self = .string(s)
            } else {
                self = .null
            }
        }

        var stringValue: String? {
            switch self {
            case .string(let s): return s
            case .number(let n): return String(n)
            case .bool(let b): return b ? "true" : "false"
            case .null: return nil
            }
        }

        var doubleValue: Double? {
            switch self {
            case .number(let n): return n
            case .string(let s): return Double(s)
            default: return nil
            }
        }
    }

    func searchRecipes(query: String, limit: Int = 25) async throws -> [RecipeLookupItem] {
        guard !accountId.isEmpty, !databaseId.isEmpty, !apiToken.isEmpty else {
            throw ServiceError.missingConfig
        }

        let url = URL(string: "https://api.cloudflare.com/client/v4/accounts/\(accountId)/d1/database/\(databaseId)/query")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let sanitized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = "%\(sanitized)%"
        let sql = "SELECT id, title, instructions, ingredients, quantity, unit, nutr_values_per100g FROM recipes WHERE title LIKE ? LIMIT \(limit);"
        let payload: [String: Any] = ["params": [pattern], "sql": sql]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw ServiceError.badResponse
        }

        let decoded = try JSONDecoder().decode(D1QueryResponse.self, from: data)
        guard decoded.success, let statement = decoded.result?.first, let rows = statement.results else {
            throw ServiceError.badResponse
        }

        return rows.compactMap { row in
            let idString = row["id"]?.stringValue
            let id = idString.flatMap(UUID.init(uuidString:)) ?? UUID()
            let title = row["title"]?.stringValue ?? ""
            guard !title.isEmpty else { return nil }
            let instructionsJSON = row["instructions"]?.stringValue ?? ""
            let steps = Self.parseInstructions(json: instructionsJSON)

            let ingredientsJSON = row["ingredients"]?.stringValue ?? ""
            let quantitiesJSON = row["quantity"]?.stringValue ?? ""
            let unitsJSON = row["unit"]?.stringValue ?? ""
            let ingredients = Self.parseIngredients(ingredientsJSON: ingredientsJSON, quantitiesJSON: quantitiesJSON, unitsJSON: unitsJSON)

            let nutrString = row["nutr_values_per100g"]?.stringValue ?? ""
            let nutrients = Self.parseNutrients(json: nutrString)

            return RecipeLookupItem(
                id: id,
                title: title,
                ingredients: ingredients,
                steps: steps,
                calories: nutrients.calories,
                protein: nutrients.protein,
                carbs: nutrients.carbs,
                fats: nutrients.fats
            )
        }
    }

    private static func parseNutrients(json: String) -> (calories: Double, protein: Double, carbs: Double, fats: Double) {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (0, 0, 0, 0)
        }

        func value(for keys: [String]) -> Double {
            for key in keys {
                if let v = dict[key] as? Double { return v }
                if let s = dict[key] as? String, let d = Double(s) { return d }
            }
            return 0
        }

        let calories = value(for: ["calories", "energy", "kcal"])
        let protein = value(for: ["protein"])
        let carbs = value(for: [
            "carbs",
            "carbohydrates",
            "carbohydrate",
            "total_carbohydrate",
            "sugars"
        ])
        let fats = value(for: ["fat", "fats"])
        return (calories, protein, carbs, fats)
    }

    private static func parseTextArray(json: String) -> [String] {
        guard let data = json.data(using: .utf8) else { return [] }
        if let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return array.compactMap { $0["text"] as? String }
        }
        if let array = try? JSONSerialization.jsonObject(with: data) as? [String] {
            return array
        }
        return []
    }

    private static func parseIngredients(ingredientsJSON: String, quantitiesJSON: String, unitsJSON: String) -> [RecipeIngredient] {
        let names = parseTextArray(json: ingredientsJSON)
        let quantities = parseTextArray(json: quantitiesJSON)
        let units = parseTextArray(json: unitsJSON)

        var combined: [RecipeIngredient] = []
        for idx in 0..<names.count {
            let name = names[idx]
            let qty = idx < quantities.count ? quantities[idx] : ""
            let unit = idx < units.count ? units[idx] : ""
            let quantityText: String
            if !qty.isEmpty && !unit.isEmpty {
                quantityText = "\(qty) \(unit)"
            } else if !qty.isEmpty {
                quantityText = qty
            } else {
                quantityText = ""
            }
            combined.append(RecipeIngredient(name: name, quantity: quantityText))
        }
        return combined
    }

    private static func parseInstructions(json: String) -> [String] {
        guard let data = json.data(using: .utf8) else { return [] }

        // Try array of objects with "text"
        if let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            let texts = array.compactMap { $0["text"] as? String }
            if !texts.isEmpty { return texts }
        }

        // Try array of strings
        if let strings = try? JSONSerialization.jsonObject(with: data) as? [String], !strings.isEmpty {
            return strings
        }

        // Fallback: single string split by newlines
        if let single = String(data: data, encoding: .utf8), !single.isEmpty {
            return single
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        return []
    }
}
