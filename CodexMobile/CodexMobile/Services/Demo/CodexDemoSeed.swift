// FILE: CodexDemoSeed.swift
// Purpose: Provides local-only threads, messages, and runtime options for the UI demo.
// Layer: Service
// Exports: CodexDemoSeed
// Depends on: Foundation, CodexThread, CodexMessage, CodexModelOption

import Foundation

enum CodexDemoSeed {
    static let primaryThreadID = "demo-thread-mobile-ui"

    static func threads(now: Date = Date(), language: AppLanguage = .stored()) -> [CodexThread] {
        let copy = copy(for: language)
        return [
            CodexThread(
                id: primaryThreadID,
                title: copy.primaryTitle,
                name: copy.primaryTitle,
                preview: copy.primaryPreview,
                createdAt: now.addingTimeInterval(-7_200),
                updatedAt: now,
                cwd: "~/Projects/codex-app",
                model: "gpt-5.5",
                modelProvider: "openai"
            ),
            CodexThread(
                id: "demo-thread-composer",
                title: copy.composerTitle,
                name: copy.composerTitle,
                preview: copy.composerPreview,
                createdAt: now.addingTimeInterval(-12_600),
                updatedAt: now.addingTimeInterval(-3_600),
                cwd: "~/Projects/mobile-client",
                model: "gpt-5.4",
                modelProvider: "openai"
            ),
            CodexThread(
                id: "demo-thread-sidebar",
                title: copy.sidebarTitle,
                name: copy.sidebarTitle,
                preview: copy.sidebarPreview,
                createdAt: now.addingTimeInterval(-18_000),
                updatedAt: now.addingTimeInterval(-8_400),
                cwd: "~/Projects/codex-app",
                model: "gpt-5.3-codex",
                modelProvider: "openai"
            ),
        ]
    }

    static func messages(now: Date = Date(), language: AppLanguage = .stored()) -> [String: [CodexMessage]] {
        let copy = copy(for: language)
        return [
            primaryThreadID: [
                message(
                    threadID: primaryThreadID,
                    role: .user,
                    text: copy.primaryUserMessage,
                    createdAt: now.addingTimeInterval(-240),
                    turnID: "demo-turn-welcome"
                ),
                message(
                    threadID: primaryThreadID,
                    role: .assistant,
                    text: copy.primaryAssistantMessage,
                    createdAt: now.addingTimeInterval(-220),
                    turnID: "demo-turn-welcome"
                ),
                message(
                    threadID: primaryThreadID,
                    role: .system,
                    kind: .toolActivity,
                    text: copy.primaryToolMessage,
                    createdAt: now.addingTimeInterval(-180),
                    turnID: "demo-turn-welcome",
                    itemID: "demo-tool-note"
                ),
            ],
            "demo-thread-composer": [
                message(
                    threadID: "demo-thread-composer",
                    role: .user,
                    text: copy.composerUserMessage,
                    createdAt: now.addingTimeInterval(-3_900),
                    turnID: "demo-turn-composer"
                ),
                message(
                    threadID: "demo-thread-composer",
                    role: .assistant,
                    text: copy.composerAssistantMessage,
                    createdAt: now.addingTimeInterval(-3_860),
                    turnID: "demo-turn-composer"
                ),
            ],
            "demo-thread-sidebar": [
                message(
                    threadID: "demo-thread-sidebar",
                    role: .user,
                    text: copy.sidebarUserMessage,
                    createdAt: now.addingTimeInterval(-8_900),
                    turnID: "demo-turn-sidebar"
                ),
                message(
                    threadID: "demo-thread-sidebar",
                    role: .assistant,
                    text: copy.sidebarAssistantMessage,
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
        preferredProjectPath: String?,
        language: AppLanguage = .stored()
    ) -> [CodexMessage] {
        let copy = copy(for: language)
        let projectLabel = preferredProjectPath?.trimmingCharacters(in: .whitespacesAndNewlines)
        return [
            message(
                threadID: threadID,
                role: .assistant,
                text: copy.newThreadReady(projectLabel),
                createdAt: now,
                turnID: "demo-turn-\(threadID)-welcome"
            ),
        ]
    }

    static func assistantReply(for userInput: String, language: AppLanguage = .stored()) -> String {
        let trimmed = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        return copy(for: language).assistantReply(trimmed)
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

    private static func copy(for language: AppLanguage) -> DemoCopy {
        switch language {
        case .english:
            return DemoCopy.english
        case .chinese:
            return DemoCopy.chinese
        }
    }
}

private struct DemoCopy {
    let primaryTitle: String
    let primaryPreview: String
    let composerTitle: String
    let composerPreview: String
    let sidebarTitle: String
    let sidebarPreview: String
    let primaryUserMessage: String
    let primaryAssistantMessage: String
    let primaryToolMessage: String
    let composerUserMessage: String
    let composerAssistantMessage: String
    let sidebarUserMessage: String
    let sidebarAssistantMessage: String
    let newThreadReady: (String?) -> String
    let assistantReply: (String) -> String

    static let english = DemoCopy(
        primaryTitle: "codex app UI demo",
        primaryPreview: "Local demo state is connected and ready.",
        composerTitle: "Composer controls",
        composerPreview: "Try model, reasoning, file, image, and review controls.",
        sidebarTitle: "Sidebar workflow",
        sidebarPreview: "Search, project groups, pins, archive actions, and local chats remain interactive.",
        primaryUserMessage: "Show me the mobile UI demo.",
        primaryAssistantMessage: "This is a local UI demo. Chats, model controls, sidebar navigation, and message rendering are active, but live bridge calls are disabled.",
        primaryToolMessage: "Demo mode: backend, secure pairing, Git, payment, and bridge source code are still in the repository.",
        composerUserMessage: "What can I try in the composer?",
        composerAssistantMessage: "You can type a prompt, toggle plan mode, inspect runtime controls, and send a local-only turn. The response is generated from demo state.",
        sidebarUserMessage: "Keep the sidebar interactions available.",
        sidebarAssistantMessage: "The sidebar uses local demo threads, so opening chats and creating new demo chats work without pairing to a computer.",
        newThreadReady: { projectLabel in
            let suffix = projectLabel?.isEmpty == false ? " for \(projectLabel!)" : ""
            return "This local demo chat\(suffix) is ready. Sends stay on-device and append mock assistant responses."
        },
        assistantReply: { trimmed in
            let topic = trimmed.isEmpty ? "that request" : "\"\(trimmed)\""
            return "Demo response for \(topic). This app is running with local mock state, so no bridge, relay, Git, payment, or backend request was made."
        }
    )

    static let chinese = DemoCopy(
        primaryTitle: "codex app UI 演示",
        primaryPreview: "本地演示状态已连接，可以开始使用。",
        composerTitle: "输入框控制",
        composerPreview: "试用模型、推理、文件、图片和审查控制。",
        sidebarTitle: "侧边栏流程",
        sidebarPreview: "搜索、项目分组、置顶、归档和本地聊天都可交互。",
        primaryUserMessage: "给我看看移动端 UI 演示。",
        primaryAssistantMessage: "这是一个本地 UI 演示。聊天、模型控制、侧边栏导航和消息渲染可以使用，但实时桥接调用已关闭。",
        primaryToolMessage: "演示模式：后端、安全配对、Git、支付和桥接源码仍然保留在仓库中。",
        composerUserMessage: "输入框里可以试什么？",
        composerAssistantMessage: "你可以输入提示词、切换计划模式、查看运行参数，并发送一个只在本地生效的消息。回复来自演示状态。",
        sidebarUserMessage: "保留侧边栏交互。",
        sidebarAssistantMessage: "侧边栏使用本地演示线程，所以打开聊天和创建新演示聊天不需要配对电脑。",
        newThreadReady: { projectLabel in
            let suffix = projectLabel?.isEmpty == false ? "（\(projectLabel!)）" : ""
            return "这个本地演示聊天\(suffix)已经准备好。发送内容只保存在本机，并追加模拟助手回复。"
        },
        assistantReply: { trimmed in
            let topic = trimmed.isEmpty ? "这个请求" : "“\(trimmed)”"
            return "这是 \(topic) 的演示回复。当前 app 使用本地模拟状态，没有发起桥接、relay、Git、支付或后端请求。"
        }
    )
}
