# M18 — Security review · completion report

**Date:** 2026-09-09 · **Status:** complete, awaiting approval for M19
**Repo:** `F:\Movie\AK\Finroot App` · builds on `026c3cd` (M17)

---

## 1. Scope

A pass over the mobile client's trust boundary: session + PKCE + DB-key
storage, sign-out wipe, what can reach a device log, the deep link, the
direct-write gateways' reliance on RLS, and the M1.5 idempotency RPC. Then the
fixes.

**No web-source change.** One additive Android resource file; no backend
change; no new dependency.

---

## 2. Reviewed — no finding

| Area | Verdict |
|---|---|
| **Session + PKCE storage** (`secure_local_storage.dart`) | Keystore / Keychain, not SharedPreferences. `flutter_secure_storage` v11 → KeyStore-backed AES/GCM by default (the old `EncryptedSharedPreferences` path was removed upstream). iOS `first_unlock`. `purgeSecureStorage()` (`deleteAll`) runs in `AuthRepository.signOut`'s `finally`, clearing session **and** PKCE verifiers. |
| **DB encryption key** (`database_key.dart`) | `Random.secure()` CSPRNG, 32 bytes, hex, keystore-only — never derived from a password, in source, or logged. `PRAGMA key` uses string interpolation (SQLite forbids bind params in PRAGMA) but the value is validated `^[0-9a-f]{64}$` before use and single-quotes are escaped. |
| **Query construction** | Every PostgREST call uses `.eq()` / `.insert({})` / `.update({})` / `.rpc(params:)` — values are encoded by the client, never concatenated. The one `LIKE` (`transactions_repository`) is a **Drift** query-builder call — bound, not interpolated. No `or()` / `filter()` string filters, no raw SQL RPC. |
| **Tenant scoping** | Every direct-write gateway adds `.eq('tenant_id', tenantId)` on top of RLS — defence in depth. `currentTenantIdProvider` can only resolve to a tenant the **server** returned as a membership; a tampered client id is still blocked by RLS. |
| **Error surface** (`failure.dart` / `error_mapper.dart`) | User-facing `.message` is always a fixed safe string; `Failure.toString()` deliberately omits `cause`. The data layer logs only `'…failed'` / `${e.runtimeType}`. `apply_transaction_mutation` errors are stored in the outbox as `f.message` (safe). |
| **Config / secrets** | Anon key only; `config/*.json` git-ignored (verified `git check-ignore`), only `*.example.json` tracked; a `service_role` key cannot be passed through `--dart-define` (F-4 hardens the guard anyway). No secrets, `http://`, WebView, or `NSAllowsArbitraryLoads` anywhere. |
| **M1.5 RPC** (`apply_transaction_mutation`, package only — not yet applied) | `SECURITY DEFINER` + `SET search_path = public`; explicit `is_tenant_member(tenant,'admin')` gate (definer bypasses the `tx_*` RLS policies); `pg_advisory_xact_lock` for the replay race; referenced `account_id` / `transfer_to_account_id` / `tracker_id` verified to belong to the tenant (stricter than the web's raw insert); `user_id` from `auth.uid()`, never the client; `REVOKE ALL … FROM public, anon` + `GRANT EXECUTE … TO authenticated`; no end-user write path to `client_mutations`; fresh-apply `ASSERT` self-checks. **Clean.** Still awaiting web-owner review + apply. |

---

## 3. Findings & fixes

### F-1 · medium · raw backend error could reach the device log

`ProviderLogger.providerDidFail` forwarded the raw `error` object to
`developer.log(error: …)`. For an **unmapped** `PostgrestException` /
`AuthException` propagating from a provider build, its `toString()` — server
`message` / `details` / `hint` — would land in logcat / Console, at WARNING,
**in release**. This contradicts the M1 §12 rule.

**Fix** (`core/logging/provider_logger.dart`): a mapped `Failure` (safe
`toString()`) passes through; anything else is reduced to `error.runtimeType`.
The stack trace (code locations only) is kept.
Tested: `test/core/logging/provider_logger_test.dart`.

### F-2 · medium · sign-out aborted the local cache wipe on a network failure

`AuthRepository.signOut()` re-threw a failed server revoke; `SignOutController`
then never reached `wipeLocalData`, and `_confirmSignOut` had no `catch` → an
unhandled exception, and the encrypted database **file** left on disk (its key
purged, so unreadable — but not wiped until the next launch's self-heal).

**Fix:**
- `auth_repository.dart` — `signOut()` swallows the server-revoke error (gotrue
  clears the local session and emits `signedOut` *before* the server call, so
  an offline failure is harmless), always runs `purgeSecureStorage()`, and
  **never throws**.
- `sign_out.dart` — `wipeLocalData` now runs unconditionally; only a failure of
  the wipe *itself* propagates.
- `settings_screen.dart` — `_confirmSignOut` catches that last-resort case and
  shows a plain "reopen the app to finish" message.
Code-review-verified (the `flutter_secure_storage` / file paths are
device-unverified, like M5 — no mock in the test suite).

### F-3 · low · Supabase SDK debug logging was on for staging

`debug: !config.isProd` → **staging** (a release build for testers) shipped
verbose gotrue / Supabase logs (request URLs, auth-flow detail) to the device
log. **Fix** (`supabase_bootstrap.dart`): `debug: kDebugMode` — debug builds
only.

### F-4 · low · the service-role guard never actually fired

`AppConfig.assertValid` checked `supabaseAnonKey.contains('service_role')` —
which can never match a real key: the `"role":"service_role"` claim is
**base64url-encoded** inside the JWT. False confidence.

**Fix** (`app_config.dart`): `_isPrivilegedKey()` — rejects `sb_secret_…` keys
and decodes a JWT payload to check `role == 'service_role'`.
Tested: `test/core/config/app_config_test.dart` (4 cases: legacy
service_role / anon, new secret / publishable).

### F-5 · low · Android auto-backup not disabled

`<application>` had no `android:allowBackup="false"` / `dataExtractionRules`.
The encrypted `.sqlite` would be swept into Android cloud backup and
device-transfer (harmless in isolation — the keystore key is device-bound and
not backed up — but the M4 §12 plan said "exclude from auto-backup").

**Fix** (`AndroidManifest.xml` + new `res/xml/data_extraction_rules.xml`):
`allowBackup="false"`, `usesCleartextTraffic="false"`, and cloud-backup /
device-transfer exclusion rules for all domains. **Build-unverified** — no
Android SDK (M2 I-1).

---

## 4. Recommendations (not fixed — need a device or web-owner)

| # | Recommendation |
|---|---|
| R-M18-1 | **Deep link → App Links / Universal Links.** `finroot://auth-callback` is a custom scheme any app can register; interception is currently mitigated only by PKCE (the intruder gets the `code` but not the verifier). Moving to `https` App Links needs an `assetlinks.json` / AASA file on the FinRoot domain — web-owner coordination. |
| R-M18-2 | **Screen-capture protection.** No `FLAG_SECURE` / app-switcher blur on balance screens. A product + device decision for M19/M20. |
| R-M18-3 | **`ITSAppUsesNonExemptEncryption`** — the local DB cipher is non-standard; declare it (and export-compliance if needed) at App Store submission. M20. |
| R-M18-4 | **`AppConfig.isProd`** is now unused by the bootstrap; keep it (used for copy / analytics later) or prune in a cleanup. |

---

## 5. Verification

| Check | Result |
|---|---|
| `flutter analyze` | ✅ **No issues found** |
| `flutter test` | ✅ **459 passing** (453 from M1–M17 + 6 new) |
| Android build / device | ⚠️ manifest + backup rules **build-unverified** — no Android SDK (M2 I-1). |

New / extended tests: `test/core/config/app_config_test.dart` (+4),
`test/core/logging/provider_logger_test.dart` (new, 2).

---

## 6. Phase status

| Phase | | Status |
|---|---|---|
| M1 – M17 | … · tablet · a11y | ✅ |
| M1.5 | `apply_transaction_mutation` + `client_mutations` — **security-reviewed clean** (this report §2) | ⏳ awaiting web-owner review + apply |
| **M18** | **Security review** — session, keystore, wipe, redaction, deep-link, RLS trust, M1.5 | ✅ **complete** (this report) |
| M19 | Full test pass — device, offline, regression, Android + iOS, phone + tablet, portrait/landscape | ⬜ **next** |
| M20 | Release prep — store listings, compliance, signing, versioning | ⬜ |

**Completed: 18 of 20** (M1–M18).

---

## 7. Next — M19 (Full test pass)

The device-verification debt tracked since M2 (I-1) comes due: install an
Android SDK, run the app on an emulator + a physical device and a tablet,
exercise the offline → sync → conflict paths for real, the notification /
workmanager / camera / mic native seams, the encrypted DB on-disk, the deep
link, and a full regression of the 459 tests on-device. Findings, then fixes.

**Stopping here for approval, per the phase-gate rule.**
