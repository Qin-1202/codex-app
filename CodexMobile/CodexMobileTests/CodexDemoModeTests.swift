// FILE: CodexDemoModeTests.swift
// Purpose: Verifies UI demo mode seeds local state without live relay identifiers.
// Layer: Unit Test
// Exports: CodexDemoModeTests
// Depends on: XCTest, CodexMobile

import XCTest
@testable import CodexMobile

@MainActor
final class CodexDemoModeTests: XCTestCase {
    private static var retainedServices: [CodexService] = []

    func testApplyDemoSeedPopulatesLocalUIStateWithoutRelaySecrets() {
        let service = makeService()

        service.applyDemoSeed(now: Date(timeIntervalSince1970: 1_800_000_000))

        XCTAssertTrue(service.isDemoModeEnabled)
        XCTAssertTrue(service.isConnected)
        XCTAssertTrue(service.isInitialized)
        XCTAssertFalse(service.isConnecting)
        XCTAssertFalse(service.isLoadingThreads)
        XCTAssertGreaterThanOrEqual(service.threads.count, 3)
        XCTAssertEqual(service.activeThreadId, CodexDemoSeed.primaryThreadID)
        XCTAssertFalse(service.availableModels.isEmpty)
        XCTAssertEqual(service.selectedModelId, "gpt-5.5")
        XCTAssertEqual(service.selectedReasoningEffort, "medium")
        XCTAssertNil(service.relaySessionId)
        XCTAssertNil(service.relayUrl)
        XCTAssertNil(service.relayMacDeviceId)
        XCTAssertNil(service.relayMacIdentityPublicKey)
        XCTAssertFalse(service.messagesByThread[CodexDemoSeed.primaryThreadID, default: []].isEmpty)
    }

    func testAppendDemoTurnAddsConfirmedUserAndAssistantRows() {
        let service = makeService()
        service.applyDemoSeed(now: Date(timeIntervalSince1970: 1_800_000_000))
        let beforeCount = service.messagesByThread[CodexDemoSeed.primaryThreadID, default: []].count

        service.appendDemoTurn(
            userInput: "Show the local UI demo response.",
            threadId: CodexDemoSeed.primaryThreadID
        )

        let messages = service.messagesByThread[CodexDemoSeed.primaryThreadID, default: []]
        XCTAssertGreaterThan(messages.count, beforeCount)
        XCTAssertEqual(Array(messages.suffix(2)).map(\CodexMessage.role), [.user, .assistant])
        XCTAssertEqual(messages.suffix(2).first?.deliveryState, .confirmed)
        XCTAssertTrue(messages.last?.text.localizedCaseInsensitiveContains("demo") == true)
        XCTAssertEqual(service.threads.first?.id, CodexDemoSeed.primaryThreadID)
        XCTAssertTrue(service.threads.first?.preview?.contains("Show the local UI demo response.") == true)
    }

    func testStartDemoThreadCreatesLocalThreadAndMessageList() {
        let service = makeService()
        service.applyDemoSeed(now: Date(timeIntervalSince1970: 1_800_000_000))

        let thread = service.startDemoThread(preferredProjectPath: "~/Projects/codex-app")

        XCTAssertEqual(service.activeThreadId, thread.id)
        XCTAssertEqual(service.threads.first?.id, thread.id)
        XCTAssertEqual(thread.cwd, "~/Projects/codex-app")
        XCTAssertFalse(service.messagesByThread[thread.id, default: []].isEmpty)
    }

    func testPreparePersistentUIStateMarksOnboardingSeen() {
        let suiteName = "CodexDemoModeTests.onboarding.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)

        AppDemoMode.preparePersistentUIState(defaults: defaults)

        XCTAssertTrue(defaults.bool(forKey: AppDemoMode.hasSeenOnboardingDefaultsKey))
    }

    private func makeService() -> CodexService {
        let suiteName = "CodexDemoModeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        let service = CodexService(defaults: defaults)
        Self.retainedServices.append(service)
        return service
    }
}
