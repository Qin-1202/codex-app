// FILE: CodexAppLanguageTests.swift
// Purpose: Verifies app language selection and demo-mode localized seed state.
// Layer: Unit Test
// Exports: CodexAppLanguageTests
// Depends on: XCTest, CodexMobile

import XCTest
@testable import CodexMobile

@MainActor
final class CodexAppLanguageTests: XCTestCase {
    private static var retainedServices: [CodexService] = []

    func testStoredLanguageDefaultsToEnglish() {
        let defaults = makeDefaults()

        XCTAssertEqual(AppLanguage.stored(in: defaults), .english)
    }

    func testLanguageSelectionPersistsChinese() {
        let defaults = makeDefaults()

        AppLanguage.chinese.store(in: defaults)

        XCTAssertEqual(defaults.string(forKey: AppLanguage.storageKey), AppLanguage.chinese.rawValue)
        XCTAssertEqual(AppLanguage.stored(in: defaults), .chinese)
    }

    func testChineseDemoSeedLocalizesCoreDemoCopy() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let threads = CodexDemoSeed.threads(now: now, language: .chinese)
        let messages = CodexDemoSeed.messages(now: now, language: .chinese)

        XCTAssertEqual(threads.first?.title, "codex app UI 演示")
        XCTAssertTrue(
            messages[CodexDemoSeed.primaryThreadID, default: []]
                .contains { $0.text.contains("本地 UI 演示") }
        )
    }

    func testApplyDemoLanguageUpdatesSeededThreadsAndMessagesWithoutRelayIdentifiers() {
        let service = makeService()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        service.applyDemoSeed(now: now, language: .english)

        service.applyDemoLanguage(.chinese, now: now.addingTimeInterval(60))

        let primaryThread = service.threads.first { $0.id == CodexDemoSeed.primaryThreadID }
        XCTAssertEqual(primaryThread?.title, "codex app UI 演示")
        XCTAssertTrue(
            service.messagesByThread[CodexDemoSeed.primaryThreadID, default: []]
                .contains { $0.text.contains("本地 UI 演示") }
        )
        XCTAssertNil(service.relaySessionId)
        XCTAssertNil(service.relayUrl)
    }

    private func makeService() -> CodexService {
        let service = CodexService(defaults: makeDefaults())
        Self.retainedServices.append(service)
        return service
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "CodexAppLanguageTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
