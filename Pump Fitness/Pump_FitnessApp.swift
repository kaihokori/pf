//
//  Pump_FitnessApp.swift
//  Pump Fitness
//
//  Created by Kyle Graham on 30/11/2025.
//

import SwiftUI

@main
struct Pump_FitnessApp: App {
    @StateObject private var themeManager: ThemeManager

    init() {
        UserDefaults.standard.register(defaults: [
            ThemeManager.defaultsKey: AppTheme.multiColour.rawValue
        ])
        _themeManager = StateObject(wrappedValue: ThemeManager())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(themeManager)
        }
    }
}
