// FILE: AppDemoMode.swift
// Purpose: Central switch and launch persistence for the open-source UI demo.
// Layer: Service
// Exports: AppDemoMode
// Depends on: Foundation

import Foundation

enum AppDemoMode {
    static let isEnabled = true
    static let hasSeenOnboardingDefaultsKey = "codex.hasSeenOnboarding"

    static func preparePersistentUIState(defaults: UserDefaults = .standard) {
        guard isEnabled else { return }

        defaults.set(true, forKey: hasSeenOnboardingDefaultsKey)
    }
}
