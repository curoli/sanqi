# Sanqi mobile prototype

Human and computer Sanqi for Android (API 24+) and iOS (15+). This is a
development prototype; it has not been published to the stores. There are no accounts,
networking or multiplayer services.

## Play

Use the globe-and-flag button in the header to choose **🇬🇧 English**,
**🇩🇪 Deutsch**, **🇮🇩 Bahasa Indonesia**, **🇸🇦 العربية**, **🇨🇳 中文**,
**🇪🇸 Español**, **🇹🇷 Türkçe**, **🇮🇳 हिन्दी**, **🇫🇷 Français**,
**🇧🇩 বাংলা**, **🇵🇹 Português**, **🇵🇰 اردو**, **🇷🇺 Русский**, or
**🇯🇵 日本語**. The header sits in the side panel in
landscape. Without a valid saved language, the app uses the first supported entry in the
system's preferred-language list, matching by language code across regional
variants, and opens the game directly. This automatic default is not saved as an
explicit choice. If none of the system languages is supported, the app asks the
user to choose, initially highlighting English. An explicit saved choice takes
priority over later system-language changes. No location, IP lookup, network
service, or permission request is used. The language chooser also supports
settings-backup restore and stays open with a retryable error if saving fails.
Backup restore and language confirmation share the same onboarding busy guard.
If Back dismisses a restoring backup dialog, the chooser stays disabled until
its writes settle; failures remain visible on the chooser and can be retried.
Changing language
updates controls, status, dialogs, and error summaries without resetting the
game, selection, or computer search. Arabic and Urdu use a right-to-left interface.
The board orientation, coordinates, and canonical movetext remain unchanged;
movetext and support coordinates are displayed left to right. Technical details
reported by Rust or platform storage may retain their original wording.

Language and skin choosers have persistent scrollbars and tappable cues for
choices above and below the viewport. Cues disappear at the corresponding end
and update after scrolling or rotation. They open at the current selection.

Both chooser headers have a **Back up settings** button (save icon). Copy the
backup text into a note or file **outside Sanqi before uninstalling**. After
reinstalling, open that dialog, paste the saved text, and choose Restore. The
portable, versioned backup contains only the language code and skin ID; it
does not contain the game. Use Save / restore separately for game movetext.
Invalid backups are rejected before any settings are applied.

Uninstalling deletes local app data; the app cannot recover settings that have
already been deleted without a backup. Android backup participation is
explicitly enabled, but automatic restore depends on device/account settings,
backup timing and compatible signing identity. No app-managed cloud service is
introduced. Where possible, install updates over the existing app instead of
uninstalling (`adb install -r path/to/app.apk`). This requires matching signing
certificates. GitHub debug builds can use different runner debug keys; if an
update is rejected, copy settings and movetext before uninstalling. For stable signing and release artifacts, see
[Signed Android releases](docs/android-release.md).

**About** opens the app information dialog in the selected language. It shows
Sanqi's pronunciation, the cooperation slogan, the author Oliver A Rübenacker,
the UTC build date and full Git commit, and links to this repository and the
rules in the current language. Links open in the system browser; if opening a
link fails, its address remains available to copy. Opening About leaves the
game and any computer search running.
The rules and repository buttons stay visible in the footer, and the close
button stays in the header. A persistent scrollbar and a localized “More below”
button indicate hidden text; tapping the hint scrolls down. The hint disappears
at the end and updates when the device rotates.

The **palette button** in the header opens the skin chooser. Each entry previews
its colors, pattern, typography, and button styling. Selecting a skin applies it
immediately and saves the choice on the device; closing the chooser keeps the
current skin. The list opens at the current selection and has a persistent
scrollbar. Skin names and controls are translated into all fourteen languages.
Changing skins preserves the game, move selection, computer search, board SVG,
pieces, board labels, and supporting-pivot markers. Linen is the default.

| Skin | Character | Typeface |
| --- | --- | --- |
| Linen | Warm cream and sage, woven diamonds, classical | Lora |
| Porcelain | Cool ivory and navy, clean grid, modern | Inter |
| Mint | Fresh green, soft dots, rounded buttons | Nunito |
| Sakura | Blush pink and plum, delicate circles | Lora |
| Sorbet | Peach and berry, playful confetti | Nunito |
| Lagoon | Aqua and deep teal, flowing waves | Inter |
| Sunflower | Sunny yellow, radiating lines | Nunito |
| Blueprint | Deep blue and cyan, technical grid | Space Mono |
| Arcade | Purple and neon lime, pixel outlines | Space Mono |
| Midnight | Navy and ice blue, quiet stars | Inter |
| Graphite | Charcoal and silver, restrained diagonals | Inter |
| Ember | Dark cocoa and amber, warm rings | Lora |
| Gilded | Ink and gold, formal lattice | Lora |
| Aurora | Dark teal and mint, flowing ribbons | Nunito |

All six font files (four primary families and two Arabic fallbacks) and their
licenses are bundled, adding about 2.6 MB before APK compression. No fonts are
downloaded at runtime. Lora uses Noto Naskh Arabic as its Arabic fallback; other
families use Noto Sans Arabic. Chinese and other missing glyphs use device font
fallback. **Font licenses** in the chooser opens Flutter's license page.
See `assets/fonts/README.md` for pinned upstream sources and checksums. Skins
live in `lib/app_skin.dart`; geometric patterns are drawn in
`lib/game_background.dart`. The defined main text and button color pairs meet
a 4.5:1 contrast ratio, and control borders meet 3:1 against the panel surface.

Use the game-mode dropdown: **Human vs Human**, **Human vs Computer**,
**Computer vs human**, or **Computer vs Computer**. The first player is White;
the second is Black. Changing mode starts a new game. The computer moves first
when you play Black. The board always keeps White at the bottom.
Computer search uses `sanqi-engine` iterative deepening through the asynchronous
Rust bridge, with a thinking indicator. In a computer game, open the speedometer
menu beside the mode selector to choose Standard (up to 600 ms, depth 6),
Strong (2 seconds, depth 8), or Expert (5 seconds, depth 10). Standard is the
default. The device remembers your choice and uses it from the next search.
Every computer turn uses a fresh randomized seed to vary ties in the engine's
root move ordering. This applies to both human/computer and computer/computer
play, including after New Game or a restart. Evaluation scores and tactical
priorities stay unchanged; forced or preferred moves can still repeat. The CLI
and Python bindings keep their existing deterministic search ordering.
New Game, mode changes, and Undo remain available during search. Work runs on a
detached movetext snapshot; Rust revision checks discard outdated/duplicate
results. A service cancellation generation is captured before requesting the
snapshot and checked after the snapshot and search complete. This also cancels
turns whose initial bridge snapshot is still queued when Pause, New Game, Undo,
restore, or a mode change occurs. An interrupted search may finish in the
background but cannot play
into a replacement game. Search failures expose a retry action.

In computer mode Undo takes back your move and the computer's reply, or just
your move if it is still thinking. The computer's opening move alone cannot be
undone; use New Game instead. Local mode still undoes one ply. Mode/color are
stored alongside the movetext preferences, and a restored computer turn resumes
automatically.

Computer vs Computer plays both sides automatically. Pause stops automatic play
and invalidates the outstanding search; Resume continues from the live position.
Undo removes one ply and pauses so the computer does not immediately replay it.
New Game resumes automatic play. The selected mode is saved; spectator play
resumes automatically when the app is reopened.

White is at the bottom and moves first. Tap a current-player piece to select it;
green dots mark destinations supplied by Rust. Tap a destination to move. Tap
the selected piece again or an unrelated square to clear selection.

Press **Example move** to cycle through every legal move in the position,
across all pieces, then wrap back to the first. The inspected move's piece is
selected automatically, without playing a move. An existing selection does not
restrict the cycle. The button is available on human turns with legal moves.
Holding a legal destination also inspects that move.
Blue rings mark supporting pieces and blue dots mark pivots. The compact panel
shows support pairs; hold the text to see every pair, including shared pivots.
Pivot coordinates start at a1=(0,0) and can include halves. Multiple pairs are
alternative supports for one move, not separate moves or a player choice.

New Game resets the position. The canonical Rust movetext
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
The coordinate helper rejects points outside the rectangle. The app fits the
available screen without scrolling, placing controls below or beside the board
to maximize its size. Only the latest moves are shown when space is limited;
Save / restore always contains the complete record. Rust calls are
asynchronous, controls are disabled while a call/save is outstanding, and errors
are visible. Preferences store movetext, mode, language, and skin, never Dart-derived
game state.

Translations live in `lib/l10n/app_*.arb`; `flutter gen-l10n` regenerates the
committed typed Dart files in `lib/l10n/generated`. Add text to all fourteen
catalogs, using placeholders and ICU plurals for dynamic messages. The app uses
the localization delegates exported by `material_ui` and `cupertino_ui`, plus
Flutter's widget delegate. Flutter 3.50's generator still emits references to
the legacy Material/Cupertino delegates in its unused convenience list; the
generated header suppresses that specific deprecation diagnostic. App analysis
still covers the generated translations. iOS advertises all fourteen locales in
`Runner/Info.plist`.

In landscape the logo and title move into the side panel, so the board fills
the safe height apart from an 8-pixel margin. Portrait retains the top header.
A muted diamond pattern sits behind the board and the cream control panel;
buttons and the mode selector have borders and tinted backgrounds.

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
tool/flutter_with_build_info.sh run -d DEVICE_ID
flutter test integration_test/game_test.dart -d DEVICE_ID
tool/flutter_with_build_info.sh build apk --debug --target-platform android-arm64
```

The debug APK is `build/app/outputs/flutter-apk/app-debug.apk`. Install it with
`adb install -r build/app/outputs/flutter-apk/app-debug.apk`. Android installs debug builds as
`com.curoli.sanqi.dev`, with a DEV badge on the launcher icon and a debug label
in About. Release builds use `com.curoli.sanqi`. Both can be installed together
and have separate app data. An Android emulator
also works; choose an ABI matching the Rust target (x86_64 or arm64). No physical
device is required for widget/host bridge tests. For signed release APKs, Play app bundles, and the private upload-key setup, see
[Signed Android releases](docs/android-release.md). Store submission remains a
manual step in Play Console.

Use `tool/flutter_with_build_info.sh` in place of `flutter` for app builds and
device runs to record the actual Git checkout and UTC build time in About.
The wrapper accepts the usual Flutter arguments and works from any directory;
it requires Bash, Git, and Flutter on PATH. It appends `-dirty` to the commit
when tracked files differ from HEAD. Both Android and iOS CI builds use it.
Direct `flutter build`/`flutter run` calls still work, but show “Not recorded
for this build” unless supplied with `--dart-define=SANQI_BUILD_DATE=...` and
`--dart-define=SANQI_GIT_COMMIT=...`. The app never substitutes its launch time
for a missing build date.

Manual device checklist:

- Move for White, then Black; tap opponent pieces and invalid destinations.
- Preview a move, inspect support rings/dots, then play its destination.
- Rotate the device and test a small screen and large text settings.
- Change light/dark skins, reopen the chooser, and restart to check persistence.
- Undo, start a new game, copy a record, and restore it.
- Paste invalid movetext and check that the existing record survives.
- Open About, confirm the build metadata, and open the repository and rules in
  the selected language in the browser.
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
tool/flutter_with_build_info.sh run -d DEVICE_ID
flutter test integration_test/game_test.dart -d DEVICE_ID
tool/flutter_with_build_info.sh build ios --simulator --debug
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
and builds an Android arm64 debug APK. A reusable Android release workflow also
builds signed release APK/AAB artifacts with a disposable CI key and verifies
signatures, native library packaging, and 16 KB alignment. Its manual run uses
private upload-key secrets for distributable artifacts; see the release guide.
A separate macOS job builds an unsigned
iOS simulator app. The existing workspace CI tests every
Rust crate and the minimum compiler; existing Python wheel tests remain intact.
The on-device smoke test requires an attached device/emulator. iOS builds and
physical-device interaction must additionally be verified on macOS/device
hardware; a host test is not a substitute for that validation.

Official references: [Flutter Android setup](https://docs.flutter.dev/platform-integration/android/setup),
[Flutter iOS setup](https://docs.flutter.dev/platform-integration/ios/setup),
[FRB integration](https://cjycode.com/flutter_rust_bridge/manual/integrate).

## Capture Google Play screenshots

Connect an Android phone over USB with USB debugging enabled, unlock it, and
accept the debugging prompt. With Flutter and Android platform tools on your
PATH, run this from the repository root:

```sh
mobile/flutter_app/tool/capture_play_store_screenshots.sh
```

The script builds and runs a debug screenshot entry point on the phone and saves
56 portrait PNGs on the laptop under
`mobile/flutter_app/build/play-store-screenshots/<timestamp>/`. Unlock the phone before running the script. It keeps the screen
awake while
the phone is powered over USB and restores the previous stay-awake setting at
exit, including if the capture fails. Leave the cable connected until the
script exits. To specify a fresh output directory and
select a device explicitly, pass both arguments:

```sh
mobile/flutter_app/tool/capture_play_store_screenshots.sh ./play-screenshots DEVICE_SERIAL
```

Use `adb devices` to find the serial. Each Play Console locale folder (for
example, `en-US`, `de-DE`, or `ja-JP`) contains:

- `01-opening.png` — starting position in Linen, the default theme
- `02-example-move.png` — a human turn in Lagoon, with Example move previewed
- `03-computer-move.png` — a different game in Sakura, with the computer's last move marked
- `04-game-over.png` — a completed game in Midnight

The runner uses fixed Rust game records and a temporary settings store. It
installs as `com.curoli.sanqi.dev`, so the Google Play installation and its
data stay separate. The capture installs a screenshot build over a compatible
existing debug build. Run your usual debug build again when you want to use it.
