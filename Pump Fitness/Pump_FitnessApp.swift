//
//  Pump_FitnessApp.swift
//  Trackerio
//
//  Created by Kyle Graham on 30/11/2025.
//

import SwiftUI
import SwiftData
import FirebaseCore
#if canImport(TipKit)
import TipKit
#endif

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }
}

@main
struct Pump_FitnessApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var themeManager: ThemeManager
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    private let modelContainer: ModelContainer

    init() {
        FirebaseApp.configure()
        _ = NetworkHelper.shared // Start network monitoring
        
        #if canImport(TipKit)
        if #available(iOS 17.4, *) {
            // try? Tips.resetDatastore()
            do {
                try Tips.configure([
                    .displayFrequency(.immediate),
                    .datastoreLocation(.applicationDefault)
                ])
            } catch {
                // Avoid crashing on unexpected TipKit failures
                print("TipKit configure failed: \(error)")
            }
        }
        #endif
        
        UserDefaults.standard.register(defaults: [
            ThemeManager.defaultsKey: AppTheme.multiColour.rawValue
        ])
        _themeManager = StateObject(wrappedValue: ThemeManager())
        do {
            // Use a single store for all models to ensure consistent context and avoid 'Day' entity missing errors.
            // Lightweight migration will handle adding 'Day' to the existing 'default.store'.
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let storeURL = documentsURL.appendingPathComponent("default.store")

            let schema = Schema([Account.self, Day.self])
            let config = ModelConfiguration(schema: schema, url: storeURL)

            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(themeManager)
                .environmentObject(subscriptionManager)
                .modelContainer(modelContainer)
                .onAppear {
                    PhotoBackupService.shared.startBackup()
                }
        }
    }
}

