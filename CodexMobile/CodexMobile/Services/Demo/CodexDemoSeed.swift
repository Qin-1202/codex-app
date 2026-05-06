// FILE: CodexDemoSeed.swift
// Purpose: Provides local-only threads, messages, and runtime options for the UI demo.
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
                title: "codex app UI demo",
                name: "codex app UI demo",
                preview: "Local demo state is connected and ready.",
                createdAt: now.addingTimeInterval(-7_200),
                updatedAt: now,
                cwd: "~/Projects/codex-app",
                model: "gpt-5.5",
                modelProvider: "openai"
            ),
            CodexThread(
                id: "demo-thread-composer",
                title: "Composer controls",
                name: "Composer controls",
                preview: "Try model, reasoning, file, image, and review controls.",
                createdAt: now.addingTimeInterval(-12_600),
                updatedAt: now.addingTimeInterval(-3_600),
                cwd: "~/Projects/mobile-client",
                model: "gpt-5.4",
                modelProvider: "openai"
            ),
            CodexThread(
                id: "demo-thread-sidebar",
                title: "Sidebar workflow",
                name: "Sidebar workflow",
                preview: "Search, project groups, pins, archive actions, and local chats remain interactive.",
                createdAt: now.addingTimeInterval(-18_000),
                updatedAt: now.addingTimeInterval(-8_400),
                cwd: "~/Projects/codex-app",
                model: "gpt-5.3-codex",
                modelProvider: "openai"
            ),
        ]
    }

    static func messages(now: Date = Date()) -> [String: [CodexMessage]] {
        [
            primaryThreadID: [
                message(
                    threadID: primaryThreadID,
                    role: .user,
                    text: "Show me the mobile UI demo.",
                    createdAt: now.addingTimeInterval(-240),
                    turnID: "demo-turn-welcome"
                ),
                message(
                    threadID: primaryThreadID,
                    role: .assistant,
                    text: "This is a local UI demo. Chats, model controls, sidebar navigation, and message rendering are active, but live bridge calls are disabled.",
                    createdAt: now.addingTimeInterval(-220),
                    turnID: "demo-turn-welcome"
                ),
                message(
                    threadID: primaryThreadID,
                    role: .system,
                    kind: .toolActivity,
                    text: "Demo mode: backend, secure pairing, Git, payment, and bridge source code are still in the repository.",
                    createdAt: now.addingTimeInterval(-180),
                    turnID: "demo-turn-welcome",
                    itemID: "demo-tool-note"
                ),
            ],
            "demo-thread-composer": [
                message(
                    threadID: "demo-thread-composer",
                    role: .user,
                    text: "What can I try in the composer?",
                    createdAt: now.addingTimeInterval(-3_900),
                    turnID: "demo-turn-composer"
                ),
                message(
                    threadID: "demo-thread-composer",
                    role: .assistant,
                    text: "You can type a prompt, toggle plan mode, inspect runtime controls, and send a local-only turn. The response is generated from demo state.",
                    createdAt: now.addingTimeInterval(-3_860),
                    turnID: "demo-turn-composer"
                ),
            ],
            "demo-thread-sidebar": [
                message(
                    threadID: "demo-thread-sidebar",
                    role: .user,
                    text: "Keep the sidebar interactions available.",
                    createdAt: now.addingTimeInterval(-8_900),
                    turnID: "demo-turn-sidebar"
                ),
                message(
                    threadID: "demo-thread-sidebar",
                    role: .assistant,
                    text: "The sidebar uses local demo threads, so opening chats and creating new demo chats work without pairing to a computer.",
                    createdAt: now.addingTimeInterval(-8_860),
                    turnID: "demo-turn-sidebar"
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
                description: "Frontier model for complex coding, research, and product work.",
                isDefault: true,
                supportsFastMode: true,
                supportedReasoningEfforts: reasoningEfforts(["low", "medium", "high", "xhigh"]),
                defaultReasoningEffort: "medium"
            ),
            CodexModelOption(
                id: "gpt-5.4",
                model: "gpt-5.4",
                displayName: "GPT-5.4",
                description: "Strong model for everyday coding and app work.",
                isDefault: false,
                supportsFastMode: true,
                supportedReasoningEfforts: reasoningEfforts(["low", "medium", "high", "xhigh"]),
                defaultReasoningEffort: "medium"
            ),
            CodexModelOption(
                id: "gpt-5.3-codex",
                model: "gpt-5.3-codex",
                displayName: "GPT-5.3-Codex",
                description: "Coding-focused model option for demo runtime controls.",
                isDefault: false,
                supportsFastMode: false,
                supportedReasoningEfforts: reasoningEfforts(["low", "medium", "high"]),
                defaultReasoningEffort: "medium"
            ),
        ]
    }

    static func newThreadMessages(
        threadID: String,
        now: Date = Date(),
        preferredProjectPath: String?
    ) -> [CodexMessage] {
        let projectLabel = preferredProjectPath?.trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = projectLabel?.isEmpty == false ? " for \(projectLabel!)" : ""
        return [
            message(
                threadID: threadID,
                role: .assistant,
                text: "This local demo chat\(suffix) is ready. Sends stay on-device and append mock assistant responses.",
                createdAt: now,
                turnID: "demo-turn-\(threadID)-welcome"
            ),
        ]
    }

    static func assistantReply(for userInput: String) -> String {
        let trimmed = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let topic = trimmed.isEmpty ? "that request" : "\"\(trimmed)\""
        return "Demo response for \(topic). This app is running with local mock state, so no bridge, relay, Git, payment, or backend request was made."
    }

    private static func reasoningEfforts(_ values: [String]) -> [CodexReasoningEffortOption] {
        values.map { CodexReasoningEffortOption(reasoningEffort: $0, description: "") }
    }

    private static func message(
        threadID: String,
        role: CodexMessageRole,
        kind: CodexMessageKind = .chat,
        text: String,
        createdAt: Date,
        turnID: String,
        itemID: String? = nil
    ) -> CodexMessage {
        CodexMessage(
            id: "\(threadID)-\(turnID)-\(role.rawValue)-\(itemID ?? UUID().uuidString)",
            threadId: threadID,
            role: role,
            kind: kind,
            text: text,
            createdAt: createdAt,
            turnId: turnID,
            itemId: itemID,
            deliveryState: .confirmed
        )
    }
}
