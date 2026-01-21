import Foundation
import SwiftUI
import HealthKit

enum WellnessMetricType: String, CaseIterable, Codable, Identifiable, Sendable {
    case uvIndex
    case bloodAlcohol
    case bodyTemperature
    case heartRate
    case oxygenSaturation
    case sexualActivity
    case audioExposure
    case vo2Max
    case hrv
    case respiratoryRate

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .uvIndex: return "UV Index"
        case .bloodAlcohol: return "Blood Alcohol"
        case .bodyTemperature: return "Body Temperature"
        case .heartRate: return "Heart Rate"
        case .oxygenSaturation: return "SpO₂ Saturation"
        case .sexualActivity: return "Sexual Activity"
        case .audioExposure: return "Audio Exposure"
        case .vo2Max: return "VO₂ Max"
        case .hrv: return "Heart Rate Variability"
        case .respiratoryRate: return "Respiratory Rate"
        }
    }
    
    var systemImage: String {
        switch self {
        case .uvIndex: return "sun.max.fill"
        case .bloodAlcohol: return "drop.triangle.fill"
        case .bodyTemperature: return "thermometer"
        case .heartRate: return "heart.fill"
        case .oxygenSaturation: return "lungs.fill"
        case .sexualActivity: return "figure.2.circle"
        case .audioExposure: return "ear.fill"
        case .vo2Max: return "figure.run"
        case .hrv: return "waveform.path.ecg"
        case .respiratoryRate: return "lungs"
        }
    }
    
    var unit: String {
        switch self {
        case .uvIndex: return "index"
        case .bloodAlcohol: return "%"
        case .bodyTemperature: return "°C"
        case .heartRate: return "bpm"
        case .oxygenSaturation: return "%"
        case .sexualActivity: return "events"
        case .audioExposure: return "dBASPL"
        case .vo2Max: return "ml/kg/min"
        case .hrv: return "ms"
        case .respiratoryRate: return "brpm"
        }
    }
    
    // Note: Sexual Activity is a Category, not a Quantity. Logic in HealthKitService must handle this.
    var hkQuantityTypeIdentifier: HKQuantityTypeIdentifier? {
        switch self {
        case .uvIndex: return .uvExposure
        case .bloodAlcohol: return .bloodAlcoholContent
        case .bodyTemperature: return .bodyTemperature
        case .heartRate: return .heartRate
        case .oxygenSaturation: return .oxygenSaturation
        case .audioExposure: return .environmentalAudioExposure // or headphoneAudioExposure? Environmental usually makes more sense for "exposure".
        case .vo2Max: return .vo2Max
        case .hrv: return .heartRateVariabilitySDNN
        case .respiratoryRate: return .respiratoryRate
        case .sexualActivity: return nil
        }
    }
    
    var hkCategoryTypeIdentifier: HKCategoryTypeIdentifier? {
        switch self {
        case .sexualActivity: return .sexualActivity
        default: return nil
        }
    }
    
    // For quantities
    enum AggregationStyle: Sendable, Equatable {
        case average
        case max
        case min
        case mostRecent
    }
    
    var aggregationStyle: AggregationStyle {
        switch self {
        case .uvIndex: return .max
        case .bloodAlcohol: return .max
        case .bodyTemperature: return .average
        case .heartRate: return .average
        case .oxygenSaturation: return .average
        case .audioExposure: return .average
        case .vo2Max: return .mostRecent
        case .hrv: return .average
        case .respiratoryRate: return .average
        case .sexualActivity: return .max // Not applicable really, count of events
        }
    }
    
    var defaultGoal: Double {
        switch self {
        case .uvIndex: return 3 // Limit?
        case .bloodAlcohol: return 0.05 // Limit?
        case .bodyTemperature: return 37.0
        case .heartRate: return 60 // Resting?
        case .oxygenSaturation: return 98
        case .sexualActivity: return 1
        case .audioExposure: return 80 // Limit
        case .vo2Max: return 45
        case .hrv: return 50
        case .respiratoryRate: return 16
        }
    }
}

struct TrackedWellnessMetric: Codable, Hashable, Identifiable {
    var id: UUID
    var type: WellnessMetricType
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
    
    init(id: UUID = UUID(), type: WellnessMetricType, goal: Double, unit: String? = nil, colorHex: String, value: Double? = nil, manualValue: Double? = nil, healthKitValue: Double? = nil) {
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
              let type = WellnessMetricType(rawValue: typeRaw) else { return nil }
        
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
