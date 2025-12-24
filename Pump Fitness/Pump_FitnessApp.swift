//
//  Pump_FitnessApp.swift
//  Pump Fitness
//
//  Created by Kyle Graham on 30/11/2025.
//

import SwiftUI
import SwiftData
import FirebaseCore

@main
struct Pump_FitnessApp: App {
    @StateObject private var themeManager: ThemeManager
    private let modelContainer: ModelContainer

    init() {
        FirebaseApp.configure()
        
        UserDefaults.standard.register(defaults: [
            ThemeManager.defaultsKey: AppTheme.multiColour.rawValue
        ])
        _themeManager = StateObject(wrappedValue: ThemeManager())
        do {
            // Use separate stores to avoid migration failures for users who already have an Account-only store.
            // Account continues to use the original default store; Day gets a new store file.
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let dayStoreURL = documentsURL.appendingPathComponent("Day.store")

            let accountSchema = Schema([Account.self])
            let daySchema = Schema([Day.self])

            let accountConfig = ModelConfiguration(schema: accountSchema)
            let dayConfig = ModelConfiguration("day", schema: daySchema, url: dayStoreURL)

            let combinedSchema = Schema([Account.self, Day.self])

            modelContainer = try ModelContainer(
                for: combinedSchema,
                configurations: [accountConfig, dayConfig]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(themeManager)
                .modelContainer(modelContainer)
        }
    }
}

