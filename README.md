<p align="center">
  <img src="docs/images/why-awake-icon.png" width="96" alt="Why Awake app icon">
</p>

# Why Awake

Why Awake is a SwiftUI macOS app for answering a specific question: why is the display, or the whole Mac, still awake?

It reads macOS power assertions, groups the useful blockers, and shows the likely owner, assertion type, reason, and duration. It can open or quit an owning user app when that is safe. It does not claim to revoke another app's assertion.

![Why Awake dashboard](docs/images/why-awake-dashboard.png)

## What It Shows

- Display sleep and system sleep status.
- The app, daemon, or kernel assertion currently blocking sleep.
- Lower-signal assertions, such as user activity or device state, behind a filter.
- Plain-language explanations for common assertion types.
- Safe actions for user apps: open, quit, or explicit force quit.
- Why Awake's own keep-awake toggles, separate from assertions owned by other apps.

![Why Awake explanation tab](docs/images/why-awake-explainer.png)

## What It Will Not Do

- It will not pretend to revoke another app's assertion directly.
- It will not kill system processes by default.
- It will not hide force quit behind an automatic action.

## Data Sources

- `pmset -g assertions` for active power assertions.
- `pmset -g custom` for display and system sleep timers.
- `pmset -g ps` to choose the active power source timer.
- `ioreg -c IOHIDSystem -r` for HID idle time used in sleep estimates.

## Build And Run

```sh
xcodebuild -list -project "Why Awake.xcodeproj"
./script/build_and_run.sh
```

Useful run modes:

```sh
./script/build_and_run.sh --verify
./script/build_and_run.sh --logs
```

The app target is `Why Awake` and the bundle identifier is `pt.z2.Why-Awake`.

## Tests

Run the unit suite:

```sh
xcodebuild test -project "Why Awake.xcodeproj" -scheme "Why Awake" -destination "platform=macOS" -derivedDataPath /private/tmp/whyawake-dd CODE_SIGNING_ALLOWED=NO -only-testing:"Why AwakeTests"
```

Run one focused test class:

```sh
xcodebuild test -project "Why Awake.xcodeproj" -scheme "Why Awake" -destination "platform=macOS" -derivedDataPath /private/tmp/whyawake-dd CODE_SIGNING_ALLOWED=NO -only-testing:"Why AwakeTests/PowerSettingsParserTests"
```

## CI/CD

GitHub Actions are configured for:

- CI on pull requests and pushes to `main`, running the unit test suite on macOS.
- Release publishing on `v*` tags, running tests, building a Release app, packaging both a zip and drag-to-Applications DMG, and attaching them to a GitHub Release.

Create a release by pushing a version tag:

```sh
git tag v1.0.0
git push origin v1.0.0
```

Build the same unsigned release zip and DMG locally:

```sh
VERSION=v1.0.0 ./script/package_release.sh
```

The generated GitHub release asset is unsigned by default. Developer ID signing and notarization should be added only after Apple Developer credentials and notarization secrets are available in the repository.

## Project Map

- `Why Awake/Models`: immutable app data for blockers, snapshots, power settings, history, and keep-awake state.
- `Why Awake/Services`: command execution, `pmset` parsing, app actions, notifications, persistence, and keep-awake control.
- `Why Awake/Stores/WhyAwakeStore.swift`: main app state, refresh loop, history, actions, notifications, and keep-awake coordination.
- `Why Awake/Views`: dashboard, blocker list, detail inspector, menu bar UI, settings, tutorial, and about window.
- `Why Awake/Support/SleepBlockerKnowledge.swift`: assertion explanations, common blocker text, and lower-signal filtering.
- `Why AwakeTests`: parser, policy, and store tests.
