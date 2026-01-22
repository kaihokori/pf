//
//  FeatureFlags.swift
//  Trackerio
//
//  Created by Kyle Graham on 22/1/2026.
//

import Foundation

struct FeatureFlags {
    /// Toggle to enable the new Background Resource Upload Extension (PhotoKit).
    /// If false, the app should rely on the classic in-app upload mechanism.
    static let useBackgroundUpload = true
}
