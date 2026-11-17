# Signed Android releases

Sanqi's application ID is `com.curoli.sanqi`. This preparation builds release
artifacts; it does not publish them or configure the Play store listing.
Debug builds remain available without credentials. Release tasks, including
those reached through aggregate Gradle tasks, fail without all four signing
variables. There is no debug-key fallback.

## 1. Create and back up your upload key once

On Debian, install a full JDK (the project uses JDK 21) so `keytool` is available.
Run these commands in your own terminal. Choose passwords when prompted; do not
put passwords in shell commands, chat, Git, or a pull request.

```bash
install -d -m 700 "$HOME/.local/share/sanqi-signing"
(umask 077; keytool -genkeypair -v \
  -keystore "$HOME/.local/share/sanqi-signing/upload.jks" \
  -storetype JKS -alias upload -keyalg RSA -keysize 2048 -validity 10000)
```

Keep an encrypted backup of this file and its alias/passwords in a separate,
secure location. Reuse this upload key for subsequent submissions. Do not
regenerate it for each build. Android keystore files are ignored by Git, but
keeping the real key outside the checkout is preferable.

With **Play App Signing**, this key authenticates your uploads. Google manages
the app signing key used for APKs installed from Google Play. They are separate
roles. Choose Play App Signing when setting up the first Play release.

## 2. Configure GitHub's private repository secrets

In **Settings → Secrets and variables → Actions → New repository secret**, add:

| Secret | Value |
| --- | --- |
| `SANQI_ANDROID_KEYSTORE_BASE64` | Base64 encoding of the complete upload keystore |
| `SANQI_ANDROID_STORE_PASSWORD` | Keystore password |
| `SANQI_ANDROID_KEY_ALIAS` | `upload` if you used the command above |
| `SANQI_ANDROID_KEY_PASSWORD` | Key password (possibly the same as the store password) |

Passwords and alias must be single-line values. Base64 is an encoding, not
encryption: treat the encoded file as private too. To avoid printing it in a
terminal or putting it in a tracked file, authenticated GitHub CLI users can run:

```bash
base64 -w 0 "$HOME/.local/share/sanqi-signing/upload.jks" |
  gh secret set SANQI_ANDROID_KEYSTORE_BASE64 --repo curoli/sanqi
```

For the other three secrets, GitHub's web form or `gh secret set NAME` provides
private input. Do not upload your keystore as a workflow artifact.

## 3. Build through GitHub Actions

After this change is merged into `main`, open **Actions → Android release →
Run workflow**, choose `main`, and enter an unused, increasing build number
(start with `1` if nothing has been uploaded). This becomes Android's version
code; the visible version name remains in `pubspec.yaml`. This workflow accepts
positive version codes up to nine digits. Never reuse a version code already
uploaded to Play.

The workflow builds a universal release APK and an Android App Bundle, checks
APK and bundle signatures, checks that Flutter and Rust libraries are present
for arm64, armv7, and x86_64, and verifies 16 KB ELF load alignment for all bundled
64-bit libraries plus APK ZIP alignment. It records build date and Git revision
in About. Credentials are loaded only for manual builds; the runner's keystore
is removed even on failure. No Play credentials or automated upload are needed.

Download and extract the **sanqi-android-release** artifact (retained 14 days):

- `app-release.aab`: upload to Google Play Console's internal/closed test track.
  An AAB cannot be installed directly on a phone.
- `app-release.apk`: install directly for a release-mode smoke test.

Pull requests and pushes to `main` also exercise this build using a disposable
CI key. Their **sanqi-android-signing-check** artifact is for build verification
only; do not submit it to Play or use it for stable device updates. Real signing
secrets are not passed to PR builds.

## 4. Test and distribute

Before replacing an existing debug installation, copy its settings backup and
saved game movetext somewhere outside Sanqi. The release certificate differs
from the debug certificate, so Android normally requires uninstalling the debug
app first, which deletes its local data. Restore the backups afterwards.

```bash
adb install -r path/to/app-release.apk
```

Check moves, computer play, Undo, rotation, language and skin persistence,
background/resume, and About's build metadata. Test on a 16 KB Android emulator
or device as well; static alignment checks do not replace runtime testing.

In Play Console, complete account verification, app setup, store listing,
privacy policy, content rating, and Data Safety declarations. Start with an
internal test for yourself, then publish a closed test for the recruited testers.
If you switch from internal to closed testing, opt out of the internal test
before joining the closed one. Send testers the closed-test opt-in link; an
emailed APK or GitHub download does not enroll them in that test.

Google Play installations use the Play app signing certificate. A directly
installed upload-key APK may therefore require uninstalling before switching
to Play, even though both are release builds. Back up settings and games first.
Use Google Play's test track to validate the actual delivery/update path.

## Optional: build locally on Debian

Install the Flutter/Android/Rust tooling listed in the parent README, then set
these variables in your own terminal. Passwords are read without echo and are
not added to shell history:

```bash
export SANQI_ANDROID_KEYSTORE_PATH="$HOME/.local/share/sanqi-signing/upload.jks"
export SANQI_ANDROID_KEY_ALIAS=upload
read -r -s -p 'Keystore password: ' SANQI_ANDROID_STORE_PASSWORD; echo
read -r -s -p 'Key password: ' SANQI_ANDROID_KEY_PASSWORD; echo
export SANQI_ANDROID_STORE_PASSWORD SANQI_ANDROID_KEY_PASSWORD
cd mobile/flutter_app
flutter pub get --enforce-lockfile
tool/flutter_with_build_info.sh build appbundle --release --build-number=1
tool/flutter_with_build_info.sh build apk --release --build-number=1
python3 tool/verify_android_release.py
unset SANQI_ANDROID_STORE_PASSWORD SANQI_ANDROID_KEY_PASSWORD
```

Use an absolute keystore path. Outputs are under
`build/app/outputs/bundle/release/` and `build/app/outputs/flutter-apk/`.
The Python checker verifies packaging/ELF alignment; the GitHub workflow also
runs Android's `apksigner`, `zipalign`, and Java's `jarsigner`.

References: [Flutter release signing](https://docs.flutter.dev/deployment/android),
[Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756),
[Google Play test tracks](https://support.google.com/googleplay/android-developer/answer/9845334),
[16 KB page compatibility](https://developer.android.com/guide/practices/page-sizes).
