import Foundation
import UserNotifications

struct NotificationsHelper {
    static func removeDailyTaskNotifications() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let toRemove = requests.map { $0.identifier }.filter { $0.hasPrefix("dailyTask.") }
            if !toRemove.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: toRemove)
            }
        }
    }

    static func removeFastingNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["fasting.end", "fasting.end.immediate"])
    }

    static func removeMealNotifications() {
        let center = UNUserNotificationCenter.current()
        let allIdentifiers = MealType.allCases.map { "mealReminder.\($0.rawValue)" }
        center.removePendingNotificationRequests(withIdentifiers: allIdentifiers)
    }

    static func scheduleMealNotifications(_ reminders: [MealReminder]) {
        let center = UNUserNotificationCenter.current()

        let allIdentifiers = MealType.allCases.map { "mealReminder.\($0.rawValue)" }
        if reminders.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: allIdentifiers)
            return
        }

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("NotificationsHelper: notification permission error: \(error)")
            }
            guard granted else {
                print("NotificationsHelper: notification permission not granted for meal reminders")
                return
            }

            center.getNotificationSettings { settings in
                guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                    print("NotificationsHelper: notification settings not authorized")
                    return
                }

                for reminder in reminders {
                    let identifier = "mealReminder.\(reminder.mealType.rawValue)"
                    center.removePendingNotificationRequests(withIdentifiers: [identifier])

                    var components = DateComponents()
                    components.hour = reminder.hour
                    components.minute = reminder.minute

                    let content = UNMutableNotificationContent()
                    content.title = "\(reminder.mealType.displayName) Reminder"
                    content.body = "Don't forget to log your \(reminder.mealType.displayName.lowercased())!"
                    content.sound = .default

                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                    let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                    center.add(request) { error in
                        if let error = error {
                            print("NotificationsHelper: failed to schedule \(identifier) notification: \(error)")
                        }
                    }
                }
            }
        }
    }

    static func scheduleDailyTaskNotifications(_ definitions: [DailyTaskDefinition], completedTaskIds: Set<String> = [], silenceCompleted: Bool = false) {
        let center = UNUserNotificationCenter.current()

        // Remove any existing dailyTask.* pending requests first
        center.getPendingNotificationRequests { requests in
            let toRemove = requests.map { $0.identifier }.filter { $0.hasPrefix("dailyTask.") }
            if !toRemove.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: toRemove)
            }

            guard !definitions.isEmpty else { return }

            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error = error {
                    print("NotificationsHelper: notification permission error: \(error)")
                }
                guard granted else {
                    print("NotificationsHelper: notification permission not granted for daily tasks")
                    return
                }

                center.getNotificationSettings { settings in
                    guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                        print("NotificationsHelper: notification settings not authorized")
                        return
                    }

                    let calendar = Calendar.current
                    let now = Date()
                    let todayWeekday = calendar.component(.weekday, from: now) // 1-7

                    for def in definitions {
                        let parts = def.time.split(separator: ":").map { Int($0) ?? 0 }
                        guard parts.count >= 2 else { continue }
                        let hour = parts[0]
                        let minute = parts[1]

                        let content = UNMutableNotificationContent()
                        content.title = def.name
                        content.body = "Reminder: \(def.name)"
                        content.sound = .default

                        if def.repeats {
                            // Schedule 7 weekly notifications to allow silencing specific days
                            for weekday in 1...7 {
                                // If silenceCompleted is true, and item is completed, and this is today's weekday -> Skip
                                if silenceCompleted && completedTaskIds.contains(def.id) && weekday == todayWeekday {
                                    continue
                                }

                                var components = DateComponents()
                                components.hour = hour
                                components.minute = minute
                                components.weekday = weekday
                                
                                let identifier = "dailyTask.\(def.id).wd\(weekday)"
                                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                                center.add(request) { err in
                                    if let err = err { print("NotificationsHelper: failed to schedule \(identifier): \(err)") }
                                }
                            }
                        } else {
                            let identifier = "dailyTask.\(def.id)"
                            // ensure any previous request for this id is removed
                            center.removePendingNotificationRequests(withIdentifiers: [identifier])
                            
                            if silenceCompleted && completedTaskIds.contains(def.id) {
                                continue
                            }

                            var components = calendar.dateComponents([.year, .month, .day], from: now)
                            components.hour = hour
                            components.minute = minute
                            var scheduledDate = calendar.date(from: components) ?? now
                            if scheduledDate <= now {
                                scheduledDate = calendar.date(byAdding: .day, value: 1, to: scheduledDate) ?? scheduledDate
                            }
                            let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: scheduledDate)
                            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
                            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                            center.add(request) { err in
                                if let err = err { print("NotificationsHelper: failed to schedule \(identifier): \(err)") }
                            }
                        }
                    }
                }
            }
        }
    }

    static func removeWeeklyProgressNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["weekly-progress-photo-reminder"])
    }

    static func scheduleActivityTimerNotification(id: String, name: String, endDate: Date) {
        let center = UNUserNotificationCenter.current()
        
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            guard granted else { return }
            
            let content = UNMutableNotificationContent()
            content.title = "\(name) Complete"
            content.body = "Your \(name) timer has finished!"
            content.sound = .default
            
            let interval = endDate.timeIntervalSinceNow
            guard interval > 0 else { return }
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let request = UNNotificationRequest(identifier: "activityTimer.\(id)", content: content, trigger: trigger)
            
            center.add(request)
        }
    }

    static func removeActivityTimerNotification(id: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["activityTimer.\(id)"])
    }

    static func scheduleHabitNotifications(_ habits: [HabitDefinition], completedHabitIds: Set<UUID> = []) {
        let center = UNUserNotificationCenter.current()
        
        // Remove any existing habit notifications
        center.getPendingNotificationRequests { requests in
            let toRemove = requests.map { $0.identifier }.filter { $0.hasPrefix("habit.daily.") }
            if !toRemove.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: toRemove)
            }
            
            guard !habits.isEmpty else { return }
            
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                guard granted else { return }
                
                center.getNotificationSettings { settings in
                    guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
                    
                    let calendar = Calendar.current
                    let now = Date()
                    let todayWeekday = calendar.component(.weekday, from: now) // 1-7
                    
                    // Schedule for each day of the week
                    for weekday in 1...7 {
                        var remainingHabits = habits
                        
                        // If scheduling for today, filter out completed habits
                        if weekday == todayWeekday {
                            remainingHabits = habits.filter { !completedHabitIds.contains($0.id) }
                        }
                        
                        // If no habits remaining for this day (e.g. all completed today), skip scheduling
                        if remainingHabits.isEmpty {
                            continue
                        }
                        
                        let habitNames = remainingHabits.map { $0.name }.joined(separator: ", ")
                        
                        let content = UNMutableNotificationContent()
                        content.title = "Daily Habits"
                        content.body = "Don't forget: \(habitNames)"
                        content.sound = .default
                        
                        var components = DateComponents()
                        components.hour = 9
                        components.minute = 0
                        components.weekday = weekday
                        
                        let identifier = "habit.daily.wd\(weekday)"
                        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                        
                        center.add(request) { error in
                            if let error = error {
                                print("NotificationsHelper: failed to schedule \(identifier): \(error)")
                            }
                        }
                    }
                }
            }
        }
    }

    static func removeHabitNotifications() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let toRemove = requests.map { $0.identifier }.filter { $0.hasPrefix("habit.daily.") }
            if !toRemove.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: toRemove)
            }
        }
    }

    static func scheduleTimeTrackingNotification(id: String, title: String, body: String, endDate: Date) {
        let center = UNUserNotificationCenter.current()
        
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            guard granted else { return }
            
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            
            let interval = endDate.timeIntervalSinceNow
            guard interval > 0 else { return }
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let request = UNNotificationRequest(identifier: "timeTracking.\(id)", content: content, trigger: trigger)
            
            center.add(request)
        }
    }

    static func removeTimeTrackingNotification(id: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["timeTracking.\(id)"])
    }

    static func scheduleDailyCheckInNotifications(autoRestIndices: Set<Int>, completedIndices: Set<Int>) {
        let center = UNUserNotificationCenter.current()
        
        // Remove existing check-in notifications
        center.getPendingNotificationRequests { requests in
            let toRemove = requests.map { $0.identifier }.filter { $0.hasPrefix("dailyCheckIn.") }
            if !toRemove.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: toRemove)
            }
            
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                guard granted else { return }
                
                center.getNotificationSettings { settings in
                    guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
                    
                    let calendar = Calendar.current
                    let now = Date()
                    let todayWeekday = calendar.component(.weekday, from: now) // 1-7
                    
                    // Iterate 0-6 (Mon-Sun)
                    for index in 0..<7 {
                        // Skip if auto-rest day
                        if autoRestIndices.contains(index) {
                            continue
                        }
                        
                        // Map index to weekday (0=Mon -> 2, ..., 6=Sun -> 1)
                        // Formula: (index + 1) % 7 + 1
                        // 0 -> 2 (Mon)
                        // 5 -> 7 (Sat)
                        // 6 -> 1 (Sun)
                        let weekday = (index + 1) % 7 + 1
                        
                        // If completed/rested manually AND it's today, skip scheduling
                        if completedIndices.contains(index) && weekday == todayWeekday {
                            continue
                        }
                        
                        let content = UNMutableNotificationContent()
                        content.title = "Daily Check-In"
                        content.body = "Time to check in! How was your day?"
                        content.sound = .default
                        
                        var components = DateComponents()
                        components.hour = 18 // 6 PM
                        components.minute = 0
                        components.weekday = weekday
                        
                        let identifier = "dailyCheckIn.wd\(weekday)"
                        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                        
                        center.add(request) { error in
                            if let error = error {
                                print("NotificationsHelper: failed to schedule \(identifier): \(error)")
                            }
                        }
                    }
                }
            }
        }
    }

    static func removeDailyCheckInNotifications() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let toRemove = requests.map { $0.identifier }.filter { $0.hasPrefix("dailyCheckIn.") }
            if !toRemove.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: toRemove)
            }
        }
    }
}
