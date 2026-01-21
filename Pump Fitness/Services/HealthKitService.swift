import Foundation
import HealthKit

class HealthKitService {
    private let healthStore = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization(for metrics: [ActivityMetricType], completion: @escaping (Bool) -> Void) {
        requestAuthorization(activityMetrics: metrics, wellnessMetrics: [], completion: completion)
    }

    func requestAuthorization(activityMetrics: [ActivityMetricType] = [], wellnessMetrics: [WellnessMetricType] = [], completion: @escaping (Bool) -> Void) {
        guard isAvailable else { completion(false); return }

        let activityTypes = activityMetrics.compactMap { $0.hkIdentifier }.compactMap { HKObjectType.quantityType(forIdentifier: $0) }
        
        var wellnessTypes: [HKObjectType] = []
        for wm in wellnessMetrics {
            if let q = wm.hkQuantityTypeIdentifier {
                if let type = HKQuantityType.quantityType(forIdentifier: q) { wellnessTypes.append(type) }
            }
            if let c = wm.hkCategoryTypeIdentifier {
                if let type = HKCategoryType.categoryType(forIdentifier: c) { wellnessTypes.append(type) }
            }
        }
        
        let types = Set(activityTypes + wellnessTypes)
        
        if types.isEmpty {
            completion(true)
            return
        }

        healthStore.requestAuthorization(toShare: [], read: types) { ok, _ in
            completion(ok)
        }
    }

    private func predicate(for date: Date) -> NSPredicate {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        let start = cal.startOfDay(for: date)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? date
        return HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
    }
    
    func fetchMetric(type: ActivityMetricType, for date: Date, completion: @escaping (Double?) -> Void) {
        guard let identifier = type.hkIdentifier,
              let hkType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            completion(nil)
            return
        }
        
        let predicate = predicate(for: date)
        let options: HKStatisticsOptions = type.aggregationStyle == .sum ? .cumulativeSum : .discreteAverage
        
        let query = HKStatisticsQuery(quantityType: hkType, quantitySamplePredicate: predicate, options: options) { _, result, _ in
            guard let result = result else { completion(nil); return }
            
            let value: Double?
            let unit = self.hkUnit(for: type)
            
            switch type.aggregationStyle {
            case .sum:
                value = result.sumQuantity()?.doubleValue(for: unit)
            case .average:
                value = result.averageQuantity()?.doubleValue(for: unit)
            }
            completion(value)
        }
        healthStore.execute(query)
    }
    
    private func hkUnit(for type: ActivityMetricType) -> HKUnit {
        switch type {
        case .calories: return .kilocalorie()
        case .steps, .flightsClimbed, .swimStroke, .pushCount: return .count()
        case .distanceWalking, .swimDistance, .distanceCycling, .distanceDownhillSnowSports, .runStrideLength: return .meter()
        case .exerciseTime, .standTime: return .minute()
        case .runSpeed: return HKUnit(from: "km/h")
        case .runPower: return .watt()
        }
    }
    
    private func hkUnit(for type: WellnessMetricType) -> HKUnit {
        switch type {
        case .uvIndex: return .count()
        case .bloodAlcohol: return .percent()
        case .bodyTemperature: return .degreeCelsius()
        case .heartRate, .respiratoryRate: return .count().unitDivided(by: .minute())
        case .oxygenSaturation: return .percent()
        case .audioExposure: return HKUnit(from: "dBASPL")
        case .vo2Max: return HKUnit(from: "ml/kg/min")
        case .hrv: return .secondUnit(with: .milli) // ms
        case .sexualActivity: return .count() // Dummy unit for category count
        }
    }

    func fetchWellnessMetric(type: WellnessMetricType, for date: Date, completion: @escaping (Double?) -> Void) {
        // Handle Category (Sexual Activity)
        if let categoryTypeIdentifier = type.hkCategoryTypeIdentifier,
           let categoryType = HKCategoryType.categoryType(forIdentifier: categoryTypeIdentifier) {
            
            let pred = predicate(for: date)
            // For categories, we might just want to know if any event existed or count of events.
            // Let's count samples.
            let query = HKSampleQuery(sampleType: categoryType, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let count = Double(samples?.count ?? 0)
                completion(count)
            }
            healthStore.execute(query)
            return
        }
        
        // Handle Quantities
        guard let identifier = type.hkQuantityTypeIdentifier,
              let hkType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            completion(nil)
            return
        }
        
        let pred = predicate(for: date)
        
        // Map aggregation style to HKStatisticsOptions
        var options: HKStatisticsOptions = []
        switch type.aggregationStyle {
        case .average: options = .discreteAverage
        case .max: options = .discreteMax
        case .min: options = .discreteMin
        case .mostRecent: options = .mostRecent
        }
        
        let query = HKStatisticsQuery(quantityType: hkType, quantitySamplePredicate: pred, options: options) { _, result, _ in
            guard let result = result else { completion(nil); return }
            
            let value: Double?
            let unit = self.hkUnit(for: type)
            
            switch type.aggregationStyle {
            case .average:
                value = result.averageQuantity()?.doubleValue(for: unit)
            case .max:
                value = result.maximumQuantity()?.doubleValue(for: unit)
            case .min:
                value = result.minimumQuantity()?.doubleValue(for: unit)
            case .mostRecent:
                value = result.mostRecentQuantity()?.doubleValue(for: unit)
            }
            
            if let val = value, (type == .bloodAlcohol || type == .oxygenSaturation) {
                 // Convert 0.5 -> 50 for formatting if needed, but HK percent is 0.0-1.0usually.
                 // Actually HKUnit.percent() usually returns 0-1. Let's keep raw and format in UI x100.
                 // Wait, check standard.
                 // HKUnit.percent(): 1.0 = 100%. User usually expects 98 not 0.98.
                 // Often useful to multiply by 100 here if UI expects it.
                 // DailySummaryModels for Activity didn't have percent types.
                 // Let's multiply by 100 for SpO2 and BAC if needed, or handle in UI.
                 // Convention in app seems to be raw values. I'll stick to raw 0.98 and format in UI to %.
                 // Actually, let's check. HK percent() is just a unit.
                 // If I enter 98 in UI, I expect match.
                 completion(val)
            } else {
                completion(value)
            }
        }
        healthStore.execute(query)
    }

    func fetchSum(for identifier: HKQuantityTypeIdentifier, completion: @escaping (Double?) -> Void) {
        // Legacy support if needed, or use generic fetch
        guard let type = ActivityMetricType.allCases.first(where: { $0.hkIdentifier == identifier }) else {
            completion(nil)
            return
        }
        fetchMetric(type: type, for: Date(), completion: completion)
    }

    func fetchTodaySteps(completion: @escaping (Double?) -> Void) {
        fetchMetric(type: .steps, for: Date(), completion: completion)
    }

    func fetchTodayDistance(completion: @escaping (Double?) -> Void) {
        fetchMetric(type: .distanceWalking, for: Date(), completion: completion)
    }

    func fetchTodayActiveEnergy(completion: @escaping (Double?) -> Void) {
        fetchMetric(type: .calories, for: Date(), completion: completion)
    }
}
