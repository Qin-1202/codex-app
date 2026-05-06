# UI Demo Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a UI-only iOS demo that keeps the original backend/core source code in the repository while launching the app with local mock state and harmless interactions.

**Architecture:** Add a demo-mode boundary around app startup, seed `CodexService` with deterministic local state, and route demo-only user actions to local state mutations. Keep production bridge, networking, Git, and payment code available but bypassed when `AppDemoMode.isEnabled` is true.

**Tech Stack:** Swift, SwiftUI, Observation, XCTest, existing Xcode project `CodexMobile/CodexMobile.xcodeproj`, GitHub CLI for publishing.

---

## File Structure

- Create `CodexMobile/CodexMobile/Services/Demo/AppDemoMode.swift`: central demo-mode switch and persistent UI setup.
- Create `CodexMobile/CodexMobile/Services/Demo/CodexDemoSeed.swift`: deterministic mock threads, messages, and model options.
- Create `CodexMobile/CodexMobile/Services/Demo/CodexService+DemoMode.swift`: applies demo seed, creates local demo chats, and appends local demo turns.
- Modify `CodexMobile/CodexMobile/CodexMobileApp.swift`: skip live RevenueCat/bootstrap in demo mode and seed services before rendering.
- Modify `CodexMobile/CodexMobile/Services/Payments/SubscriptionService.swift`: add a demo access method that marks subscription state usable without RevenueCat.
- Modify `CodexMobile/CodexMobile/ContentView.swift`: select the initial demo thread and skip launch reconnect work in demo mode.
- Modify `CodexMobile/CodexMobile/Views/Turn/TurnViewModel.swift`: route composer sends to local demo turn appends in demo mode.
- Modify `CodexMobile/CodexMobile/Views/SidebarView.swift`: route refresh and new-chat actions to local demo state in demo mode.
- Modify `CodexMobile/BuildSupport/CodexMobile-Info.plist`: set display/user-facing permission copy to `codex app`.
- Modify `CodexMobile/CodexMobile.xcodeproj/project.pbxproj`: set app display build setting to `codex app`.
- Modify `README.md`: replace original product runbook with UI-demo open-source instructions and attribution.
- Create `CodexMobile/CodexMobileTests/CodexDemoModeTests.swift`: verify seed/bootstrap and demo send behavior.

---

### Task 1: Demo Seed And Service Bootstrap

**Files:**
- Create: `CodexMobile/CodexMobile/Services/Demo/AppDemoMode.swift`
- Create: `CodexMobile/CodexMobile/Services/Demo/CodexDemoSeed.swift`
- Create: `CodexMobile/CodexMobile/Services/Demo/CodexService+DemoMode.swift`
- Test: `CodexMobile/CodexMobileTests/CodexDemoModeTests.swift`

- [ ] **Step 1: Write the failing demo seed test**

Add `CodexMobile/CodexMobileTests/CodexDemoModeTests.swift`:

```swift
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
        XCTAssertEqual(messages.suffix(2).map(\.role), [.user, .assistant])
        XCTAssertEqual(messages.suffix(2).first?.deliveryState, .confirmed)
        XCTAssertTrue(messages.last?.text.localizedCaseInsensitiveContains("demo") == true)
        XCTAssertEqual(service.threads.first?.id, CodexDemoSeed.primaryThreadID)
        XCTAssertTrue(service.threads.first?.preview?.contains("Show the local UI demo response.") == true)
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
```

- [ ] **Step 2: Run the focused test to verify it fails**

Run:

```bash
xcodebuild test \
  -project CodexMobile/CodexMobile.xcodeproj \
  -scheme CodexMobile \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:CodexMobileTests/CodexDemoModeTests
```

Expected: fail to compile because `CodexDemoSeed`, `isDemoModeEnabled`, `applyDemoSeed`, and `appendDemoTurn` do not exist. If the local machine still reports `xcode-select: error: tool 'xcodebuild' requires Xcode`, record that as an environment blocker and continue with static implementation.

- [ ] **Step 3: Add the demo-mode switch**

Create `CodexMobile/CodexMobile/Services/Demo/AppDemoMode.swift`:

```swift
// FILE: AppDemoMode.swift
// Purpose: Central switch for the UI-only demo launch path.
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
```

- [ ] **Step 4: Add deterministic mock data**

Create `CodexMobile/CodexMobile/Services/Demo/CodexDemoSeed.swift`:

```swift
// FILE: CodexDemoSeed.swift
// Purpose: Provides deterministic local content for the UI-only demo.
// Layer: Service
// Exports: CodexDemoSeed
// Depends on: Foundation, CodexThread, CodexMessage, CodexModelOption

import Foundation

enum CodexDemoSeed {
    static let primaryThreadID = "demo-thread-mobile-ui"

    static func threads(now: Date = Date()) -> [CodexThread] {
        [
            CodexThread(
                id: primaryThreadID,
                title: "Polish iOS chat timeline",
                preview: "Reviewing sidebar, composer, and timeline interactions.",
                createdAt: now.addingTimeInterval(-86_400),
                updatedAt: now.addingTimeInterval(-120),
                cwd: "/Users/demo/Projects/codex-app",
                model: "gpt-5.5",
                modelProvider: "openai"
            ),
            CodexThread(
                id: "demo-thread-worktree",
                title: "Prepare release notes",
                preview: "Drafting concise notes for the UI demo repository.",
                createdAt: now.addingTimeInterval(-172_800),
                updatedAt: now.addingTimeInterval(-3_600),
                cwd: "/Users/demo/Projects/codex-app",
                model: "gpt-5.4",
                modelProvider: "openai"
            ),
            CodexThread(
                id: "demo-thread-settings",
                title: "Tune runtime settings",
                preview: "Testing model, reasoning, and access controls locally.",
                createdAt: now.addingTimeInterval(-259_200),
                updatedAt: now.addingTimeInterval(-9_000),
                cwd: "/Users/demo/Projects/local-tools",
                model: "gpt-5.5",
                modelProvider: "openai"
            ),
        ]
    }

    static func messages(now: Date = Date()) -> [String: [CodexMessage]] {
        [
            primaryThreadID: [
                CodexMessage(
                    id: "demo-message-1",
                    threadId: primaryThreadID,
                    role: .user,
                    text: "Keep the original app UI, but make it safe to explore without a bridge.",
                    createdAt: now.addingTimeInterval(-420),
                    deliveryState: .confirmed
                ),
                CodexMessage(
                    id: "demo-message-2",
                    threadId: primaryThreadID,
                    role: .assistant,
                    kind: .thinking,
                    text: "I will keep the SwiftUI surfaces intact and replace live dependencies with local demo state.",
                    createdAt: now.addingTimeInterval(-360),
                    deliveryState: .confirmed
                ),
                CodexMessage(
                    id: "demo-message-3",
                    threadId: primaryThreadID,
                    role: .system,
                    kind: .commandExecution,
                    text: "xcodebuild test -only-testing:CodexMobileTests/CodexDemoModeTests",
                    createdAt: now.addingTimeInterval(-300),
                    deliveryState: .confirmed
                ),
                CodexMessage(
                    id: "demo-message-4",
                    threadId: primaryThreadID,
                    role: .system,
                    kind: .fileChange,
                    text: "CodexMobile/CodexMobile/Services/Demo/AppDemoMode.swift\nCodexMobile/CodexMobile/Services/Demo/CodexDemoSeed.swift",
                    createdAt: now.addingTimeInterval(-240),
                    deliveryState: .confirmed
                ),
                CodexMessage(
                    id: "demo-message-5",
                    threadId: primaryThreadID,
                    role: .assistant,
                    text: "Demo mode is ready for local interaction. You can open threads, adjust runtime controls, and send messages without starting a live Codex session.",
                    createdAt: now.addingTimeInterval(-180),
                    deliveryState: .confirmed
                ),
            ],
            "demo-thread-worktree": [
                CodexMessage(
                    id: "demo-release-1",
                    threadId: "demo-thread-worktree",
                    role: .assistant,
                    text: "Release note draft: codex app is a UI-only iOS demo preserving the original source boundaries.",
                    createdAt: now.addingTimeInterval(-3_400),
                    deliveryState: .confirmed
                ),
            ],
            "demo-thread-settings": [
                CodexMessage(
                    id: "demo-settings-1",
                    threadId: "demo-thread-settings",
                    role: .user,
                    text: "Show the runtime controls without requiring a connected Mac.",
                    createdAt: now.addingTimeInterval(-8_900),
                    deliveryState: .confirmed
                ),
            ],
        ]
    }

    static func models() -> [CodexModelOption] {
        [
            CodexModelOption(
                id: "gpt-5.5",
                model: "gpt-5.5",
                displayName: "GPT-5.5",
                description: "Demo default model",
                isDefault: true,
                supportsFastMode: true,
                supportedReasoningEfforts: reasoningEfforts(),
                defaultReasoningEffort: "medium"
            ),
            CodexModelOption(
                id: "gpt-5.4",
                model: "gpt-5.4",
                displayName: "GPT-5.4",
                description: "Demo fast model",
                isDefault: false,
                supportsFastMode: true,
                supportedReasoningEfforts: reasoningEfforts(),
                defaultReasoningEffort: "low"
            ),
        ]
    }

    private static func reasoningEfforts() -> [CodexReasoningEffortOption] {
        [
            CodexReasoningEffortOption(reasoningEffort: "low", description: "Low"),
            CodexReasoningEffortOption(reasoningEffort: "medium", description: "Medium"),
            CodexReasoningEffortOption(reasoningEffort: "high", description: "High"),
        ]
    }
}
```

- [ ] **Step 5: Add service bootstrap and local demo turns**

Create `CodexMobile/CodexMobile/Services/Demo/CodexService+DemoMode.swift`:

```swift
// FILE: CodexService+DemoMode.swift
// Purpose: Applies demo state and handles local-only UI interactions.
// Layer: Service
// Exports: CodexService demo APIs
// Depends on: Foundation, CodexDemoSeed

import Foundation

extension CodexService {
    func applyDemoSeed(now: Date = Date()) {
        isDemoModeEnabled = true
        isConnected = true
        isConnecting = false
        isInitialized = true
        isLoadingThreads = false
        isBootstrappingConnectionSync = false
        shouldAutoReconnectOnForeground = false
        connectionRecoveryState = .idle
        lastErrorMessage = nil
        relaySessionId = nil
        relayUrl = nil
        relayMacDeviceId = nil
        relayMacIdentityPublicKey = nil
        secureConnectionState = .notPaired
        threads = CodexDemoSeed.threads(now: now)
        messagesByThread = CodexDemoSeed.messages(now: now)
        messageRevisionByThread = messagesByThread.mapValues { _ in 1 }
        availableModels = CodexDemoSeed.models()
        selectedModelId = "gpt-5.5"
        selectedGitWriterModelId = nil
        selectedReasoningEffort = "medium"
        selectedAccessMode = .onRequest
        selectedServiceTier = .fast
        activeThreadId = CodexDemoSeed.primaryThreadID
        activeTurnId = nil
        activeTurnIdByThread.removeAll()
        runningThreadIDs.removeAll()
        readyThreadIDs.removeAll()
        failedThreadIDs.removeAll()
        pendingApprovals.removeAll()
        queuedTurnDraftsByThread.removeAll()
    }

    @discardableResult
    func startDemoThread(preferredProjectPath: String? = nil) -> CodexThread {
        let threadID = "demo-thread-\(UUID().uuidString)"
        let now = Date()
        let thread = CodexThread(
            id: threadID,
            title: "New demo chat",
            preview: "A local-only conversation for exploring the UI.",
            createdAt: now,
            updatedAt: now,
            cwd: preferredProjectPath ?? "/Users/demo/Projects/codex-app",
            model: selectedModelId,
            modelProvider: "openai"
        )
        threads.insert(thread, at: 0)
        messagesByThread[threadID] = [
            CodexMessage(
                threadId: threadID,
                role: .assistant,
                text: "This is a local demo chat. Messages stay on device and no bridge request is made.",
                createdAt: now,
                deliveryState: .confirmed
            ),
        ]
        messageRevisionByThread[threadID] = 1
        activeThreadId = threadID
        return thread
    }

    func appendDemoTurn(userInput: String, threadId: String) {
        let trimmedInput = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return }

        let now = Date()
        appendMessage(
            CodexMessage(
                threadId: threadId,
                role: .user,
                text: trimmedInput,
                createdAt: now,
                deliveryState: .confirmed
            )
        )
        appendMessage(
            CodexMessage(
                threadId: threadId,
                role: .assistant,
                text: "Demo response: I captured your message locally and kept the UI flow interactive without contacting the bridge.",
                createdAt: now.addingTimeInterval(1),
                deliveryState: .confirmed
            )
        )

        if let index = threads.firstIndex(where: { $0.id == threadId }) {
            threads[index].preview = trimmedInput
            threads[index].updatedAt = now
            let refreshed = threads.remove(at: index)
            threads.insert(refreshed, at: 0)
        }
        activeThreadId = threadId
        lastErrorMessage = nil
    }
}
```

- [ ] **Step 6: Add the service flag**

Modify `CodexMobile/CodexMobile/Services/CodexService.swift` public state near `threads`:

```swift
var isDemoModeEnabled = false
```

- [ ] **Step 7: Run the focused test to verify it passes or capture the environment blocker**

Run the same command as Step 2.

Expected: `CodexDemoModeTests` passes. If `xcodebuild` is blocked by active Command Line Tools, capture the exact blocker and run static checks in Task 5 after code edits.

- [ ] **Step 8: Commit**

```bash
git add \
  CodexMobile/CodexMobile/Services/CodexService.swift \
  CodexMobile/CodexMobile/Services/Demo/AppDemoMode.swift \
  CodexMobile/CodexMobile/Services/Demo/CodexDemoSeed.swift \
  CodexMobile/CodexMobile/Services/Demo/CodexService+DemoMode.swift \
  CodexMobile/CodexMobileTests/CodexDemoModeTests.swift
git commit -m "Add UI demo seed state"
```

---

### Task 2: Demo Launch Path

**Files:**
- Modify: `CodexMobile/CodexMobile/CodexMobileApp.swift`
- Modify: `CodexMobile/CodexMobile/Services/Payments/SubscriptionService.swift`
- Modify: `CodexMobile/CodexMobile/ContentView.swift`
- Test: `CodexMobile/CodexMobileTests/CodexDemoModeTests.swift`

- [ ] **Step 1: Add a failing test for persistent onboarding setup**

Append to `CodexDemoModeTests`:

```swift
func testPreparePersistentUIStateMarksOnboardingSeen() {
    let suiteName = "CodexDemoModeTests.onboarding.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName) ?? .standard
    defaults.removePersistentDomain(forName: suiteName)

    AppDemoMode.preparePersistentUIState(defaults: defaults)

    XCTAssertTrue(defaults.bool(forKey: AppDemoMode.hasSeenOnboardingDefaultsKey))
}
```

- [ ] **Step 2: Run the focused test**

Run:

```bash
xcodebuild test \
  -project CodexMobile/CodexMobile.xcodeproj \
  -scheme CodexMobile \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:CodexMobileTests/CodexDemoModeTests/testPreparePersistentUIStateMarksOnboardingSeen
```

Expected: pass after Task 1. If blocked by `xcode-select`, record blocker.

- [ ] **Step 3: Add demo subscription access**

In `SubscriptionService`, add this method near `hasAppAccess`:

```swift
func applyDemoAccess() {
    bootstrapState = .ready
    hasProAccess = true
    freeSendCount = 0
    isLoading = false
    isPurchasing = false
    isRestoring = false
    lastErrorMessage = nil
}
```

- [ ] **Step 4: Wire demo startup**

Modify `CodexMobileApp.init()`:

```swift
init() {
    if AppDemoMode.isEnabled {
        AppDemoMode.preparePersistentUIState()
    } else {
        Self.configureRevenueCatIfAvailable()
    }

    let service = CodexService()
    if AppDemoMode.isEnabled {
        service.applyDemoSeed()
    } else {
        service.configureNotifications()
    }

    let subscriptions = SubscriptionService()
    if AppDemoMode.isEnabled {
        subscriptions.applyDemoAccess()
    }

    _codexService = State(initialValue: service)
    _petCompanionStore = State(initialValue: PetCompanionStore())
    _petCompanionStatusStore = State(initialValue: PetCompanionStatusStore())
    _subscriptionService = State(initialValue: subscriptions)
}
```

Modify the root `.task` inside `CodexMobileApp.body`:

```swift
.task {
    guard !AppDemoMode.isEnabled else { return }
    await subscriptionService.bootstrap()
}
```

- [ ] **Step 5: Select an initial thread and skip launch reconnect in demo mode**

Modify the first `.task` in `ContentView.rootContentWithLifecycleObservers`:

```swift
.task {
    selectInitialThreadIfNeeded()
    guard !AppDemoMode.isEnabled else {
        scheduleSidebarPrewarmIfNeeded()
        return
    }
    guard hasSeenOnboarding, !isShowingManualScanner else {
        debugSidebarLog("launch task skipped onboardingSeen=\(hasSeenOnboarding) manualScanner=\(isShowingManualScanner)")
        return
    }
    debugSidebarLog("launch task autoConnect begin connected=\(codex.isConnected) threadCount=\(codex.threads.count)")
    await viewModel.attemptAutoConnectOnLaunchIfNeeded(codex: codex)
    scheduleSidebarPrewarmIfNeeded()
}
```

Add a helper near `syncSelectedThread(with:)`:

```swift
private func selectInitialThreadIfNeeded() {
    guard selectedThread == nil else { return }
    if let activeThreadId = codex.activeThreadId,
       let activeThread = codex.threads.first(where: { $0.id == activeThreadId }) {
        selectedThread = activeThread
        return
    }
    selectedThread = codex.threads.first
    codex.activeThreadId = selectedThread?.id
}
```

- [ ] **Step 6: Run focused tests or capture blocker**

Run:

```bash
xcodebuild test \
  -project CodexMobile/CodexMobile.xcodeproj \
  -scheme CodexMobile \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:CodexMobileTests/CodexDemoModeTests
```

Expected: `CodexDemoModeTests` passes, or `xcode-select` environment blocker is still present.

- [ ] **Step 7: Commit**

```bash
git add \
  CodexMobile/CodexMobile/CodexMobileApp.swift \
  CodexMobile/CodexMobile/Services/Payments/SubscriptionService.swift \
  CodexMobile/CodexMobile/ContentView.swift \
  CodexMobile/CodexMobileTests/CodexDemoModeTests.swift
git commit -m "Launch iOS app in UI demo mode"
```

---

### Task 3: Local Demo Interactions

**Files:**
- Modify: `CodexMobile/CodexMobile/Views/Turn/TurnViewModel.swift`
- Modify: `CodexMobile/CodexMobile/Views/SidebarView.swift`
- Test: `CodexMobile/CodexMobileTests/CodexDemoModeTests.swift`

- [ ] **Step 1: Add a failing test for local new chat**

Append to `CodexDemoModeTests`:

```swift
func testStartDemoThreadCreatesLocalConversation() {
    let service = makeService()
    service.applyDemoSeed(now: Date(timeIntervalSince1970: 1_800_000_000))
    let beforeCount = service.threads.count

    let thread = service.startDemoThread(preferredProjectPath: "/Users/demo/Projects/new-demo")

    XCTAssertEqual(service.threads.count, beforeCount + 1)
    XCTAssertEqual(service.threads.first?.id, thread.id)
    XCTAssertEqual(service.activeThreadId, thread.id)
    XCTAssertEqual(thread.cwd, "/Users/demo/Projects/new-demo")
    XCTAssertFalse(service.messagesByThread[thread.id, default: []].isEmpty)
}
```

- [ ] **Step 2: Run the focused test**

Run:

```bash
xcodebuild test \
  -project CodexMobile/CodexMobile.xcodeproj \
  -scheme CodexMobile \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:CodexMobileTests/CodexDemoModeTests/testStartDemoThreadCreatesLocalConversation
```

Expected: pass after Task 1. If blocked by `xcode-select`, record blocker.

- [ ] **Step 3: Route composer sends locally in demo mode**

At the start of `TurnViewModel.sendTurn(codex:subscriptions:threadID:)`, after local payload variables are computed and before subscription consumption/network work:

```swift
if codex.isDemoModeEnabled {
    guard (!payload.isEmpty || !attachments.isEmpty || reviewSelection != nil),
          !isSending,
          codex.isConnected,
          !hasBlockingAttachmentState else {
        return
    }
    isSending = true
    codex.appendDemoTurn(
        userInput: payload.isEmpty ? "Demo attachment message" : payload,
        threadId: threadID
    )
    shouldAnchorToAssistantResponse = true
    clearComposer()
    isSending = false
    return
}
```

- [ ] **Step 4: Route sidebar refresh and new chat locally in demo mode**

In `SidebarView.refreshThreads()`:

```swift
guard !codex.isDemoModeEnabled else { return }
```

At the start of `handleNewChatTap(preferredProjectPath:)`:

```swift
if codex.isDemoModeEnabled {
    prepareSidebarForChatNavigation()
    let thread = codex.startDemoThread(preferredProjectPath: preferredProjectPath)
    onOpenThread(thread)
    return
}
```

At the start of `handleNewWorktreeChatTap(preferredProjectPath:)`:

```swift
if codex.isDemoModeEnabled {
    prepareSidebarForChatNavigation()
    let thread = codex.startDemoThread(preferredProjectPath: preferredProjectPath)
    onOpenThread(thread)
    return
}
```

- [ ] **Step 5: Run focused tests or capture blocker**

Run:

```bash
xcodebuild test \
  -project CodexMobile/CodexMobile.xcodeproj \
  -scheme CodexMobile \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:CodexMobileTests/CodexDemoModeTests
```

Expected: `CodexDemoModeTests` passes, or the environment blocker is unchanged.

- [ ] **Step 6: Commit**

```bash
git add \
  CodexMobile/CodexMobile/Views/Turn/TurnViewModel.swift \
  CodexMobile/CodexMobile/Views/SidebarView.swift \
  CodexMobile/CodexMobileTests/CodexDemoModeTests.swift
git commit -m "Keep demo interactions local"
```

---

### Task 4: Branding And README

**Files:**
- Modify: `CodexMobile/BuildSupport/CodexMobile-Info.plist`
- Modify: `CodexMobile/CodexMobile.xcodeproj/project.pbxproj`
- Modify: `README.md`

- [ ] **Step 1: Rebrand the iOS display name and permission copy**

In `CodexMobile-Info.plist`, change:

```xml
<key>CFBundleDisplayName</key>
<string>codex app</string>
```

Update visible permission strings from `Remodex needs...` to `codex app needs...`. Keep technical keys and URL schemes unchanged unless a later build requires a bundle-identifier change.

In `project.pbxproj`, update both `INFOPLIST_KEY_CFBundleDisplayName = Remodex;` entries for the iOS app target to:

```text
INFOPLIST_KEY_CFBundleDisplayName = "codex app";
```

- [ ] **Step 2: Replace README with UI demo project copy**

Rewrite `README.md` with these sections:

```markdown
# codex app

`codex app` is an open-source iOS UI demo based on the original Remodex source. It preserves the SwiftUI app surfaces and local interaction patterns while launching with mock data instead of requiring a live Codex bridge.

## What This Demo Includes

- the original iOS navigation shell, sidebar, thread list, timeline, composer, settings, and runtime controls
- local demo threads and messages
- local-only send/new-chat interactions
- preserved bridge, Codex service, Git, secure pairing, and payment source files for reference

## What Demo Mode Does Not Do

- connect to a live Codex runtime
- pair with a Mac bridge
- run Git mutations
- require a hosted relay
- require RevenueCat configuration at launch

## Run Locally

1. Open `CodexMobile/CodexMobile.xcodeproj` in Xcode.
2. Select the `CodexMobile` scheme.
3. Run on an iPhone simulator or device.

The app starts directly in demo mode. No QR pairing step is required.

## Original Project

This project is derived from the open-source Remodex repository by Emanuele Di Pietro. The original backend and core logic are intentionally kept in this repository, but the default launch path is configured as a UI-only demo.

## License

See `LICENSE`.
```

- [ ] **Step 3: Commit**

```bash
git add \
  CodexMobile/BuildSupport/CodexMobile-Info.plist \
  CodexMobile/CodexMobile.xcodeproj/project.pbxproj \
  README.md
git commit -m "Rebrand project as codex app UI demo"
```

---

### Task 5: Verification And GitHub Publish

**Files:**
- No source file changes expected unless verification finds compile issues.

- [ ] **Step 1: Run repository status and diff checks**

```bash
git status --short --branch
git log --oneline -5
```

Expected: current branch contains the spec, plan, and implementation commits; no unintended `.superpowers/` files are staged.

- [ ] **Step 2: Run focused tests**

```bash
xcodebuild test \
  -project CodexMobile/CodexMobile.xcodeproj \
  -scheme CodexMobile \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:CodexMobileTests/CodexDemoModeTests
```

Expected: pass. If blocked by the current developer directory, report the exact `xcode-select` blocker and do not claim tests passed.

- [ ] **Step 3: Run a build check**

```bash
xcodebuild build \
  -project CodexMobile/CodexMobile.xcodeproj \
  -scheme CodexMobile \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: build succeeds. If blocked by the current developer directory, report the exact `xcode-select` blocker and do not claim build success.

- [ ] **Step 4: Create the public GitHub repository**

Verify the authenticated owner:

```bash
gh auth status
```

If `Qin-1202/codex-app` does not exist, preserve the original upstream remote and create the new public repository:

```bash
git remote rename origin upstream
gh repo create codex-app --public --source . --remote origin --push
```

If `Qin-1202/codex-app` already exists before this step, use:

```bash
git remote rename origin upstream
git remote add origin https://github.com/Qin-1202/codex-app.git
git push -u origin main
```

- [ ] **Step 5: Verify remotes and published repository**

```bash
git remote -v
gh repo view Qin-1202/codex-app --json nameWithOwner,visibility,url
```

Expected: `origin` points to `https://github.com/Qin-1202/codex-app.git`, `upstream` points to `https://github.com/Emanuele-web04/remodex.git`, and the repository visibility is `PUBLIC`.

- [ ] **Step 6: Final status**

```bash
git status --short --branch
```

Expected: clean working tree on `main` tracking `origin/main`, or only intentionally untracked local helper files ignored by Git.

---

## Self-Review

- Spec coverage: demo launch, preserved backend/core source, local interactions, README/open-source positioning, and GitHub publication are covered by Tasks 1-5.
- Placeholder scan: no task uses `TBD`, `TODO`, or unspecified “add tests” steps.
- Type consistency: planned names are consistent across files: `AppDemoMode`, `CodexDemoSeed`, `isDemoModeEnabled`, `applyDemoSeed`, `startDemoThread`, `appendDemoTurn`, and `applyDemoAccess`.
