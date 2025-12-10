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
            modelContainer = try ModelContainer(for: Account.self)
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
