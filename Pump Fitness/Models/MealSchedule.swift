import Foundation

struct MealSession: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var colorHex: String
    var hour: Int
    var minute: Int

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = "",
        hour: Int = 9,
        minute: Int = 0
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.hour = hour
        self.minute = minute
    }

    init?(dictionary: [String: Any]) {
        guard let name = dictionary["name"] as? String else { return nil }
        let idRaw = dictionary["id"] as? String
        let colorHex = dictionary["colorHex"] as? String ?? ""
        let hour = (dictionary["hour"] as? NSNumber)?.intValue ?? 9
        let minute = (dictionary["minute"] as? NSNumber)?.intValue ?? 0
        self.init(
            id: idRaw.flatMap(UUID.init(uuidString:)) ?? UUID(),
            name: name,
            colorHex: colorHex,
            hour: hour,
            minute: minute
        )
    }

    var asDictionary: [String: Any] {
        [
            "id": id.uuidString,
            "name": name,
            "colorHex": colorHex,
            "hour": hour,
            "minute": minute
        ]
    }

    var dateForToday: Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = hour
        comps.minute = minute
        return Calendar.current.date(from: comps) ?? Date()
    }

    var formattedTime: String {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let calendar = Calendar.current
        let date = calendar.date(from: comps) ?? Date()
        let formatter = MealSession.timeFormatter
        return formatter.string(from: date)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
}

struct MealScheduleItem: Identifiable, Codable, Hashable {
    var id: UUID
    var day: String
    var sessions: [MealSession]

    init(id: UUID = UUID(), day: String, sessions: [MealSession]) {
        self.id = id
        self.day = day
        self.sessions = sessions
    }

    init?(dictionary: [String: Any]) {
        guard let day = dictionary["day"] as? String else { return nil }
        let idRaw = dictionary["id"] as? String
        let sessionDicts = dictionary["sessions"] as? [[String: Any]] ?? []
        let sessions = sessionDicts.compactMap { MealSession(dictionary: $0) }
        self.init(
            id: idRaw.flatMap(UUID.init(uuidString:)) ?? UUID(),
            day: day,
            sessions: sessions
        )
    }

    var asDictionary: [String: Any] {
        [
            "id": id.uuidString,
            "day": day,
            "sessions": sessions.map { $0.asDictionary }
        ]
    }

    static var defaults: [MealScheduleItem] {
        let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        return days.map { MealScheduleItem(day: $0, sessions: []) }
    }
}

struct CatalogIngredient: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var quantity: String
    // Legacy nutritional fields retained for backward compatibility
    var calories: Double
    var protein: Double
    var carbs: Double
    var fats: Double
    var macroValues: [String: Double]

    init(
        id: UUID = UUID(),
        name: String,
        quantity: String,
        calories: Double = 0,
        protein: Double = 0,
        carbs: Double = 0,
        fats: Double = 0,
        macroValues: [String: Double] = [:]
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fats = fats
        self.macroValues = macroValues
    }

    init?(dictionary: [String: Any]) {
        guard let name = dictionary["name"] as? String else { return nil }
        let idRaw = dictionary["id"] as? String
        let quantity = dictionary["quantity"] as? String ?? ""
        let calories = (dictionary["calories"] as? NSNumber)?.doubleValue ?? 0
        let protein = (dictionary["protein"] as? NSNumber)?.doubleValue ?? 0
        let carbs = (dictionary["carbs"] as? NSNumber)?.doubleValue ?? 0
        let fats = (dictionary["fats"] as? NSNumber)?.doubleValue ?? 0
        let macroValues = dictionary["macroValues"] as? [String: Double] ?? [:]

        self.init(
            id: idRaw.flatMap(UUID.init(uuidString:)) ?? UUID(),
            name: name,
            quantity: quantity,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fats: fats,
            macroValues: macroValues
        )
    }

    var asDictionary: [String: Any] {
        [
            "id": id.uuidString,
            "name": name,
            "quantity": quantity,
            "calories": calories,
            "protein": protein,
            "carbs": carbs,
            "fats": fats,
            "macroValues": macroValues
        ]
    }
}

struct MethodStep: Identifiable, Codable, Hashable {
    var id: UUID
    var text: String
    var durationMinutes: Int

    init(id: UUID = UUID(), text: String = "", durationMinutes: Int = 0) {
        self.id = id
        self.text = text
        self.durationMinutes = durationMinutes
    }

    init?(dictionary: [String: Any]) {
        guard let text = dictionary["text"] as? String else { return nil }
        let idRaw = dictionary["id"] as? String
        let duration = dictionary["durationMinutes"] as? Int ?? 0

        self.init(id: idRaw.flatMap(UUID.init(uuidString:)) ?? UUID(), text: text, durationMinutes: duration)
    }

    var asDictionary: [String: Any] {
        [
            "id": id.uuidString,
            "text": text,
            "durationMinutes": durationMinutes
        ]
    }

    static func steps(from legacyMethod: String) -> [MethodStep] {
        legacyMethod
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { MethodStep(text: $0) }
    }
}

struct CatalogMeal: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var mealType: MealType
    var colorHex: String
    var ingredients: [CatalogIngredient]
    var calories: Double
    var protein: Double
    var carbs: Double
    var fats: Double
    var macroValues: [String: Double]
    var methodSteps: [MethodStep]
    var method: String
    var notes: String
    var url: String?

    init(
        id: UUID = UUID(),
        name: String,
        mealType: MealType = .snack,
        colorHex: String = "#4A7BD0",
        ingredients: [CatalogIngredient] = [],
        calories: Double = 0,
        protein: Double = 0,
        carbs: Double = 0,
        fats: Double = 0,
        macroValues: [String: Double] = [:],
        methodSteps: [MethodStep] = [],
        method: String = "",
        notes: String = "",
        url: String? = nil
    ) {
        self.id = id
        self.name = name
        self.mealType = mealType
        self.colorHex = colorHex
        self.ingredients = ingredients
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fats = fats
        self.macroValues = macroValues
        self.methodSteps = methodSteps
        self.method = method
        self.notes = notes
        self.url = url
    }

    init?(dictionary: [String: Any]) {
        guard let name = dictionary["name"] as? String else { return nil }
        let idRaw = dictionary["id"] as? String
        let mealTypeRaw = dictionary["mealType"] as? String ?? "snack"
        var mealType = MealType(rawValue: mealTypeRaw)
        if mealType == nil && mealTypeRaw == "other" {
            mealType = .snack
        }
        
        let colorHex = dictionary["colorHex"] as? String ?? ""
        let calories = (dictionary["calories"] as? NSNumber)?.doubleValue
        let protein = (dictionary["protein"] as? NSNumber)?.doubleValue
        let carbs = (dictionary["carbs"] as? NSNumber)?.doubleValue
        let fats = (dictionary["fats"] as? NSNumber)?.doubleValue
        let macroValues = dictionary["macroValues"] as? [String: Double]
        let method = dictionary["method"] as? String ?? ""
        let notes = dictionary["notes"] as? String ?? ""
        let url = dictionary["url"] as? String
        let ingredientDicts = dictionary["ingredients"] as? [[String: Any]] ?? []
        let ingredients = ingredientDicts.compactMap { CatalogIngredient(dictionary: $0) }
        let stepDicts = dictionary["methodSteps"] as? [[String: Any]] ?? []
        let methodSteps = stepDicts.compactMap { MethodStep(dictionary: $0) }
        let resolvedSteps = methodSteps.isEmpty ? MethodStep.steps(from: method) : methodSteps

        // Legacy fallback: derive meal-level calories/macros from ingredients if not provided
        let derivedCalories = calories ?? ingredients.reduce(0) { $0 + $1.calories }
        let derivedProtein = protein ?? ingredients.reduce(0) { $0 + $1.protein }
        let derivedCarbs = carbs ?? ingredients.reduce(0) { $0 + $1.carbs }
        let derivedFats = fats ?? ingredients.reduce(0) { $0 + $1.fats }
        let derivedMacroValues: [String: Double]
        if let macroValues { derivedMacroValues = macroValues } else {
            // Sum any macroValues present on ingredients
            var summed: [String: Double] = [:]
            for ing in ingredients {
                for (key, val) in ing.macroValues {
                    summed[key, default: 0] += val
                }
            }
            derivedMacroValues = summed
        }

        self.init(
            id: idRaw.flatMap(UUID.init(uuidString:)) ?? UUID(),
            name: name,
            mealType: mealType ?? .snack,
            colorHex: colorHex,
            ingredients: ingredients,
            calories: derivedCalories,
            protein: derivedProtein,
            carbs: derivedCarbs,
            fats: derivedFats,
            macroValues: derivedMacroValues,
            methodSteps: resolvedSteps,
            method: method,
            notes: notes,
            url: url
        )
    }

    var asDictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id.uuidString,
            "name": name,
            "mealType": mealType.rawValue,
            "colorHex": colorHex,
            "ingredients": ingredients.map { $0.asDictionary },
            "calories": calories,
            "protein": protein,
            "carbs": carbs,
            "fats": fats,
            "macroValues": macroValues,
            "methodSteps": methodSteps.map { $0.asDictionary },
            "method": methodStringForLegacy,
            "notes": notes
        ]
        if let url { dict["url"] = url }
        return dict
    }

    enum CodingKeys: String, CodingKey {
        case id, name, mealType, colorHex, ingredients, calories, protein, carbs, fats, macroValues, methodSteps, method, notes, url
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        mealType = try container.decode(MealType.self, forKey: .mealType)
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? ""
        ingredients = try container.decode([CatalogIngredient].self, forKey: .ingredients)
        calories = try container.decodeIfPresent(Double.self, forKey: .calories) ?? ingredients.reduce(0) { $0 + $1.calories }
        protein = try container.decodeIfPresent(Double.self, forKey: .protein) ?? ingredients.reduce(0) { $0 + $1.protein }
        carbs = try container.decodeIfPresent(Double.self, forKey: .carbs) ?? ingredients.reduce(0) { $0 + $1.carbs }
        fats = try container.decodeIfPresent(Double.self, forKey: .fats) ?? ingredients.reduce(0) { $0 + $1.fats }
        if let decodedMacroValues = try container.decodeIfPresent([String: Double].self, forKey: .macroValues) {
            macroValues = decodedMacroValues
        } else {
            var summed: [String: Double] = [:]
            for ing in ingredients {
                for (key, val) in ing.macroValues { summed[key, default: 0] += val }
            }
            macroValues = summed
        }
        methodSteps = try container.decodeIfPresent([MethodStep].self, forKey: .methodSteps) ?? []
        method = try container.decode(String.self, forKey: .method)
        if methodSteps.isEmpty && !method.isEmpty {
            methodSteps = MethodStep.steps(from: method)
        }
        notes = try container.decode(String.self, forKey: .notes)
        url = try container.decodeIfPresent(String.self, forKey: .url)
    }

    private var methodStringForLegacy: String {
        if !method.isEmpty { return method }
        guard !methodSteps.isEmpty else { return "" }
        let lines = methodSteps.enumerated().map { idx, step -> String in
            let duration = step.durationMinutes > 0 ? " (\(step.durationMinutes) min)" : ""
            return "\(idx + 1). \(step.text)\(duration)"
        }
        return lines.joined(separator: "\n")
    }
}
