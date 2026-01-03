import Foundation

struct MacroCalculator {
    enum Gender {
        case male
        case female
    }

    enum ActivityLevel: CaseIterable {
        case sedentary
        case light
        case moderate
        case high
        case athlete

        var multiplier: Double {
            switch self {
            case .sedentary: return 1.2
            case .light: return 1.375
            case .moderate: return 1.55
            case .high: return 1.725
            case .athlete: return 1.9
            }
        }

        static func fromWorkoutDays(_ days: Int) -> ActivityLevel {
            switch days {
            case ..<1: return .sedentary
            case 1...2: return .light
            case 3...4: return .moderate
            case 5: return .high
            default: return .athlete
            }
        }

        static func fromAccountActivityLevel(_ raw: String?) -> ActivityLevel? {
            guard let raw else { return nil }
            switch raw {
            case ActivityLevelOption.sedentary.rawValue:
                return .sedentary
            case ActivityLevelOption.lightlyActive.rawValue:
                return .light
            case ActivityLevelOption.moderatelyActive.rawValue:
                return .moderate
            case ActivityLevelOption.veryActive.rawValue:
                return .high
            case ActivityLevelOption.extraActive.rawValue:
                return .athlete
            default:
                return nil
            }
        }
    }

    enum WeightGoalOption: String, CaseIterable, Identifiable {
        case mildWeightLoss
        case mildWeightGain
        case weightLoss
        case weightGain
        case extremeWeightLoss
        case extremeWeightGain
        case maintainWeight
        case custom
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .mildWeightLoss: return "Mild Weight Loss"
            case .mildWeightGain: return "Mild Weight Gain"
            case .weightLoss: return "Weight Loss"
            case .weightGain: return "Weight Gain"
            case .extremeWeightLoss: return "Extreme Weight Loss"
            case .extremeWeightGain: return "Extreme Weight Gain"
            case .maintainWeight: return "Maintain Weight"
            case .custom: return "Custom"
            }
        }
    }

    enum MacroDistributionStrategy: String, CaseIterable, Identifiable {
        case highProtein
        case balanced
        case lowFat
        case lowCarb
        case custom

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .highProtein: return "High Protein"
            case .balanced: return "Balanced"
            case .lowFat: return "Low Fat"
            case .lowCarb: return "Low Carb"
            case .custom: return "Custom"
            }
        }
        
        var description: String {
            switch self {
            case .highProtein: return "Protein 2.5g/kg (min 30%) • Fat 20% • Carbs Remainder"
            case .balanced: return "Protein 25% • Fat 25% • Carbs Remainder"
            case .lowFat: return "Protein 1.6g/kg • Fat 15% • Carbs Remainder"
            case .lowCarb: return "Protein 2.0g/kg • Carbs 10% • Fat Remainder"
            case .custom: return "Manually set your macro targets"
            }
        }
    }

    struct Input {
        var gender: Gender
        var birthDate: Date
        var heightCm: Double
        var weightKg: Double
        var activityLevel: ActivityLevel
        var weightGoal: WeightGoalOption
        var macroStrategy: MacroDistributionStrategy
    }

    struct Result {
        var calories: Int
        var protein: Int
        var carbohydrates: Int
        var fats: Int
        var fibre: Int
        var sodiumMg: Int
        var waterMl: Int
    }

    static func calculateTargets(for input: Input, referenceDate: Date = Date(), overrideCalories: Int? = nil) -> Result? {
        guard let ageYears = age(inYearsAt: referenceDate, birthDate: input.birthDate), (0...120).contains(ageYears) else {
            return nil
        }

        let weight = input.weightKg
        let height = input.heightCm
        guard weight.isFinite, height.isFinite, ageYears.isFinite else {
            return nil
        }

        // Mifflin-St Jeor Formula
        let rmr: Double
        if input.gender == .male {
            rmr = 10 * weight + 6.25 * height - 5 * ageYears + 5
        } else {
            rmr = 10 * weight + 6.25 * height - 5 * ageYears - 161
        }

        guard rmr.isFinite else { return nil }

        let tdee = rmr * input.activityLevel.multiplier
        
        // Calculate Target Calories based on Weight Goal
        var targetCalories: Double
        
        if let override = overrideCalories {
            targetCalories = Double(override)
        } else {
            switch input.weightGoal {
            case .maintainWeight:
                targetCalories = tdee
            case .mildWeightLoss:
                targetCalories = tdee - 250
            case .weightLoss:
                targetCalories = tdee - 500
            case .extremeWeightLoss:
                targetCalories = tdee - 1000
            case .mildWeightGain:
                targetCalories = tdee + 250
            case .weightGain:
                targetCalories = tdee + 500
            case .extremeWeightGain:
                targetCalories = tdee + 1000
            case .custom:
                targetCalories = tdee
            }
        }
        
        // Ensure safe minimum
        targetCalories = max(1200, targetCalories)
        
        var proteinG: Double
        var fatsG: Double
        var carbsG: Double
        
        // Calculate Macros based on Strategy
        switch input.macroStrategy {
        case .highProtein:
            // Protein = 2.5 x BW (or 30% of calories, whichever is higher)
            // Fat = 20%
            // Carbs = remaining calories
            let proteinByWeight = 2.5 * weight
            let proteinByCal = (targetCalories * 0.30) / 4.0
            proteinG = max(proteinByWeight, proteinByCal)
            
            let proteinCal = proteinG * 4.0
            let fatCal = targetCalories * 0.20
            fatsG = fatCal / 9.0
            let remainingCal = targetCalories - proteinCal - fatCal
            carbsG = max(0, remainingCal / 4.0)
            
        case .balanced:
            // Protein = 25%
            // Fat = 25%
            // Carbs = remaining calories
            let proteinCal = targetCalories * 0.25
            proteinG = proteinCal / 4.0
            let fatCal = targetCalories * 0.25
            fatsG = fatCal / 9.0
            let remainingCal = targetCalories - proteinCal - fatCal
            carbsG = max(0, remainingCal / 4.0)
            
        case .lowFat:
            // Protein = 1.6 x BW
            // Fat = 15%
            // Carbs = remaining calories
            proteinG = 1.6 * weight
            let proteinCal = proteinG * 4.0
            let fatCal = targetCalories * 0.15
            fatsG = fatCal / 9.0
            let remainingCal = targetCalories - proteinCal - fatCal
            carbsG = max(0, remainingCal / 4.0)
            
        case .lowCarb:
            // Protein = 2.0 x BW
            // Carbs = 10%
            // Fat = remaining calories
            proteinG = 2.0 * weight
            let proteinCal = proteinG * 4.0
            let carbCal = targetCalories * 0.10
            carbsG = carbCal / 4.0
            let remainingCal = targetCalories - proteinCal - carbCal
            fatsG = max(0, remainingCal / 9.0)
            
        case .custom:
            // Default fallback (Balanced)
            let proteinCal = targetCalories * 0.25
            proteinG = proteinCal / 4.0
            let fatCal = targetCalories * 0.25
            fatsG = fatCal / 9.0
            let remainingCal = targetCalories - proteinCal - fatCal
            carbsG = max(0, remainingCal / 4.0)
        }

        
        // Fibre: 14g per 1000 kcal, clamped 20-40g
        let fibreFromCalories = (targetCalories / 1000) * 14
        let fibreG = clamp(fibreFromCalories, min: 20, max: 40)

        let sodiumMg = 2300
        let waterMl = max(2000, Int(round(weight * 35.0)))

        return Result(
            calories: Int(round(targetCalories)),
            protein: Int(round(proteinG)),
            carbohydrates: Int(round(carbsG)),
            fats: Int(round(fatsG)),
            fibre: Int(round(fibreG)),
            sodiumMg: sodiumMg,
            waterMl: waterMl
        )
    }

    private static func age(inYearsAt referenceDate: Date, birthDate: Date) -> Double? {
        let calendar = Calendar.current
        guard birthDate <= referenceDate else { return nil }
        let components = calendar.dateComponents([.year, .month, .day], from: birthDate, to: referenceDate)
        guard let years = components.year else { return nil }
        var ageYears = Double(years)
        if let months = components.month, let days = components.day {
            let monthFraction = Double(months) / 12.0
            let dayFraction = Double(days) / 365.0
            ageYears += monthFraction + dayFraction
        }
        return ageYears
    }

    private static func clamp(_ value: Double, min minimum: Double, max maximum: Double) -> Double {
        return max(minimum, min(value, maximum))
    }
}

extension MacroCalculator {
    static func makeInput(
        genderOption: GenderOption?,
        birthDate: Date,
        unitSystem: UnitSystem,
        heightValue: String,
        heightFeet: String,
        heightInches: String,
        weightValue: String,
        workoutDays: Int,
        weightGoal: WeightGoalOption,
        macroStrategy: MacroDistributionStrategy,
        activityLevelRaw: String? = nil
    ) -> Input? {
                guard let genderOption = genderOption,
                            genderOption != .preferNotSay,
                            weightGoal != .custom,
                            let heightCm = heightInCentimeters(unitSystem: unitSystem, heightValue: heightValue, heightFeet: heightFeet, heightInches: heightInches),
                            let weightKg = weightInKilograms(unitSystem: unitSystem, weightValue: weightValue) else {
                        return nil
                }

        let gender: Gender = (genderOption == .male) ? .male : .female
        let activityLevel = ActivityLevel.fromAccountActivityLevel(activityLevelRaw) ?? ActivityLevel.fromWorkoutDays(workoutDays)

        return Input(
            gender: gender,
            birthDate: birthDate,
            heightCm: heightCm,
            weightKg: weightKg,
            activityLevel: activityLevel,
            weightGoal: weightGoal,
            macroStrategy: macroStrategy
        )
    }

    static func estimateMaintenanceCalories(
        genderOption: GenderOption?,
        birthDate: Date,
        unitSystem: UnitSystem,
        heightValue: String,
        heightFeet: String,
        heightInches: String,
        weightValue: String,
        workoutDays: Int,
        activityLevelRaw: String? = nil,
        referenceDate: Date = Date()
    ) -> Int? {
        guard let genderOption = genderOption,
              genderOption != .preferNotSay,
              let heightCm = heightInCentimeters(
                  unitSystem: unitSystem,
                  heightValue: heightValue,
                  heightFeet: heightFeet,
                  heightInches: heightInches
              ),
              let weightKg = weightInKilograms(unitSystem: unitSystem, weightValue: weightValue),
              let ageYears = age(inYearsAt: referenceDate, birthDate: birthDate) else {
            return nil
        }

        let gender: Gender = (genderOption == .male) ? .male : .female
        let bmr: Double
        if gender == .male {
            bmr = 10 * weightKg + 6.25 * heightCm - 5 * ageYears + 5
        } else {
            bmr = 10 * weightKg + 6.25 * heightCm - 5 * ageYears - 161
        }

        let activityLevel = ActivityLevel.fromAccountActivityLevel(activityLevelRaw) ?? ActivityLevel.fromWorkoutDays(workoutDays)
        let tdee = bmr * activityLevel.multiplier
        guard tdee.isFinite else { return nil }
        return Int(round(tdee))
    }

    private static func heightInCentimeters(
        unitSystem: UnitSystem,
        heightValue: String,
        heightFeet: String,
        heightInches: String
    ) -> Double? {
        switch unitSystem {
        case .metric:
            guard let cm = Double(heightValue), cm > 0 else { return nil }
            return cm
        case .imperial:
            guard let feet = Double(heightFeet), let inches = Double(heightInches) else { return nil }
            let totalInches = feet * 12 + inches
            guard totalInches > 0 else { return nil }
            return totalInches * 2.54
        }
    }

    private static func weightInKilograms(unitSystem: UnitSystem, weightValue: String) -> Double? {
        guard let value = Double(weightValue), value > 0 else { return nil }
        switch unitSystem {
        case .metric:
            return value
        case .imperial:
            return value / 2.20462
        }
    }
}
