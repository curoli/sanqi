# Sanqi mobile prototype

Local two-player or human-vs-computer Sanqi for Android (API 24+) and iOS (15+). This is a
development prototype, not a signed store release. There are no accounts,
networking or multiplayer services.

## Play

Use the game-mode dropdown to play locally with another person, or against the
computer as White or Black. Changing mode starts a new game. The computer moves
first when you choose Black. The board keeps White at the bottom in both modes.
Computer search uses `sanqi-engine` iterative deepening (depth cap 6, 600 ms
search budget) through the asynchronous Rust bridge, with a thinking indicator.
New Game, mode changes, and Undo remain available during search. Work runs on a
detached movetext snapshot; Rust revision checks discard outdated/duplicate
results. An interrupted search may finish in the background but cannot play
into a replacement game. Search failures expose a retry action.

In computer mode Undo takes back your move and the computer's reply, or just
your move if it is still thinking. The computer's opening move alone cannot be
undone; use New Game instead. Local mode still undoes one ply. Mode/color are
stored alongside the movetext preferences, and a restored computer turn resumes
automatically.

White is at the bottom and moves first. Tap a current-player piece to select it;
green dots mark destinations supplied by Rust. Tap a destination to move. Tap
the selected piece again or an unrelated square to clear selection.

Hold a legal destination or choose a `Preview from-to` chip to inspect a move
without playing it. Blue rings mark supporting pieces and blue dots mark
pivots. The panel lists **every** support pair, including pairs sharing a pivot.
Pivot coordinates start at a1=(0,0) and can include halves. Multiple pairs are
alternative supports for one move, not separate moves or a player choice.

New Game resets the position; Undo removes one ply. The canonical Rust movetext
is saved on the device after each action and restored at startup. Save / restore
lets you copy a record or paste an existing one. An invalid import leaves the
game intact. Storage errors are displayed; play can continue in memory.

## Architecture

`sanqi-core::Game` in `crates/sanqi-mobile` is authoritative. Flutter holds an
opaque Rust session handle and a read-only `GameView`, not a second board/rules
implementation. Rust computes legal moves, applies `Game::play`, queries
supporting pivots, renders SVG via `sanqi-render`, and parses/serializes movetext.
Undo replays the retained moves into a new `Game` (O(n), suitable for this MVP).

The board is always square. Its SVG fills exactly the gesture rectangle with no
letterboxing. Screen row zero maps to rank 8, and the bottom-left maps to a1.
The coordinate helper rejects points outside the rectangle. The app scrolls on
small portrait screens and uses a side panel on wide screens. Rust calls are
asynchronous, controls are disabled while a call/save is outstanding, and errors
are visible. Preferences store only movetext, never Dart-derived game state.

## Linux host setup

Install Git, curl, unzip, a C/C++ build toolchain, Rust via rustup, and Flutter
**3.50.0** (Dart 3.14). Add Flutter's `bin` and `~/.cargo/bin` to PATH. The root
`rust-toolchain.toml` selects the development compiler; Rust 1.88 remains the
workspace minimum. Install a full JDK 21 (not just a JRE) and Android Studio or Android command-line
tools if you want an APK/device run. `flutter doctor -v` identifies missing tools.

From the repository root:

```bash
cargo test --workspace --locked
cargo build -p sanqi-mobile --locked
cd mobile/flutter_app
flutter pub get --enforce-lockfile
flutter analyze
flutter test
```

`test/native_bridge_test.dart` loads the host Linux shared library from
`../../target/debug/libsanqi_mobile.so`. Build it first. Widget tests use a fake
service only to test interaction/layout; the native bridge test exercises the
real generated Dart/Rust API. Linux desktop application support is not part of
this phase.

App analysis excludes `rust_builder/cargokit/**`, a vendored standalone Dart
build-tool package. Its dependencies are bootstrapped by the native build, not
by the app's `flutter pub get`. App code, generated bridge bindings, widget tests,
and device integration tests remain covered by `flutter analyze` on a clean
checkout, before any native build has bootstrapped Cargokit.

## Android SDK and a physical device

In Android Studio's SDK Manager install Android SDK Platform **36**, Build Tools
**36.0.0**, Platform Tools, Command-line Tools, and NDK **28.2.13676358**. Use the
SDK location shown there (typically `$HOME/Android/Sdk`):

```bash
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$ANDROID_HOME/platform-tools:$PATH"
flutter doctor --android-licenses
rustup target add --toolchain stable aarch64-linux-android armv7-linux-androideabi x86_64-linux-android i686-linux-android
flutter doctor -v
```

Review and accept the SDK licenses when prompted. The committed Cargokit plugin
builds/bundles `libsanqi_mobile.so` automatically from the workspace crate; do not
copy native libraries manually. It uses the stable Rust toolchain and the NDK
selected by the app. Gradle and Cargo require network access on the first build.
The bridge runtime and code generator are both pinned to FRB **2.12.0**. The
vendored Cargokit Gradle task uses `ExecOperations` for Gradle 9 compatibility;
the pod builder normalizes Cargo's hyphenated package name to `sanqi_mobile`
when naming the static library.

Enable Developer options and USB debugging on the phone, connect it, and accept
its USB authorization prompt. On Linux you may need your distribution's Android
udev rules. Check that it appears as `device`, not `unauthorized`:

```bash
adb devices
flutter devices
cd mobile/flutter_app
flutter run -d DEVICE_ID
flutter test integration_test/game_test.dart -d DEVICE_ID
flutter build apk --debug --target-platform android-arm64
```

The debug APK is `build/app/outputs/flutter-apk/app-debug.apk`. Install it with
`adb install -r build/app/outputs/flutter-apk/app-debug.apk`. An Android emulator
also works; choose an ABI matching the Rust target (x86_64 or arm64). No physical
device is required for widget/host bridge tests. Release signing and store
submission are intentionally left for a subsequent phase.

Manual device checklist:

- Move for White, then Black; tap opponent pieces and invalid destinations.
- Preview a move, inspect support rings/dots, then play its destination.
- Rotate the device and test a small screen and large text settings.
- Undo, start a new game, copy a record, and restore it.
- Paste invalid movetext and check that the existing record survives.
- Close/relaunch the app and confirm that the game resumes correctly.

## iOS needs macOS and Xcode

Linux cannot build or sign an iOS app. On a Mac install Flutter 3.50.0, Rust,
Xcode with iOS platform/simulator support, and CocoaPods. Complete Xcode's
first-launch setup and license acceptance, and select its command-line tools:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
rustup target add --toolchain stable aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios
cd mobile/flutter_app
flutter pub get --enforce-lockfile
cd ios
pod install
open Runner.xcworkspace
```

Use CocoaPods, not Swift Package Manager, for the bundled Cargokit plugin; this
choice is configured per app in pubspec.yaml. The pod script builds and links
the Rust static library using Xcode's active architecture and SDK. For a real
phone choose your own Apple development team and a unique bundle identifier in
Xcode, enable Developer Mode on the phone, and trust the signing certificate.
Start an iOS simulator through Xcode (Simulator/Device Hub, depending on the
Xcode version), then use `flutter devices` and:

```bash
flutter run -d DEVICE_ID
flutter test integration_test/game_test.dart -d DEVICE_ID
flutter build ios --simulator --debug
```

On macOS, run the pure widget tests with
`flutter test test/game_screen_test.dart`; the host `.so` test is Linux-specific.
Physical iOS device builds need Apple signing; simulator builds do not. App Store
release builds also need the appropriate Apple Developer account/provisioning.

## Regenerating the bridge

Generated files are committed so app users need no code generator. After a Rust
API change, use matching versions:

```bash
cargo install flutter_rust_bridge_codegen --version 2.12.0 --locked
cargo install cargo-expand --locked
cd mobile/flutter_app
flutter pub get
flutter_rust_bridge_codegen generate --stop-on-error
dart format lib test integration_test
```

The config points at `../../crates/sanqi-mobile`; do not create a duplicate Rust
crate under this app. `rust_builder` is only native build glue. Retain the
vendored Cargokit license. Existing CLI/Python APIs are unchanged.

## CI and validation limits

The Mobile workflow analyzes the app, runs widget and real Linux bridge tests,
and builds an Android arm64 debug APK. A separate macOS job builds an unsigned
iOS simulator app. The existing workspace CI tests every
Rust crate and the minimum compiler; existing Python wheel tests remain intact.
The on-device smoke test requires an attached device/emulator. iOS builds and
physical-device interaction must additionally be verified on macOS/device
hardware; a host test is not a substitute for that validation.

Official references: [Flutter Android setup](https://docs.flutter.dev/platform-integration/android/setup),
[Flutter iOS setup](https://docs.flutter.dev/platform-integration/ios/setup),
[FRB integration](https://cjycode.com/flutter_rust_bridge/manual/integrate).
