# codex app

[![License](https://img.shields.io/badge/License-Apache--2.0-blue.svg)](LICENSE)

`codex app` is an open-source iOS UI demo for controlling Codex from a mobile interface. This fork launches the existing app target in demo mode by default: the frontend, sidebar, composer, model controls, and local chat interactions are active, while live bridge, relay, secure pairing, Git, payment, notification, and backend startup paths are not bootstrapped on launch.

The backend, bridge, secure transport, Git, payment, and core service source code intentionally remain in the repository for inspection and future development.

## Demo Mode

- Seeds local threads, messages, model choices, connection state, and runtime settings.
- Marks onboarding as seen so the app opens directly into the main UI.
- Treats the app as connected without seeding relay/session identifiers.
- Sends prompts to local mock state and appends confirmed user and assistant messages.
- Creates new chats locally from the sidebar.
- Skips RevenueCat bootstrap, notification setup, auto reconnect, QR pairing, and live sync startup.

Demo mode is controlled by `AppDemoMode.isEnabled` in the iOS app source.

## Repository Structure

```text
├── CodexMobile/                  # Xcode project root
│   ├── CodexMobile/              # SwiftUI app source target
│   │   ├── Services/             # Connection, sync, demo, payment, secure transport, and persistence code
│   │   ├── Views/                # SwiftUI screens, sidebar, composer, and timeline components
│   │   ├── Models/               # RPC, thread, message, and UI models
│   │   └── Assets.xcassets/      # App icons and UI assets
│   ├── CodexMobileTests/         # Unit tests
│   ├── CodexMobileUITests/       # UI tests
│   └── BuildSupport/             # Info.plist and build configuration files
├── phodex-bridge/                # Node.js bridge/runtime package retained from the original project
├── Docs/                         # Architecture and self-hosting docs retained for reference
└── Specs/                        # Implementation notes and plans
```

## Build

Open the project in Xcode:

```sh
cd CodexMobile
open CodexMobile.xcodeproj
```

Or build from the command line:

```sh
xcodebuild build \
  -project CodexMobile/CodexMobile.xcodeproj \
  -scheme CodexMobile \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

If your local Xcode has a different simulator set, replace the destination with one returned by:

```sh
xcodebuild -project CodexMobile/CodexMobile.xcodeproj -scheme CodexMobile -showdestinations
```

## Tests

The demo-mode behavior is covered by `CodexDemoModeTests`:

```sh
xcodebuild test \
  -project CodexMobile/CodexMobile.xcodeproj \
  -scheme CodexMobile \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:CodexMobileTests/CodexDemoModeTests
```

## Attribution

This project is based on the original Remodex codebase by Emanuele Di Pietro. The original backend, bridge, mobile service, payment, Git, and secure-pairing implementation are retained in source form, but the published app branding for this fork is `codex app`.

## License

Licensed under Apache-2.0. See [LICENSE](LICENSE).
