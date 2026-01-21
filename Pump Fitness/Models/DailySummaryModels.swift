import Foundation
import SwiftUI
import HealthKit

enum ActivityMetricType: String, CaseIterable, Codable, Identifiable, Sendable {
    case calories
    case steps
    case distanceWalking
    case exerciseTime
    case standTime
    case flightsClimbed
    case swimDistance
    case swimStroke
    case runSpeed
    case runStrideLength
    case runPower
    case distanceCycling
    case distanceDownhillSnowSports
    case pushCount

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .calories: return "Calories Burned"
        case .steps: return "Steps Taken"
        case .distanceWalking: return "Distance Travelled"
        case .exerciseTime: return "Exercise Time"
        case .standTime: return "Stand Time"
        case .flightsClimbed: return "Flights Climbed"
        case .swimDistance: return "Swim Distance"
        case .swimStroke: return "Swim Strokes"
        case .runSpeed: return "Run Speed"
        case .runStrideLength: return "Run Stride Length"
        case .runPower: return "Run Power"
        case .distanceCycling: return "Distance Cycling"
        case .distanceDownhillSnowSports: return "Distance Downhill"
        case .pushCount: return "Wheelchair Pushes"
        }
    }
    
    var systemImage: String {
        switch self {
        case .calories: return "flame.fill"
        case .steps: return "figure.walk"
        case .distanceWalking: return "point.bottomleft.forward.to.point.topright.filled.scurvepath"
        case .exerciseTime: return "stopwatch.fill"
        case .standTime: return "figure.stand"
        case .flightsClimbed: return "stairs"
        case .swimDistance: return "figure.pool.swim"
        case .swimStroke: return "hand.point.up.left.fill"
        case .runSpeed: return "speedometer"
        case .runStrideLength: return "ruler.fill"
        case .runPower: return "bolt.fill"
        case .distanceCycling: return "bicycle"
        case .distanceDownhillSnowSports: return "figure.skiing.downhill"
        case .pushCount: return "figure.roll"
        }
    }
    
    var unit: String {
        switch self {
        case .calories: return "kcal"
        case .steps: return "steps"
        case .distanceWalking: return "m"
        case .exerciseTime: return "min"
        case .standTime: return "min"
        case .flightsClimbed: return "flights"
        case .swimDistance: return "m"
        case .swimStroke: return "strokes"
        case .runSpeed: return "km/h"
        case .runStrideLength: return "m"
        case .runPower: return "W"
        case .distanceCycling: return "km"
        case .distanceDownhillSnowSports: return "km"
        case .pushCount: return "pushes"
        }
    }
    
    var hkIdentifier: HKQuantityTypeIdentifier? {
        switch self {
        case .calories: return .activeEnergyBurned
        case .steps: return .stepCount
        case .distanceWalking: return .distanceWalkingRunning
        case .exerciseTime: return .appleExerciseTime
        case .standTime: return .appleStandTime
        case .flightsClimbed: return .flightsClimbed
        case .swimDistance: return .distanceSwimming
        case .swimStroke: return .swimmingStrokeCount
        case .runSpeed: return .runningSpeed
        case .runStrideLength: return .runningStrideLength
        case .runPower: return .runningPower
        case .distanceCycling: return .distanceCycling
        case .distanceDownhillSnowSports: return .distanceDownhillSnowSports
        case .pushCount: return .pushCount
        }
    }
    
    enum AggregationStyle: Sendable, Equatable {
        case sum
        case average
    }
    
    var aggregationStyle: AggregationStyle {
        switch self {
        case .calories, .steps, .distanceWalking, .exerciseTime, .standTime, .flightsClimbed, .swimDistance, .swimStroke, .distanceCycling, .distanceDownhillSnowSports, .pushCount:
            return .sum
        case .runSpeed, .runStrideLength, .runPower:
            return .average
        }
    }
    
    var defaultGoal: Double {
        switch self {
        case .calories: return 500
        case .steps: return 10000
        case .distanceWalking: return 3000
        case .exerciseTime: return 30
        case .standTime: return 60
        case .flightsClimbed: return 10
        case .swimDistance: return 500
        case .swimStroke: return 500
        case .runSpeed: return 10
        case .runStrideLength: return 1
        case .runPower: return 200
        case .distanceCycling: return 20
        case .distanceDownhillSnowSports: return 10
        case .pushCount: return 500
        }
    }
}

struct TrackedActivityMetric: Codable, Hashable, Identifiable {
    var id: UUID
    var type: ActivityMetricType
    var goal: Double
    var unit: String
    var colorHex: String
    private var _value: Double?
    
    var manualValue: Double?
    var healthKitValue: Double?
    
    var value: Double? {
        if let m = manualValue, let h = healthKitValue { return m + h }
        if let m = manualValue { return m }
        if let h = healthKitValue { return h }
        return _value
    }
    
    // Manual additions
    // Logic: HK value + manual adjustment = displayed value.
    // The metric tracks the goal. The actual value logic resides in HealthKit integration + persistency of adjustments.
    
    init(id: UUID = UUID(), type: ActivityMetricType, goal: Double, unit: String? = nil, colorHex: String, value: Double? = nil, manualValue: Double? = nil, healthKitValue: Double? = nil) {
        self.id = id
        self.type = type
        self.goal = goal
        self.unit = unit ?? type.unit
        self.colorHex = colorHex
        self._value = value
        self.manualValue = manualValue
        self.healthKitValue = healthKitValue
    }
    
    var color: Color {
        Color(hex: colorHex) ?? .accentColor
    }

    init?(dictionary: [String: Any]) {
        guard let typeRaw = dictionary["type"] as? String,
              let type = ActivityMetricType(rawValue: typeRaw) else { return nil }
        
        let idRaw = dictionary["id"] as? String ?? UUID().uuidString
        self.id = UUID(uuidString: idRaw) ?? UUID()
        self.type = type
        self.goal = (dictionary["goal"] as? NSNumber)?.doubleValue ?? 0
        self.unit = dictionary["unit"] as? String ?? type.unit
        self.colorHex = dictionary["colorHex"] as? String ?? "#FF3B30"
        self._value = (dictionary["value"] as? NSNumber)?.doubleValue ?? dictionary["value"] as? Double
        
        self.manualValue = (dictionary["manualValue"] as? NSNumber)?.doubleValue ?? dictionary["manualValue"] as? Double
        self.healthKitValue = (dictionary["healthKitValue"] as? NSNumber)?.doubleValue ?? dictionary["healthKitValue"] as? Double
    }

    var asDictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id.uuidString,
            "type": type.rawValue,
            "goal": goal,
            "unit": unit,
            "colorHex": colorHex
        ]
        if let value = value {
            dict["value"] = value
        }
        if let manualValue = manualValue {
            dict["manualValue"] = manualValue
        }
        if let healthKitValue = healthKitValue {
            dict["healthKitValue"] = healthKitValue
        }
        return dict
    }
}
