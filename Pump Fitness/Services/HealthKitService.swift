import Foundation
import HealthKit

class HealthKitService {
    private let healthStore = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard isAvailable else { completion(false); return }

        let types: Set = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]

        healthStore.requestAuthorization(toShare: [], read: types) { ok, _ in
            completion(ok)
        }
    }

    private func todayPredicate() -> NSPredicate {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        let start = cal.startOfDay(for: Date())
        return HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
    }

    func fetchSum(for identifier: HKQuantityTypeIdentifier, completion: @escaping (Double?) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { completion(nil); return }

        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: todayPredicate(), options: .cumulativeSum) { _, result, _ in
            guard let result = result, let sum = result.sumQuantity() else { completion(nil); return }
            let unit: HKUnit
            switch identifier {
            case .stepCount:
                unit = HKUnit.count()
            case .distanceWalkingRunning:
                unit = HKUnit.meter()
            case .activeEnergyBurned:
                unit = HKUnit.kilocalorie()
            default:
                unit = HKUnit.count()
            }
            let value = sum.doubleValue(for: unit)
            completion(value)
        }
        healthStore.execute(query)
    }

    func fetchTodaySteps(completion: @escaping (Double?) -> Void) {
        fetchSum(for: .stepCount, completion: completion)
    }

    func fetchTodayDistance(completion: @escaping (Double?) -> Void) {
        fetchSum(for: .distanceWalkingRunning, completion: completion)
    }

    func fetchTodayActiveEnergy(completion: @escaping (Double?) -> Void) {
        fetchSum(for: .activeEnergyBurned, completion: completion)
    }
}
