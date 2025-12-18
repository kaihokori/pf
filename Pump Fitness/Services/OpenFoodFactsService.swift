import Foundation

struct OpenFoodFactsNutriments: Decodable {
    let energyKcal100g: Double?
    let proteins100g: Double?
    let carbohydrates100g: Double?
    let fat100g: Double?
    let sugars100g: Double?
    let sodium100g: Double?
    let potassium100g: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case proteins100g = "proteins_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case fat100g = "fat_100g"
        case sugars100g = "sugars_100g"
        case sodium100g = "sodium_100g"
        case potassium100g = "potassium_100g"
    }
}

struct OpenFoodFactsProduct: Decodable {
    let productName: String?
    let brands: String?
    let nutriments: OpenFoodFactsNutriments?

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case brands
        case nutriments
    }
}

struct OpenFoodFactsLookupResponse: Decodable {
    let status: Int
    let statusVerbose: String?
    let product: OpenFoodFactsProduct?

    enum CodingKeys: String, CodingKey {
        case status
        case statusVerbose = "status_verbose"
        case product
    }
}

final class OpenFoodFactsService {
    static let shared = OpenFoodFactsService()

    private init() {}
    private let decoder = JSONDecoder()

    func lookup(barcode: String) async throws -> LookupResultItem? {
        let trimmed = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(trimmed).json") else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let msg = HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw NSError(domain: "OpenFoodFacts", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
        }

        let payload = try decoder.decode(OpenFoodFactsLookupResponse.self, from: data)
        guard payload.status == 1, let product = payload.product else {
            return nil
        }

        let brand = product.brands?.split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let nutriments = product.nutriments

        let calories = Int(round(nutriments?.energyKcal100g ?? 0))
        let protein = Int(round(nutriments?.proteins100g ?? 0))
        let carbs = Int(round(nutriments?.carbohydrates100g ?? 0))
        let fat = Int(round(nutriments?.fat100g ?? 0))
        let sugar = Int(round(nutriments?.sugars100g ?? 0))
        let sodium = Int(round((nutriments?.sodium100g ?? 0) * 1000))
        let potassium = Int(round((nutriments?.potassium100g ?? 0) * 1000))

        return LookupResultItem(
            fatSecretId: nil,
            name: product.productName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown product",
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
}
