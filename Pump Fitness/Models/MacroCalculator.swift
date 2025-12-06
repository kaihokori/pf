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
    }

    struct Input {
        var gender: Gender
        var birthDate: Date
        var heightCm: Double
        var weightKg: Double
        var activityLevel: ActivityLevel
        var goal: GoalOption
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

        let bmr: Double
        if input.gender == .male {
            bmr = 10 * weight + 6.25 * height - 5 * ageYears + 5
        } else {
            bmr = 10 * weight + 6.25 * height - 5 * ageYears - 161
        }

        guard bmr.isFinite else { return nil }

        let tdee = bmr * input.activityLevel.multiplier

        var desiredCalories = tdee
        switch input.goal {
        case .loseFat:
            desiredCalories = tdee * 0.8
        case .gainMuscle:
            desiredCalories = tdee * 1.15
        case .recomposition:
            desiredCalories = tdee * 0.9
        case .maintain:
            desiredCalories = tdee
        }

        let isMale = input.gender == .male
        let hardFloor = isMale ? 1500.0 : 1200.0
        let bmrFloor = bmr * 1.05
        let softFloor = max(hardFloor, bmrFloor, tdee * 0.75)
        let softCeiling = tdee * 1.25
        var calorieTarget = clamp(desiredCalories, min: softFloor, max: softCeiling)
        calorieTarget = round(calorieTarget)

        guard let split = macroSplitStrategy(from: input.macroFocus) else {
            return nil
        }

        let proteinPerKg = split.proteinPerKg
        let fatPerKg = split.fatPerKg

        let proteinMinG = weight * 1.4
        let proteinMaxG = min(weight * 2.4, 220)
        var proteinG = clamp(weight * proteinPerKg, min: proteinMinG, max: proteinMaxG)

        let fatMinG = max(0.6 * weight, 35)
        let fatMaxG = min(1.2 * weight, 120)
        var fatsG = clamp(weight * fatPerKg, min: fatMinG, max: fatMaxG)

        var caloriesFromProtein = proteinG * 4
        var caloriesFromFats = fatsG * 9
        var pfCalories = caloriesFromProtein + caloriesFromFats

        let maxPfRatio = split == .lowCarb ? 0.9 : 0.8
        let maxPfCalories = calorieTarget * maxPfRatio

        if pfCalories > maxPfCalories {
            var extra = pfCalories - maxPfCalories

            var fatCalories = caloriesFromFats
            let fatCalsMin = fatMinG * 9
            let fatReducible = max(0, fatCalories - fatCalsMin)
            let fatReduction = min(extra, fatReducible)
            fatCalories -= fatReduction
            extra -= fatReduction
            fatsG = fatCalories / 9

            var proteinCalories = caloriesFromProtein
            let proteinCalsMin = proteinMinG * 4
            let proteinReducible = max(0, proteinCalories - proteinCalsMin)
            let proteinReduction = min(extra, proteinReducible)
            proteinCalories -= proteinReduction
            extra -= proteinReduction
            proteinG = proteinCalories / 4

            caloriesFromProtein = proteinCalories
            caloriesFromFats = fatCalories
            pfCalories = caloriesFromProtein + caloriesFromFats
        }

        let caloriesForCarbs = max(0, calorieTarget - pfCalories)
        let carbsG = caloriesForCarbs / 4

        let fibreFromCalories = (calorieTarget / 1000) * 14
        let fibreG = clamp(fibreFromCalories, min: 20, max: 40)

        let roundedCalories = Int(round(calorieTarget))
        let roundedProtein = Int(round(proteinG))
        let roundedCarbs = Int(round(carbsG))
        let roundedFats = Int(round(fatsG))
        let roundedFibre = Int(round(fibreG))

        let sodiumMg = 2300
        let waterMl = max(2000, Int(round(weight * 35.0)))

        return Result(
            calories: roundedCalories,
            protein: roundedProtein,
            carbohydrates: roundedCarbs,
            fats: roundedFats,
            fibre: roundedFibre,
            sodiumMg: sodiumMg,
            waterMl: waterMl
        )
    }

    private enum MacroSplitStrategy {
        case highProtein
        case balanced
        case lowCarb

        var proteinPerKg: Double {
            switch self {
            case .highProtein: return 2.0
            case .balanced: return 1.8
            case .lowCarb: return 2.2
            }
        }

        var fatPerKg: Double {
            switch self {
            case .highProtein: return 0.8
            case .balanced: return 0.9
            case .lowCarb: return 1.0
            }
        }
    }

    private static func macroSplitStrategy(from focus: MacroFocusOption) -> MacroSplitStrategy? {
        switch focus {
        case .highProtein: return .highProtein
        case .balanced: return .balanced
        case .lowCarb: return .lowCarb
        case .custom: return nil
        }
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
        goal: GoalOption?,
        macroFocus: MacroFocusOption
    ) -> Input? {
                guard let genderOption = genderOption,
                            genderOption != .preferNotSay,
                            let goal = goal,
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
            goal: goal,
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

        let activityLevel = ActivityLevel.fromWorkoutDays(workoutDays)
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
