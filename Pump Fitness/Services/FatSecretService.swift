import Foundation

struct FatSecretFood: Hashable {
    let id: String
    let name: String
    let brand: String?
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let sugar: Int
    let sodium: Int
    let potassium: Int
}

struct FatSecretFoodDetail: Hashable {
    let id: String
    let name: String
    let brand: String?
    let foodType: String?
    let foodUrl: String?
    let measurementDescription: String?
    let numberOfUnits: Double?
    let servingDescription: String?
    let metricServingAmount: Double?
    let metricServingUnit: String?
    let calories: Double?
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let saturatedFat: Double?
    let polyunsaturatedFat: Double?
    let monounsaturatedFat: Double?
    let transFat: Double?
    let cholesterol: Double?
    let sodium: Double?
    let potassium: Double?
    let fiber: Double?
    let sugar: Double?

    func scaled(to grams: Double) -> FatSecretFoodDetail {
        guard let serving = metricServingAmount, serving > 0 else { return self }
        let factor = grams / serving
        func scale(_ value: Double?) -> Double? { value.map { $0 * factor } }

        return FatSecretFoodDetail(
            id: id,
            name: name,
            brand: brand,
            foodType: foodType,
            foodUrl: foodUrl,
            measurementDescription: measurementDescription,
            numberOfUnits: numberOfUnits.map { $0 * factor },
            servingDescription: servingDescription,
            metricServingAmount: grams,
            metricServingUnit: metricServingUnit,
            calories: scale(calories),
            protein: scale(protein),
            carbs: scale(carbs),
            fat: scale(fat),
            saturatedFat: scale(saturatedFat),
            polyunsaturatedFat: scale(polyunsaturatedFat),
            monounsaturatedFat: scale(monounsaturatedFat),
            transFat: scale(transFat),
            cholesterol: scale(cholesterol),
            sodium: scale(sodium),
            potassium: scale(potassium),
            fiber: scale(fiber),
            sugar: scale(sugar)
        )
    }
}

final class FatSecretService {
    static let shared = FatSecretService()

    private struct Token {
        let value: String
        let expiry: Date
    }

    private var cachedToken: Token?
    private let decoder = JSONDecoder()

    func searchFoods(query: String, pageSize: Int = 25) async throws -> [FatSecretFood] {
        let token = try await accessToken()

        guard let url = URL(string: "https://platform.fatsecret.com/rest/server.api") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body: [String: String] = [
            "method": "foods.search",
            "search_expression": query,
            "format": "json",
            "max_results": String(pageSize),
            "page_number": "0"
        ]
        request.httpBody = body.percentEncoded()

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let msg = String(data: data, encoding: .utf8) ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw NSError(domain: "FatSecret", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
        }

        let payload = try decoder.decode(FoodsSearchResponse.self, from: data)
        let foods = payload.foods?.food ?? []
        let mapped = foods.map(mapFood)
        return dedupe(mapped)
    }

    private func accessToken() async throws -> String {
        if let cached = cachedToken, cached.expiry.timeIntervalSinceNow > 60 {
            return cached.value
        }

        guard let url = URL(string: "https://oauth.fatsecret.com/connect/token") else {
            throw URLError(.badURL)
        }

        let clientId = FatSecretCredentials.clientId
        let clientSecret = FatSecretCredentials.clientSecret

        guard !clientId.isEmpty, !clientSecret.isEmpty, !FatSecretCredentials.isPlaceholder(clientId), !FatSecretCredentials.isPlaceholder(clientSecret) else {
            let guidance = "FatSecret credentials missing. Set them in FatSecretCredentials or via env FATSECRET_CLIENT_ID / FATSECRET_CLIENT_SECRET."
            throw NSError(domain: "FatSecret", code: 0, userInfo: [NSLocalizedDescriptionKey: guidance])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let credentials = "\(clientId):\(clientSecret)"
        if let encoded = credentials.data(using: .utf8)?.base64EncodedString() {
            request.setValue("Basic \(encoded)", forHTTPHeaderField: "Authorization")
        }

        let body = "grant_type=client_credentials&scope=basic"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let msg = String(data: data, encoding: .utf8) ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw NSError(domain: "FatSecret", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
        }

        let token = try decoder.decode(TokenResponse.self, from: data)
        let expiry = Date().addingTimeInterval(Double(token.expiresIn))
        let cached = Token(value: token.accessToken, expiry: expiry)
        cachedToken = cached
        return cached.value
    }

    private func mapFood(_ food: FatSecretFoodData) -> FatSecretFood {
        let id = food.foodId ?? UUID().uuidString
        let name = food.foodName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown"
        let brand = food.brandName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = food.foodDescription ?? ""

        let calories = extract(labels: ["calorie", "calories", "kcal", "kcals"], in: description)
        let protein = extract(labels: ["protein", "proteins", "prot"], in: description)
        let carbs = extract(labels: ["carb", "carbs", "carbohydrate", "carbohydrates"], in: description)
        let fat = extract(labels: ["fat", "fats", "lipid", "lipids"], in: description)
        let sugar = extract(labels: ["sugar", "sugars"], in: description)
        let sodium = extract(labels: ["sodium", "salt", "na"], in: description)
        let potassium = extract(labels: ["potassium", "k"], in: description)

        return FatSecretFood(
            id: id,
            name: name,
            brand: brand,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            sugar: sugar,
            sodium: sodium,
            potassium: potassium
        )
    }

    private func extract(labels: [String], in text: String) -> Int {
        // FatSecret descriptions vary (e.g., "Carbohydrates: 13.1g" or "Carbohydrate 13.1g | Sugars 10g")
        for rawLabel in labels {
            let label = NSRegularExpression.escapedPattern(for: rawLabel)
            let pattern = "(?i)\\b\(label)s?\\b[^0-9]*([0-9]+(?:\\.[0-9]+)?)"
            if let value = firstMatch(pattern: pattern, in: text) {
                return Int(round(value))
            }
        }
        return 0
    }

    func getFoodDetail(id: String) async throws -> FatSecretFoodDetail {
        let token = try await accessToken()

        guard let url = URL(string: "https://platform.fatsecret.com/rest/server.api") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body: [String: String] = [
            "method": "food.get.v5",
            "food_id": id,
            "format": "json"
        ]
        request.httpBody = body.percentEncoded()

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let msg = String(data: data, encoding: .utf8) ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw NSError(domain: "FatSecret", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
        }

        let payload = try decoder.decode(FoodGetResponse.self, from: data)
        guard let detail = payload.food else {
            throw NSError(domain: "FatSecret", code: 0, userInfo: [NSLocalizedDescriptionKey: "Missing food data"])
        }
        return mapDetail(detail)
    }

    private func mapDetail(_ data: FoodDetailData) -> FatSecretFoodDetail {
        let serving = data.servings?.serving?.first

        func num(_ value: String?) -> Double? {
            guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
            return Double(trimmed)
        }

        return FatSecretFoodDetail(
            id: data.foodId ?? UUID().uuidString,
            name: data.foodName ?? "Unknown",
            brand: data.brandName,
            foodType: data.foodType,
            foodUrl: data.foodUrl,
            measurementDescription: serving?.measurementDescription,
            numberOfUnits: num(serving?.numberOfUnits),
            servingDescription: serving?.servingDescription,
            metricServingAmount: num(serving?.metricServingAmount),
            metricServingUnit: serving?.metricServingUnit,
            calories: num(serving?.calories),
            protein: num(serving?.protein),
            carbs: num(serving?.carbohydrate),
            fat: num(serving?.fat),
            saturatedFat: num(serving?.saturatedFat),
            polyunsaturatedFat: num(serving?.polyunsaturatedFat),
            monounsaturatedFat: num(serving?.monounsaturatedFat),
            transFat: num(serving?.transFat),
            cholesterol: num(serving?.cholesterol),
            sodium: num(serving?.sodium),
            potassium: num(serving?.potassium),
            fiber: num(serving?.fiber),
            sugar: num(serving?.sugar)
        )
    }

    private func firstMatch(pattern: String, in text: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1 else { return nil }
        if let valueRange = Range(match.range(at: 1), in: text) {
            return Double(text[valueRange])
        }
        return nil
    }

    private func dedupe(_ items: [FatSecretFood]) -> [FatSecretFood] {
        var deduped: [String: FatSecretFood] = [:]
        for item in items {
            let brandPart = item.brand?.lowercased() ?? ""
            let key = "\(brandPart)|\(item.name.lowercased())"
            if let existing = deduped[key] {
                if score(item) > score(existing) {
                    deduped[key] = item
                }
            } else {
                deduped[key] = item
            }
        }
        return deduped.values.sorted {
            if let lhsBrand = $0.brand, let rhsBrand = $1.brand, lhsBrand.localizedCaseInsensitiveCompare(rhsBrand) != .orderedSame {
                return lhsBrand.localizedCaseInsensitiveCompare(rhsBrand) == .orderedAscending
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func score(_ item: FatSecretFood) -> Int {
        item.calories + item.protein + item.carbs + item.fat + item.sugar + item.sodium + item.potassium
    }
}

private struct TokenResponse: Decodable {
    let accessToken: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
    }
}

private struct FoodsSearchResponse: Decodable {
    let foods: FoodsContainer?
}

private struct FoodsContainer: Decodable {
    let food: [FatSecretFoodData]?
}

private struct FatSecretFoodData: Decodable {
    let foodId: String?
    let foodName: String?
    let brandName: String?
    let foodDescription: String?

    enum CodingKeys: String, CodingKey {
        case foodId = "food_id"
        case foodName = "food_name"
        case brandName = "brand_name"
        case foodDescription = "food_description"
    }
}

private struct FoodGetResponse: Decodable {
    let food: FoodDetailData?
}

private struct FoodDetailData: Decodable {
    let foodId: String?
    let foodName: String?
    let brandName: String?
    let foodType: String?
    let foodUrl: String?
    let servings: FoodDetailServings?

    enum CodingKeys: String, CodingKey {
        case foodId = "food_id"
        case foodName = "food_name"
        case brandName = "brand_name"
        case foodType = "food_type"
        case foodUrl = "food_url"
        case servings
    }
}

private struct FoodDetailServings: Decodable {
    let serving: [FoodServing]?
}

private struct FoodServing: Decodable {
    let servingDescription: String?
    let measurementDescription: String?
    let numberOfUnits: String?
    let metricServingAmount: String?
    let metricServingUnit: String?
    let calories: String?
    let carbohydrate: String?
    let protein: String?
    let fat: String?
    let saturatedFat: String?
    let polyunsaturatedFat: String?
    let monounsaturatedFat: String?
    let transFat: String?
    let cholesterol: String?
    let sodium: String?
    let potassium: String?
    let fiber: String?
    let sugar: String?

    enum CodingKeys: String, CodingKey {
        case servingDescription = "serving_description"
        case measurementDescription = "measurement_description"
        case numberOfUnits = "number_of_units"
        case metricServingAmount = "metric_serving_amount"
        case metricServingUnit = "metric_serving_unit"
        case calories
        case carbohydrate
        case protein
        case fat
        case saturatedFat = "saturated_fat"
        case polyunsaturatedFat = "polyunsaturated_fat"
        case monounsaturatedFat = "monounsaturated_fat"
        case transFat = "trans_fat"
        case cholesterol
        case sodium
        case potassium
        case fiber
        case sugar
    }
}

enum FatSecretCredentials {
    static let clientId = "fd07ad867a964c9e8c5acc2b44de4828"
    static let clientSecret = "2c248fad736d4fabafb1fa6faaff19b5"

    static func isPlaceholder(_ value: String) -> Bool {
        value.contains("REPLACE_ME") || value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private extension Dictionary where Key == String, Value == String {
    func percentEncoded() -> Data? {
        map { key, value in
            let escapedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let escapedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            return "\(escapedKey)=\(escapedValue)"
        }
        .joined(separator: "&")
        .data(using: .utf8)
    }
}
