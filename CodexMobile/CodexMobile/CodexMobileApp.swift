// FILE: CodexMobileApp.swift
// Purpose: App entry point, RevenueCat setup, and root dependency wiring.
// Layer: App
// Exports: CodexMobileApp

import RevenueCat
import SwiftUI

@MainActor
@main
struct CodexMobileApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @UIApplicationDelegateAdaptor(CodexMobileAppDelegate.self) private var appDelegate
    @AppStorage(AppLanguage.storageKey) private var appLanguageRawValue = AppLanguage.defaultLanguage.rawValue
    @State private var codexService: CodexService
    @State private var petCompanionStore: PetCompanionStore
    @State private var petCompanionStatusStore: PetCompanionStatusStore
    @State private var subscriptionService: SubscriptionService

    init() {
        if AppDemoMode.isEnabled {
            AppDemoMode.preparePersistentUIState()
        } else {
            Self.configureRevenueCatIfAvailable()
        }

        let service = CodexService()
        if AppDemoMode.isEnabled {
            service.applyDemoSeed(language: AppLanguage.stored())
        } else {
            service.configureNotifications()
        }
        let subscriptionService = SubscriptionService()
        if AppDemoMode.isEnabled {
            subscriptionService.applyDemoAccess()
        }

        _codexService = State(initialValue: service)
        _petCompanionStore = State(initialValue: PetCompanionStore())
        _petCompanionStatusStore = State(initialValue: PetCompanionStatusStore())
        _subscriptionService = State(initialValue: subscriptionService)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(codexService)
                .environment(petCompanionStore)
                .environment(petCompanionStatusStore)
                .environment(subscriptionService)
                .environment(\.locale, appLanguage.locale)
                .task {
                    guard !AppDemoMode.isEnabled else { return }
                    await subscriptionService.bootstrap()
                }
                .onOpenURL { url in
                    Task { @MainActor in
                        guard CodexService.legacyGPTLoginCallbackEnabled else {
                            return
                        }
                        await codexService.handleGPTLoginCallbackURL(url)
                    }
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: UIApplication.didReceiveMemoryWarningNotification
                    )
                ) { _ in
                    TurnCacheManager.resetAll()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .background else { return }
                    TurnCacheManager.resetAll()
                }
                .onChange(of: appLanguageRawValue) { _, rawValue in
                    guard AppDemoMode.isEnabled else { return }
                    let language = AppLanguage(rawValue: rawValue) ?? .defaultLanguage
                    codexService.applyDemoLanguage(language)
                }
        }
    }

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRawValue) ?? .defaultLanguage
    }

    // Configures RevenueCat once at launch using the client-safe public SDK key.
    private static func configureRevenueCatIfAvailable() {
        guard let apiKey = AppEnvironment.revenueCatPublicAPIKey else {
            assertionFailure("Missing RevenueCat public API key in Info.plist")
            return
        }

        #if DEBUG
        Purchases.logLevel = .debug
        #endif

        Purchases.configure(withAPIKey: apiKey)
    }
}
