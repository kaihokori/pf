import Foundation
import SwiftData

/// Produces a compact JSON snapshot of Account and Day for use as AI context.
struct AssistantContextProvider {
    static func snapshotJSON(context: ModelContext) async -> String {
        var out: [String: Any] = [:]

        // Fetch Account
        do {
            let req = FetchDescriptor<Account>()
            if let acct = try context.fetch(req).first {
                var acctDict: [String: Any] = [:]
                acctDict["id"] = acct.id
                acctDict["name"] = acct.name ?? NSNull()
                if let dob = acct.dateOfBirth { acctDict["dateOfBirth"] = iso8601String(from: dob) }
                acctDict["weight"] = acct.weight as Any
                acctDict["height"] = acct.height as Any
                acctDict["calorieGoal"] = acct.calorieGoal
                acctDict["maintenanceCalories"] = acct.maintenanceCalories
                acctDict["trackedMacros"] = acct.trackedMacros.map { $0.asDictionary }
                acctDict["dailyTasks"] = acct.dailyTasks.map { $0.asDictionary }
                acctDict["mealSchedule"] = acct.mealSchedule.map { $0.asDictionary }
                acctDict["goals"] = acct.goals.map { (item: GoalItem) -> [String: Any] in
                    ["id": item.id, "title": item.title]
                }
                out["account"] = acctDict
            }
        } catch {
            // ignore
        }

        // Fetch Day (today)
        do {
            let day = Day.fetchOrCreate(for: Date(), in: context, trackedMacros: nil, soloMetrics: nil, teamMetrics: nil)
            var dayDict: [String: Any] = [:]
            dayDict["id"] = day.id
            dayDict["date"] = iso8601String(from: day.date)
            dayDict["caloriesConsumed"] = day.caloriesConsumed
            dayDict["calorieGoal"] = day.calorieGoal
            dayDict["mealIntakes"] = day.mealIntakes.map { $0.asDictionary }
            dayDict["soloMetricValues"] = day.soloMetricValues.map { $0.asDictionary }
            dayDict["stepsTaken"] = day.stepsTaken
            dayDict["distanceTravelled"] = day.distanceTravelled
            dayDict["weightEntries"] = day.weightEntries.map { $0.asDictionary }
            out["day"] = dayDict
        } catch {
            // ignore
        }

        // Encode to JSON string
        if JSONSerialization.isValidJSONObject(out) {
            if let data = try? JSONSerialization.data(withJSONObject: out, options: []) {
                return String(data: data, encoding: .utf8) ?? "{}"
            }
        }
        return "{}"
    }

    static func iso8601String(from date: Date) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fmt.string(from: date)
    }
}
