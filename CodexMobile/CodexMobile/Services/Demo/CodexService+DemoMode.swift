// FILE: CodexService+DemoMode.swift
// Purpose: Applies local-only demo state and handles demo chat actions without live bridge calls.
// Layer: Service
// Exports: CodexService demo mode APIs
// Depends on: Foundation, CodexService, CodexDemoSeed

import Foundation

extension CodexService {
    func applyDemoSeed(now: Date = Date(), language: AppLanguage = .stored()) {
        isDemoModeEnabled = true
        syncRealtimeEnabled = false
        stopSyncLoop()
        postConnectSyncTask?.cancel()
        postConnectSyncTask = nil
        gptAccountLoginSyncTask?.cancel()
        gptAccountLoginSyncTask = nil
        trustedSessionResolveTask?.cancel()
        trustedSessionResolveTask = nil

        isConnected = true
        isConnecting = false
        isInitialized = true
        isLoadingThreads = false
        isBootstrappingConnectionSync = false
        isLoadingModels = false
        modelsErrorMessage = nil
        lastErrorMessage = nil
        currentOutput = ""

        activeTurnId = nil
        activeTurnIdByThread.removeAll()
        pendingApprovals.removeAll()
        queuedTurnDraftsByThread.removeAll()
        queuePauseStateByThread.removeAll()
        clearAllRunningState()
        readyThreadIDs.removeAll()
        failedThreadIDs.removeAll()
        runningThreadWatchByID.removeAll()
        threadCompletionBanner = nil
        missingNotificationThreadPrompt = nil

        relaySessionId = nil
        relayUrl = nil
        relayMacDeviceId = nil
        relayMacIdentityPublicKey = nil
        secureSession = nil
        pendingHandshake = nil
        secureConnectionState = .encrypted
        shouldAutoReconnectOnForeground = false
        shouldForceQRBootstrapOnNextHandshake = false

        availableModels = CodexDemoSeed.models()
        selectedModelId = "gpt-5.5"
        selectedGitWriterModelId = nil
        selectedReasoningEffort = "medium"
        selectedServiceTier = .fast
        selectedAccessMode = .onRequest
        supportsStructuredSkillInput = true
        supportsStructuredMentionInput = true
        supportsTurnCollaborationMode = true
        supportsServiceTier = true
        supportsBridgeVoiceAuth = false
        supportsThreadFork = true
        supportsTurnPagination = false

        threads = sortThreads(CodexDemoSeed.threads(now: now, language: language))
        messagesByThread = CodexDemoSeed.messages(now: now, language: language)
        let threadIDs = Set(threads.map(\.id))
        messageRevisionByThread = Dictionary(uniqueKeysWithValues: threadIDs.map { ($0, 1) })
        hydratedThreadIDs = threadIDs
        loadingThreadIDs.removeAll()
        loadingOlderThreadHistoryIDs.removeAll()
        initialTurnsLoadedByThreadID = threadIDs
        threadsWithAuthoritativeLocalHistoryStart = threadIDs
        olderThreadHistoryCursorByThreadID.removeAll()
        exhaustedOlderThreadHistoryCursorByThreadID.removeAll()
        olderHistoryLoadErrorByThreadID.removeAll()

        activeThreadId = CodexDemoSeed.primaryThreadID
        refreshAllThreadTimelineStates()
        updateCurrentOutput(for: CodexDemoSeed.primaryThreadID)
    }

    func applyDemoLanguage(_ language: AppLanguage, now: Date = Date()) {
        guard isDemoModeEnabled else { return }

        let localizedSeedThreads = CodexDemoSeed.threads(now: now, language: language)
        for localizedThread in localizedSeedThreads {
            guard let index = threadIndex(for: localizedThread.id) else { continue }
            threads[index].title = localizedThread.title
            threads[index].name = localizedThread.name
            threads[index].preview = localizedThread.preview
            threads[index].cwd = localizedThread.cwd
            threads[index].model = localizedThread.model
            threads[index].modelProvider = localizedThread.modelProvider
        }

        let localizedMessages = CodexDemoSeed.messages(now: now, language: language)
        for (threadID, messages) in localizedMessages {
            messagesByThread[threadID] = messages
            messageRevisionByThread[threadID, default: 0] += 1
        }

        threads = sortThreads(threads)
        refreshAllThreadTimelineStates()
        updateCurrentOutput(for: activeThreadId ?? CodexDemoSeed.primaryThreadID)
    }

    @discardableResult
    func startDemoThread(preferredProjectPath: String? = nil) -> CodexThread {
        if !isDemoModeEnabled {
            applyDemoSeed()
        }

        let now = nextDemoTimestamp()
        let threadID = "demo-thread-\(UUID().uuidString)"
        let thread = CodexThread(
            id: threadID,
            title: CodexThread.defaultDisplayTitle,
            preview: "Local demo chat ready.",
            createdAt: now,
            updatedAt: now,
            cwd: preferredProjectPath,
            model: selectedModelId ?? "gpt-5.5",
            modelProvider: "openai"
        )

        messagesByThread[threadID] = CodexDemoSeed.newThreadMessages(
            threadID: threadID,
            now: now,
            preferredProjectPath: preferredProjectPath,
            language: .stored()
        )
        messageRevisionByThread[threadID] = 1
        hydratedThreadIDs.insert(threadID)
        initialTurnsLoadedByThreadID.insert(threadID)
        threadsWithAuthoritativeLocalHistoryStart.insert(threadID)
        upsertThread(thread)
        activeThreadId = threadID
        markThreadAsViewed(threadID)
        updateCurrentOutput(for: threadID)

        return thread
    }

    func appendDemoTurn(userInput: String, threadId: String) {
        guard isDemoModeEnabled else { return }
        let normalizedInput = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedInput.isEmpty else { return }

        let now = nextDemoTimestamp()
        let turnID = "demo-turn-\(UUID().uuidString)"
        let userMessage = CodexMessage(
            threadId: threadId,
            role: .user,
            text: normalizedInput,
            createdAt: now,
            turnId: turnID,
            deliveryState: .confirmed
        )
        let assistantMessage = CodexMessage(
            threadId: threadId,
            role: .assistant,
            text: CodexDemoSeed.assistantReply(for: normalizedInput, language: .stored()),
            createdAt: now.addingTimeInterval(0.1),
            turnId: turnID,
            deliveryState: .confirmed
        )

        messagesByThread[threadId, default: []].append(contentsOf: [userMessage, assistantMessage])
        messagesByThread[threadId]?.sort { $0.orderIndex < $1.orderIndex }

        if let index = threadIndex(for: threadId) {
            threads[index].preview = normalizedInput
            threads[index].updatedAt = now
            threads = sortThreads(threads)
        }

        activeThreadId = threadId
        clearRunningState(for: threadId)
        lastErrorMessage = nil
        updateCurrentOutput(for: threadId)
    }
}

private extension CodexService {
    func nextDemoTimestamp() -> Date {
        let latestThreadDate = threads.compactMap { thread in
            thread.updatedAt ?? thread.createdAt
        }.max() ?? Date()
        let current = Date()

        return current > latestThreadDate ? current : latestThreadDate.addingTimeInterval(1)
    }
}
