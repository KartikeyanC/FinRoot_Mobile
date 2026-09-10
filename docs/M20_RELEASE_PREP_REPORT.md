# M20 — Release preparation · completion report

**Date:** 2026-09-10 · **Status:** complete for everything doable without a
device / store account / designer. The residue is a **submission checklist** for
whoever holds those (§6) plus the M19 §5 device checklist, which is still the
ship gate. **Final milestone — 20 of 20.**
**Repo:** `F:\Movie\AK\Finroot App` · builds on `c1eca34` (M19)

---

## 1. Scope

M20 in the M1 plan: "Release prep — store metadata/screenshots, Android keystore
+ iOS provisioning signing, version/build numbers, export-compliance +
`ITSAppUsesNonExemptEncryption` declarations, build runbook; gate = §5 device
checklist run on real hardware."

Same constraint as M2–M19: **no Android SDK, no Mac, no store accounts, no brand
icon asset.** So M20 delivers the parts that are text and config — the signing
*scaffold*, the compliance *answers*, the listing *copy*, the *runbook* — and
hands over a single ordered checklist for the parts that need credentials and
hardware.

**No app-source behaviour change. No new dependency. No backend change.**
Two build-config files touched (`android/app/build.gradle.kts`,
`ios/Runner/Info.plist`), the rest is new scaffolding + docs.

---

## 2. Signing scaffold

### Android — `android/app/build.gradle.kts`

Replaced the template's "sign release with the debug key / TODO" block with a
real release `signingConfig` that loads `android/key.properties`:

- `key.properties` **present** → release build signs with the upload keystore;
- `key.properties` **absent** (this machine, CI without secrets) → falls back to
  the debug keystore so `flutter build appbundle --release` still compiles and
  `flutter run --release` still works.

New files:
- `android/key.properties.example` — template + the `keytool` one-liner + a note
  to enrol in Play App Signing.
- `android/app/proguard-rules.pro` — keep rules for every native plugin the app
  adds (flutter_local_notifications, workmanager, speech_to_text, sqlite3,
  flutter_secure_storage, OkHttp). **Wired but dormant:** `isMinifyEnabled` is
  explicitly `false` — R8 has never been run against these plugins on a device,
  so a shrunk build is unverifiable here. `RELEASE.md` §4.2 says to enable it
  only as its own change with the full device checklist.

`.gitignore` now excludes `key.properties`, `*.jks`, `*.keystore`, `*.p12`,
`*.p8`, `*.mobileprovision`, `ios/ExportOptions.plist`, and a stray
`GoogleService-Info.plist`.

### iOS

- `ios/ExportOptions.plist.example` — App Store export options (method,
  team id placeholder, manual signing, `FinRoot App Store` profile name, dSYM
  upload). Copied to the git-ignored real file on the Mac.
- `ios/Runner/Info.plist` — **`ITSAppUsesNonExemptEncryption` = `true`** added
  (R-M18-3). Rationale in the plist comment and `COMPLIANCE.md` §4: the app
  bundles AES-256 local-DB encryption (SQLite3MultipleCiphers, M4) on top of
  HTTPS, which is non-exempt cryptography. `true` is the conservative, honest
  default; flipping to `false` needs written legal sign-off.

The Runner target's `CODE_SIGN_STYLE` is still `Automatic` — `RELEASE.md` §5.1
notes the switch to `Manual` if the export plist is used.

---

## 3. Compliance pack — `docs/COMPLIANCE.md`

All **derived from the codebase** (deps, egress, manifests), all engineering
input to a legal review, not the review:

- **Data inventory** — email (auth), financial records (encrypted local cache +
  shared Supabase), receipt images (transient, to the `scan-receipt` function),
  mic audio (on-device only). No ad id, no analytics/crash SDK, no location,
  no third-party trackers. Only egress is `*.supabase.co`.
- **Google Play Data safety** — full table: Email + "Other financial info"
  collected (not *shared* — Supabase is a processor), Photos processed
  ephemerally, everything else "No". Security: encrypted in transit + at rest,
  data-deletion route.
- **Apple App Privacy labels** — Email + Financial Info + Photos, all "linked to
  you / App Functionality", none used for tracking. Audio deliberately not
  declared (on-device) with a flag to revisit if a network recogniser is ever
  used.
- **Export compliance** — the non-exempt-encryption finding, the required BIS
  self-classification + annual report + French declaration, and the per-build
  vs. once-a-year documentation choice in App Store Connect.
- **Content rating** — Everyone / 4+; "Made for Kids" off.
- **Permissions ledger** — every Android permission and iOS usage string, its
  trigger, and its user-facing text.
- **7 open items** R-M20-1..6 for the release owner (privacy URL, deletion URL,
  export filings, DPA confirmation, the `onDevice: true` speech tweak, the final
  encryption-flag call).

---

## 4. Store listing — `docs/STORE_LISTING.md`

Submittable draft copy, matched to what the app actually does at M19:

- Identity table (name **FinRoot**, ids, category Finance, free/no-ads/no-IAP).
- **Play**: 30-char name, 80-char short description, full description (~1900
  chars), Data-safety pointer.
- **App Store**: name, subtitle, promo text, 4000-char description, 100-char
  keyword string, support/marketing/privacy URL slots, App Review notes with a
  test-account placeholder.
- **Assets checklist** — every graphic with its spec and a ❌: the app icon is
  still the Flutter default (flagged **BLOCKER**), and no screenshots can be
  produced without a device/Mac. Includes a 5-frame screenshot plan + captions
  for when hardware exists.

---

## 5. Runbook + privacy policy

- **`docs/RELEASE.md`** — end-to-end: prerequisites, pre-flight checks
  (`analyze`/`test`/`format` + a readiness list), the versioning rule
  (`name+code`, bump `code` every upload), the app-icon procedure
  (`flutter_launcher_icons`), Android AAB build + keystore + Play upload with
  verification steps, iOS IPA build + signing + App Store Connect, the M19 §5
  device checklist reproduced inline as the ship gate, and post-release steps.
  Every command is annotated **"not executed here"**.
- **`docs/PRIVACY_POLICY.md`** — a complete draft in policy voice (who we are,
  what's collected and why, where data lives, processors named, user choices,
  children, contact), clearly marked DRAFT pending legal review + hosting.

---

## 6. Handover checklist (needs credentials / hardware / design)

Ordered. Nothing below can be done from this repo alone.

**Design**
- [ ] FinRoot app-icon master (1024²) → run `flutter_launcher_icons`
      (`RELEASE.md` §3) — **blocks first submission**

**Legal / privacy** (`COMPLIANCE.md` §7)
- [ ] Review + host `PRIVACY_POLICY.md` at a public URL (R-M20-2)
- [ ] Provide the account-deletion URL for Play Data safety (R-M20-3)
- [ ] File the BIS mass-market self-classification + set the annual reminder
      (R-M20-4)
- [ ] Confirm the Supabase DPA / sub-processor docs support "collected, not
      shared" (R-M20-5)
- [ ] Sign off `ITSAppUsesNonExemptEncryption` final value (R-M20-6)

**Backend config** (web-owner)
- [ ] Add `finroot://auth-callback` to the Supabase Auth redirect allow-list
      (additive, no web impact — tracked in memory since M3)
- [ ] Apply the M1.5 migration (`apply_transaction_mutation` + `client_mutations`)
      — still pending web-owner review; not an M20 blocker but the idempotent-
      write path stays inert until it lands

**Store setup**
- [ ] Play Console app record `com.finroot.mobile`; App Store Connect app record
- [ ] Upload keystore + Play App Signing enrolment (`RELEASE.md` §4.1)
- [ ] Apple Distribution cert + `FinRoot App Store` provisioning profile
- [ ] Seed a review/test account in the **prod** Supabase project
- [ ] Paste listing copy + screenshots from `STORE_LISTING.md`

**The gate**
- [ ] **Run the M19 §5 device checklist on real Android + iOS hardware.**
      No public rollout until it passes. Internal-testing / TestFlight builds to
      run it against are expected and encouraged.

---

## 7. Verification done here

| | |
|---|---|
| `flutter analyze` | clean (no Dart changed) |
| `flutter test` | 517 passing, unchanged from M19 (no Dart changed) |
| `android/app/build.gradle.kts` | reviewed by hand — Kotlin DSL, `rootProject.file("key.properties")` resolves to `android/key.properties`; fallback path exercised on this machine at the next `flutter run` |
| Gradle release build | **not run** — no Android SDK |
| iOS archive | **not run** — no Mac |
| `Info.plist` | well-formed; new key placed in the top dict |

---

## 8. Phase status — project complete

| Phase | | Status |
|---|---|---|
| M1 – M17 | foundation → features → tablet → a11y | ✅ |
| M18 | Security review + fixes | ✅ |
| M19 | Full test pass — encryption proven, offline loop + layout matrix, 517 tests | ✅ |
| **M20** | **Release prep** — signing scaffold, compliance pack, store copy, runbook | ✅ **complete** (§6 is the credentialed-owner handover) |
| M1.5 | `apply_transaction_mutation` + `client_mutations` | ⏳ awaiting web-owner apply |

**20 of 20 milestones complete.** The app is code-complete and release-prepared.
What remains is not development: it is a design asset, a set of legal filings,
store-account setup, and one device-verification pass — all itemised in §6 and,
for the device pass, in M19 §5.

---

## 9. What was deliberately NOT done

- **No behaviour changes** dressed up as release prep. `speech_to_text
  onDevice: true` (a real improvement to the privacy story) is left as R-M20-1
  for someone with a mic to verify it doesn't break older devices.
- **No R8 / shrinking** turned on — dormant rules only.
- **No `flutter_launcher_icons` dependency** added without an icon asset to feed
  it — the procedure is documented instead.
- **No `FLAG_SECURE` / app-switcher blur** (R-M18-2) — a product decision that
  also needs a device to tune; noted, not implemented.
- **No fabricated screenshots or icon.** Placeholders are marked ❌, not faked.
