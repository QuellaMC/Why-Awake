# Why Awake Codex Guide

## Project

Why Awake is a SwiftUI macOS app that explains why the display or the whole Mac is staying awake. It reads macOS power assertions, groups useful blockers, shows the likely display/system sleep cause, and offers safe actions such as opening or quitting the owning app. Why Awake must not imply it can revoke another app's assertion directly.

## Architecture

- `Why Awake/Models`: immutable app data, including blockers, snapshots, keep-awake state, and power settings.
- `Why Awake/Services`: macOS integration and parsing layers. Keep command execution behind protocols so tests can use static or in-memory clients.
- `Why Awake/Stores/WhyAwakeStore.swift`: main `@MainActor` app state, refresh loop, actions, history, notifications, and keep-awake coordination.
- `Why Awake/Views`: SwiftUI dashboard, blocker list, detail inspector, menu bar UI, and settings.
- `Why Awake/Support/SleepBlockerKnowledge.swift`: assertion explanations, common-blocker text, and lower-signal filtering.
- `Why AwakeTests`: parser, policy, and store tests. Add tests next to the layer being changed.

## Development Workflow

Use TDD for behavior changes:

1. Add or update a focused test that demonstrates the bug or expected behavior.
2. Run the smallest matching test target and confirm it fails for the right reason.
3. Implement the smallest maintainable fix in the relevant layer.
4. Re-run the focused test, then the full unit suite.
5. Keep unrelated refactors and generated churn out of the change.

Prefer narrow, future-proof seams:

- Parse `pmset` output in parser types, not SwiftUI views.
- Keep macOS command calls in service clients, not stores or views.
- Keep UI copy derived from store/model state.
- Treat Apple/system assertions separately from user apps.
- Do not kill system processes by default.
- Force quit must stay explicit and warned in UI.

## Build, Run, Test

Project type: Xcode macOS app.

Main scheme:

```sh
xcodebuild -list -project "Why Awake.xcodeproj"
```

Run from Codex or terminal:

```sh
./script/build_and_run.sh
```

Verify launch:

```sh
./script/build_and_run.sh --verify
```

Stream app logs:

```sh
./script/build_and_run.sh --logs
```

Run all unit tests:

```sh
xcodebuild test -project "Why Awake.xcodeproj" -scheme "Why Awake" -destination "platform=macOS" -derivedDataPath /private/tmp/whyawake-dd CODE_SIGNING_ALLOWED=NO -only-testing:"Why AwakeTests"
```

Run a focused test class:

```sh
xcodebuild test -project "Why Awake.xcodeproj" -scheme "Why Awake" -destination "platform=macOS" -derivedDataPath /private/tmp/whyawake-dd CODE_SIGNING_ALLOWED=NO -only-testing:"Why AwakeTests/PowerSettingsParserTests"
```

The Codex Run button is configured in `.codex/environments/environment.toml` and points to `./script/build_and_run.sh`.

## macOS Data Sources

- `pmset -g assertions`: active sleep assertions.
- `pmset -g custom`: battery and AC display/system sleep timers.
- `pmset -g ps`: current power source. Use it to choose battery vs power adapter timers.
- `ioreg -c IOHIDSystem -r`: HID idle time for "Sleep in about ..." estimates.

When showing remaining sleep time, choose the timer for the active power source first. Fall back only when the active-source section is missing.
