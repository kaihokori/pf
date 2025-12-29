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

    struct Input {
        var gender: Gender
        var birthDate: Date
        var heightCm: Double
        var weightKg: Double
        var activityLevel: ActivityLevel
        var macroFocus: MacroFocusOption
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

    static func calculateTargets(for input: Input, referenceDate: Date = Date()) -> Result? {
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
        
        // Calculate Target Calories and Macros based on MacroFocus
        var targetCalories: Double
        var proteinG: Double
        var fatsG: Double
        var carbsG: Double
        
        switch input.macroFocus {
        case .leanCutting:
            // Calories: TDEE - 500
            // Protein: 2.5 x BW
            // Fats: 20%
            // Carbs: Remainder
            targetCalories = tdee - 500
            proteinG = 2.5 * weight
            fatsG = (targetCalories * 0.20) / 9.0
            let remainingCalories = targetCalories - (proteinG * 4) - (fatsG * 9)
            carbsG = max(0, remainingCalories / 4.0)
            
        case .lowCarb:
            // Calories: TDEE - 500
            // Protein: 2.1 x BW
            // Carbs: 10%
            // Fats: Remainder
            targetCalories = tdee - 500
            proteinG = 2.1 * weight
            carbsG = (targetCalories * 0.10) / 4.0
            let remainingCalories = targetCalories - (proteinG * 4) - (carbsG * 4)
            fatsG = max(0, remainingCalories / 9.0)
            
        case .balanced:
            // Calories: TDEE
            // Protein: 2.3 x BW
            // Fats: 30%
            // Carbs: Remainder (Target ~40%)
            targetCalories = tdee
            proteinG = 2.3 * weight
            fatsG = (targetCalories * 0.30) / 9.0
            let remainingCalories = targetCalories - (proteinG * 4) - (fatsG * 9)
            carbsG = max(0, remainingCalories / 4.0)
            
        case .leanBulking:
            // Calories: TDEE + 350
            // Protein: 2.5 x BW
            // Fats: 20%
            // Carbs: Remainder (Target ~50%)
            targetCalories = tdee + 350
            proteinG = 2.5 * weight
            fatsG = (targetCalories * 0.20) / 9.0
            let remainingCalories = targetCalories - (proteinG * 4) - (fatsG * 9)
            carbsG = max(0, remainingCalories / 4.0)
            
        case .custom:
            return nil
        }
        
        // Safety clamps
        targetCalories = max(1200, targetCalories)
        
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
        macroFocus: MacroFocusOption
    ) -> Input? {
                guard let genderOption = genderOption,
                            genderOption != .preferNotSay,
                            macroFocus != .custom,
                            let heightCm = heightInCentimeters(unitSystem: unitSystem, heightValue: heightValue, heightFeet: heightFeet, heightInches: heightInches),
                            let weightKg = weightInKilograms(unitSystem: unitSystem, weightValue: weightValue) else {
                        return nil
                }

        let gender: Gender = (genderOption == .male) ? .male : .female
        let activityLevel = ActivityLevel.fromWorkoutDays(workoutDays)

        return Input(
            gender: gender,
            birthDate: birthDate,
            heightCm: heightCm,
            weightKg: weightKg,
            activityLevel: activityLevel,
            macroFocus: macroFocus
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
