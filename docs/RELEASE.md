# FinRoot Mobile — release runbook (M20)

**Date:** 2026-09-10 · How to cut a store build of FinRoot for Android and iOS.

> **This runbook has not been executed.** The build machine has no Android SDK
> and no macOS/iOS toolchain (M2 I-1, confirmed again at M19). Every command
> below is written from the toolchain docs and the repo's config; the person who
> runs it first should expect to correct small things and update this file.
>
> **The gate for shipping is the M19 §5 device checklist, run on real hardware.**
> Do not submit to either store until that checklist passes.

---

## 0. Prerequisites

| | Android | iOS |
|---|---|---|
| Toolchain | Flutter 3.47.2, Android SDK (API 35+), JDK 17 | Flutter 3.47.2, Xcode 16+, a Mac, an Apple Developer account |
| Store account | Google Play Console, app created as `com.finroot.mobile` | App Store Connect, app record for `com.finroot.mobile` |
| Signing | upload keystore + Play App Signing enrolled | Apple Distribution cert + "FinRoot App Store" provisioning profile |
| Config | `config/prod.json` (git-ignored) with the **prod** Supabase URL + anon key | same |

```bash
# from repo root, once per machine
cp config/prod.example.json config/prod.json     # then fill in real prod values
flutter --version                                 # expect 3.47.2 / Dart 3.13.2
flutter doctor                                    # Android + (on Mac) iOS rows must be green
```

`config/prod.json` must use the **anon / publishable** key. A `service_role`
key in a build is a P0 — `AppConfig.assertValid` rejects privileged keys (M18
F-4), but do not rely on that.

---

## 1. Pre-flight checks (every release)

```bash
flutter analyze
flutter test
dart format --set-exit-if-changed lib test
```

All three must be clean. As of M19: analyze clean, **517 tests** passing.

Then confirm:

- [ ] `pubspec.yaml` `version:` bumped per §Versioning
- [ ] `docs/COMPLIANCE.md` open items R-M20-1..6 resolved or explicitly accepted
- [ ] Privacy-policy URL is live (`docs/PRIVACY_POLICY.md` reviewed + hosted)
- [ ] App icon is the real FinRoot icon, not the Flutter default (§Icon)
- [ ] Store listing finalised (`docs/STORE_LISTING.md`)
- [ ] Review test account exists in the **prod** Supabase project and is seeded
- [ ] `finroot://auth-callback` is in the prod Supabase Auth redirect allow-list
      (**web-owner config task**, tracked in memory)

---

## 2. Versioning

`pubspec.yaml` → `version: <name>+<code>`.

- **`<name>`** (`1.0.0`) — semver, user-visible. Bump per marketing/product:
  patch for fixes, minor for features, major for a redesign.
- **`<code>`** (`+1`) — a monotonic integer. **Increment on every upload to
  either store**, even a re-upload of the same version name. Never reuse or
  decrease it. Android `versionCode` and iOS `CFBundleVersion` both derive from
  it.

First submission: `1.0.0+1` (current value — leave as-is for the first cut).
Overridable at build time: `--build-name=1.0.1 --build-number=7`.

Tag the release commit: `git tag v1.0.0+1 && git push --tags`.

---

## 3. App icon  ·  **BLOCKER for first release**

The app still ships the default Flutter launcher icon on both platforms. Before
any public build:

1. Get a 1024×1024 PNG master of the FinRoot mark (no alpha for iOS; a
   full-bleed foreground + background for the Android adaptive icon).
2. Add `flutter_launcher_icons` and generate:
   ```yaml
   # pubspec.yaml (dev_dependencies)
   flutter_launcher_icons: ^0.14.4
   # pubspec.yaml (top level)
   flutter_launcher_icons:
     android: true
     ios: true
     image_path: "assets/branding/icon-1024.png"
     adaptive_icon_background: "#<brand-bg-hex>"
     adaptive_icon_foreground: "assets/branding/icon-foreground.png"
     remove_alpha_ios: true
   ```
   ```bash
   dart run flutter_launcher_icons
   ```
3. Commit the generated `mipmap-*` / `AppIcon.appiconset` changes.
4. Verify on a device — the adaptive icon mask and the iOS icon corners.

---

## 4. Android — build & upload

### 4.1 One-time: upload keystore + Play App Signing

```bash
keytool -genkey -v -keystore finroot-upload.jks -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 -alias finroot-upload
```

Store `finroot-upload.jks` **outside the repo**. In Play Console → *Setup → App
signing*, enrol in **Play App Signing** (Google holds the real app signing key;
you upload with the upload key).

Create `android/key.properties` from `android/key.properties.example` and point
`storeFile` at the `.jks`. `android/key.properties` and `*.jks` are git-ignored.

`android/app/build.gradle.kts` already wires this: with `key.properties` present
the release build uses it; without it, the build falls back to the debug keystore
so CI/dev still compiles.

### 4.2 Build the app bundle

```bash
flutter build appbundle --release \
  --dart-define-from-file=config/prod.json \
  --obfuscate --split-debug-info=build/symbols
```

Output: `build/app/outputs/bundle/release/app-release.aab`.
Keep `build/symbols/` — upload it to Play for crash de-obfuscation.

> **Code shrinking (R8) is OFF** (`isMinifyEnabled = false`). To enable it, flip
> the flag in `android/app/build.gradle.kts`, keep `proguard-rules.pro`, and
> **re-run the full M19 §5 device checklist** — the native plugins have never
> been shrink-tested. Do this as its own change, not bundled with a release.

### 4.3 Verify before upload

- [ ] `bundletool build-apks --bundle=app-release.aab --output=t.apks` succeeds
- [ ] install the universal APK on a device → cold start → sign in → real balance
- [ ] `adb shell dumpsys package com.finroot.mobile | grep versionCode` matches
- [ ] `adb shell bmgr` / backup test: `allowBackup=false` honoured (M19 §5)
- [ ] pull `finroot.sqlite`, confirm bytes are not `SQLite format 3` (M19 §5)

### 4.4 Upload

Play Console → *Production* (or *Internal testing* first — recommended for v1) →
create release → upload the `.aab` and the symbols zip → fill the release notes →
complete *Data safety* (`docs/COMPLIANCE.md` §2), *Content rating* (§5),
*Ads: No*, *Target audience: not children*, *Privacy policy URL*, *US export
laws* checkbox (§4) → roll out.

---

### Payment detection and side-loaded APKs

Payment detection (the "₹500 paid — add to FinRoot?" pop-up) needs Android's
notification access. **Google Play Protect blocks any app installed outside the
Play Store that asks for it** ("App blocked to protect your device" — the India
fraud-protection rule), so release builds leave the `PaymentListenerService` out
by default (`android/app/src/noPaymentDetection/AndroidManifest.xml`). The app
then reports `included: false`, and the Detected payments screen explains how to
**share a bank SMS to FinRoot** instead: Messages → long-press → Share → "Add to
FinRoot" opens Quick Add filled in (an `ACTION_SEND` text/plain target on
`MainActivity`; no permission, so it is in every build).

`windows-installer\work\apk-build.ps1` builds both APKs for a release:
`Finroot_Version_<v>.apk` (the default above, installs anywhere) and
`Finroot_Version_<v>_auto-detect.apk` (with the listener; installs via ADB, the
Play Store, or with Play Protect off). Same key and versionCode, so either
installs over the other. `-NoAutoDetect` builds the first only.

```bash
# Side-loaded APK (default): no notification access, installs cleanly.
flutter build apk --release --dart-define-from-file=config/dev.json

# Play Store build WITH payment detection (declare notification access in
# Play Console first):
flutter build appbundle --release --dart-define-from-file=config/prod.json --android-project-arg=finroot.paymentDetection=true
```

Debug builds always include it.

## 5. iOS — build & upload  (Mac only)

### 5.1 One-time: signing

- App Store Connect: create the app record for `com.finroot.mobile`.
- Certificates: an **Apple Distribution** certificate.
- Profile: an **App Store** provisioning profile for `com.finroot.mobile`, named
  `FinRoot App Store` (matches `ios/ExportOptions.plist`).
- `cp ios/ExportOptions.plist.example ios/ExportOptions.plist` and fill in
  `teamID`. It is git-ignored.
- In `ios/Runner.xcodeproj`, the Runner target: set the team; switch
  `CODE_SIGN_STYLE` to `Manual` for Release if using the export plist above
  (currently `Automatic`).

### 5.2 Build the IPA

```bash
flutter build ipa --release \
  --dart-define-from-file=config/prod.json \
  --obfuscate --split-debug-info=build/symbols \
  --export-options-plist=ios/ExportOptions.plist
```

Output: `build/ios/ipa/finroot_mobile.ipa`.

### 5.3 Upload

```bash
xcrun altool --upload-app -f build/ios/ipa/finroot_mobile.ipa \
  -t ios -u <apple-id> -p <app-specific-password>
# or: open build/ios/archive/*.xcarchive in Xcode Organizer → Distribute
```

Then in App Store Connect:

- [ ] **App Privacy** answers from `docs/COMPLIANCE.md` §3
- [ ] **Export compliance**: `ITSAppUsesNonExemptEncryption` is `true` in
      `Info.plist`; upload the mass-market self-classification documentation
      (`docs/COMPLIANCE.md` §4) so review isn't blocked per-build
- [ ] Age rating 4+ (§5), "Made for Kids" **off**
- [ ] Screenshots (6.7" iPhone + 13" iPad), description, keywords, support &
      privacy URLs from `docs/STORE_LISTING.md`
- [ ] App Review notes with the test account
- [ ] Submit for review

---

## 6. The ship gate — M19 §5 device checklist

Copied here so it lives with the runbook. **All must pass on real hardware
before public rollout** (staged / internal-testing rollout to run the checklist
is fine and encouraged).

**Smoke:** cold start → auth → Home with a real balance · rotate every tab
portrait↔landscape · resize across 600 & 840 dp on a tablet/foldable ·
pull-to-refresh flips the sync chip.

**Offline:** airplane mode → add expense/transfer/income → each "Pending"
instantly · force-quit + reopen offline → rows still there · reconnect → banner
clears, markers gone, `dashboard_summary` refreshes · edit then delete a synced
row offline → reconnect → server matches · two devices, same row edited offline
on both → reconnect → last-write-wins, no dupes.

**Native seams:** grant then deny notification permission; a recurring item due
tomorrow schedules a local notification; reboot → it still fires · Bill scan:
camera + gallery; `scan-receipt` returns; approve → one expense in the ledger ·
Voice: "spent 250 rupees on groceries yesterday" → form pre-filled → confirm ·
open a password-reset email link → app opens on the reset screen → new password →
signed in · background during a sync → return → resumes; overnight → `workmanager`
ran.

**Encryption / sign-out:** pull `finroot.sqlite` → not plaintext · sign out →
file + keystore entries gone · airplane-mode sign-out also wipes · reinstall →
no previous-user data.

**iOS:** repeat Smoke + Offline + deep link + Dynamic Type at max · VoiceOver:
amount reads "Expense …", a transaction row is one item, the sync banner
announces.

**Store readiness:** `allowBackup=false` verified via `adb shell bmgr` ·
`ITSAppUsesNonExemptEncryption` set + export compliance answered.

---

## 7. Post-release

- [ ] Tag pushed (`v<name>+<code>`)
- [ ] `build/symbols/` archived somewhere durable per release
- [ ] Bump `pubspec.yaml` build number for the next cycle
- [ ] Watch Play pre-launch report + App Store Connect crash reports for the
      device seams that were never CI-verified (notifications, workmanager,
      camera, mic, deep link)
