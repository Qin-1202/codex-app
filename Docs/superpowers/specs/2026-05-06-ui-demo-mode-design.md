# UI Demo Mode Design

## Goal

Create an open-source iOS UI demo for `codex app` that uses the original Remodex SwiftUI screens and interaction patterns while avoiding live backend, bridge, payment, Git, and Codex runtime dependencies at app launch.

The repository must keep the backend and core logic source code intact. Demo mode should bypass those systems at runtime instead of deleting or rewriting them.

## Recommended Approach

Add a demo mode inside the existing `CodexMobile` iOS app target.

This keeps the app close to the original source and lets the current SwiftUI views keep driving the experience. A separate demo target would provide stronger separation, but it would require more Xcode project changes and would increase drift from the original app. A static showcase app would be simpler but would lose too much of the existing interaction model.

## Runtime Shape

Introduce a small demo-mode boundary near app startup:

- A central `AppDemoMode` or equivalent switch determines whether the app launches in demo mode.
- Demo mode seeds `CodexService` with local mock state before `ContentView` renders.
- Demo mode prevents automatic live bridge connection, QR pairing recovery, RevenueCat bootstrap, and other startup work that requires external services.
- Non-demo mode keeps the existing code path available for future restoration.

## Mock State

Demo mode should populate enough state for the existing UI to feel usable:

- several conversation threads with project names and relative timestamps
- one active thread with user, assistant, reasoning, command, and file-change style messages
- connected or demo-connected status so the chat UI opens instead of forcing setup
- model, reasoning, access mode, and service-tier selections
- no live relay session identifiers or bearer-like pairing values

The mock data should live in focused helpers rather than being scattered through views.

## Interaction Behavior

The UI should preserve local interactions:

- open and close the sidebar
- search and select threads
- navigate to settings
- type into the composer
- change local composer/runtime controls
- submit a demo message and append a local assistant response

Actions that would normally mutate real external state should become harmless demo responses:

- Git write operations should not run.
- network pairing should not start.
- bridge and Codex runtime calls should not be made.
- payment bootstrap should not block app startup.

## Repository And Branding

The new GitHub repository should be open source and titled `codex app` in README-facing copy.

GitHub repository names cannot contain spaces, so the remote repository slug should be `codex-app`. The app display name and README title can still use `codex app`.

## Documentation

Update README content for the forked open-source demo:

- explain that this is a UI-only iOS demo based on the original Remodex source
- state that backend and bridge code are preserved but not used by demo launch mode
- document the Xcode project path and demo run expectation
- avoid implying that a hosted service or production relay is required

## Testing And Verification

Use focused verification:

- add a lightweight unit test for demo seed generation or demo bootstrap behavior
- run the relevant Swift test/build command if available without simulator UI testing
- do not run Xcode UI tests unless explicitly requested

Manual simulator or device testing can be suggested after the code is implemented, but the implementation should not depend on deleting backend code to make the UI run.

## Out Of Scope

- rewriting the UI as a Web app
- deleting bridge, Codex service, payment, or Git action code
- implementing a production backend
- publishing to the App Store
- preserving live Codex runtime functionality in demo mode
