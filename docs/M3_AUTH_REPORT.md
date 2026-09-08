# M3 — Authentication · completion report

**Date:** 2026-09-08 · **Status:** complete, awaiting approval for M4
**Repo:** `F:\Movie\AK\Finroot App` · builds on `ceed339` (M1+M2)

---

## 1. Scope

Implemented against the **unchanged** existing Supabase auth architecture
(M1 audit §7–8). No migration, no schema, RLS, RPC or web-source change.

| Delivered | Notes |
|---|---|
| Email + password **sign in** | `signInWithPassword`; errors mapped to plain copy |
| **Sign up** | `signUp` with `display_name` / `full_name` so `handle_new_user()` names the workspace; handles both "signed in immediately" and "confirm your email" |
| **Sign out** | server sign-out + `purgeSecureStorage()` wipes every FinRoot key from the keystore |
| **Forgot password** | `resetPasswordForEmail` → `finroot://auth-callback` |
| **Reset password** | deep link → `AuthChangeEvent.passwordRecovery` → forced reset screen → `updateUser(password:)` |
| **Session restore** | already wired in M2 (`SecureLocalStorage` in the keychain/keystore); M3 adds the routing around it |
| **Sign-in intent guard** | `AuthIntent.mark()` before every credential call — the seam a later app-lock consumes so a cold-start restore is not mistaken for a sign-in (web BUG-090) |
| **Membership fetch** | `tenant_members` joined to `tenants`, scoped to `user_id` (a PO can read all rows — must filter ourselves) |
| **Tenant selection** | stored in `shared_preferences`, reconciled against live memberships (stale / deleted / left → first usable), mirrors web `TenantContext` |
| **Workspace switcher** | bottom sheet, shown only when the user is in > 1 workspace |
| **"No workspace" state** | dedicated screen with retry + sign out (rare; the signup trigger always makes one) |
| **Menu gate** | `get_effective_menus(tenant_id)` → `Set<String>`; `More` entries and the Trackers tab render *locked* (not hidden, not crashed) when their menu is absent; "unknown" while loading never shows a lock |
| **Settings** | profile (display-name edit), workspace summary/switcher, theme mode (system/light/dark, persisted), sign-out with confirm |
| **Theme toggle** | `themeModeProvider` + `shared_preferences`; `MaterialApp.themeMode` now driven by it |

---

## 2. Architecture decisions

- **Layering.** Each feature is `data/` (repository, one place that talks to
  Supabase) → `application/` (Riverpod controllers / providers, no widgets) →
  `presentation/` (widgets, no Supabase). Every repository method maps backend
  errors to a `Failure` (from M2) so no screen sees a raw `AuthException` /
  `PostgrestException`.
- **Auth form state is a sealed class** (`AuthActionState`: idle / busy /
  failed / awaiting-confirmation / reset-sent), not `AsyncValue<void>` — the
  two success outcomes (session appears vs. "check your email") are distinct
  and the UI must tell them apart. **Navigation on success is the router's
  job**, never the screen's: the redirect reacts to the session appearing.
- **`shared_preferences` added** as the device-local KV store — distinct from
  the keystore (secrets) and from Drift (synced data, M4). Holds the theme
  choice and the last-selected workspace today; onboarding flags and
  last-used pickers later. This is the mobile equivalent of the web's
  `localStorage` device-local keys (M1 audit §8).
- **Tenant reconciliation is a pure function** (`resolveCurrentTenantId`) so
  the "keep the stored choice unless it is stale/deleted, else first usable"
  rule is tested directly, matching the web `TenantContext` "stillValid" logic.
- **Menu gate resolves to three states** — `available` / `locked` / `unknown`.
  `unknown` (loading or RPC error) counts as usable: RLS is the real gate, and
  the web rule is "anything uncertain renders nothing, never a paywall aimed at
  someone who already paid" (`menuUpsell`). **No upgrade prompt** — telling a
  plan lock apart from an owner-disabled menu is the billing phase's job.
- **Password-reset deep link** flows through a `passwordRecoveryProvider`
  (`Notifier<bool>`) that the router treats as top priority: while set, every
  route redirects to the reset screen; the screen clears it on success/cancel.
  `supabase_flutter` handles the incoming link and makes the short-lived
  session — it does not navigate; this provider is the bridge.
- **Riverpod 3 note:** `AsyncValue` exposes `.value` (nullable), not
  `.valueOrNull`; `FutureProvider` **auto-retries on error** by default (kept
  for `effectiveMenusProvider` — a transient RPC failure self-heals; tests
  disable it with `ProviderContainer(retry: ...)`).

---

## 3. Files

### New (23)

```
lib/core/device/device_prefs.dart                         SharedPreferences wrapper, themeModeProvider
lib/features/auth/data/auth_repository.dart                gotrue wrapper, error mapping
lib/features/auth/data/auth_intent.dart                    sign-in intent seam
lib/features/auth/application/auth_controller.dart         sealed AuthActionState machine
lib/features/auth/application/auth_validators.dart         pure form validators (mirror web zod)
lib/features/auth/application/password_recovery.dart       deep-link → router bridge
lib/features/auth/presentation/reset_password_screen.dart  new-password form
lib/features/workspace/domain/membership.dart              Membership, WorkspaceRole, resolveCurrentTenantId
lib/features/workspace/data/membership_repository.dart     tenant_members + get_effective_menus
lib/features/workspace/application/workspace_providers.dart  memberships / currentTenantId / role / switcher
lib/features/workspace/presentation/no_workspace_screen.dart
lib/features/workspace/presentation/workspace_switcher_sheet.dart  + WorkspaceSummaryTile
lib/features/menus/application/menu_providers.dart         effectiveMenus, menuStatus, menuAvailable
lib/features/menus/presentation/menu_locked_view.dart
lib/features/profile/profile_providers.dart               profiles row read + display-name update
test/features/auth/auth_validators_test.dart
test/features/auth/auth_controller_test.dart
test/features/workspace/membership_test.dart
test/features/menus/menu_status_test.dart
```

### Modified (12)

```
lib/app/app.dart                       themeMode from provider
lib/app/router.dart                    reset-password + no-workspace routes; 4-tier redirect
lib/bootstrap.dart                     load SharedPreferences, override the provider
lib/features/auth/presentation/auth_screen.dart      full rewrite: 3-mode form
lib/features/settings/presentation/settings_screen.dart  full rewrite
lib/features/more/presentation/more_screen.dart      menu gating + workspace summary
lib/features/trackers/presentation/trackers_screen.dart  locked state when trackers menu absent
pubspec.yaml / pubspec.lock            + shared_preferences ^2.3.5 (resolved 2.5.5)
android/app/src/main/AndroidManifest.xml  finroot://auth-callback intent-filter
ios/Runner/Info.plist                  CFBundleURLTypes: finroot
config/dev.example.json                redirect-allow-list note
```

---

## 4. Gates

| Gate | Result |
|---|---|
| `flutter analyze` | ✅ **No issues found** (same strict settings as M2) |
| `flutter test` | ✅ **55 passing** (28 from M2 + 27 new) |
| `dart format` | ✅ applied |
| Regression risk to web | ✅ **none** — `F:\Movie\AK\FinRoot\_extracted` git status clean; no file outside `F:\Movie\AK\Finroot App` touched; no migration; no Supabase schema / RLS / RPC / data change |
| Device / emulator run | ⚠️ **not performed** — still no Android SDK (M2 issue I-1) |

---

## 5. Required external config (not a migration — one dashboard toggle)

For the password-reset link to open the **app** rather than the web reset
page, the Supabase project's **Auth → URL Configuration → Redirect URLs**
allow-list must include:

```
finroot://auth-callback
```

This is **additive and has no web impact** (it only widens what redirect
targets are accepted). Until it is added, the reset email still sends and works
— the link just lands on the web reset page. Flagging for the web/Supabase
owner alongside the M1.5 migration review.

---

## 6. Not built in M3 (deliberate)

- **App lock (PIN / biometric).** A device curtain, not access control (web
  ADR-0007) — worth its own phase. `local_auth` stays in `pubspec.yaml`; the
  `AuthIntent` seam it will consume is already in place.
- **Plan-lock upsell copy** — billing phase (needs the plan `menu_set` to tell
  a plan lock from an owner-disabled menu).
- **Profile beyond display name** (username, mobile, onboarding wizard).
- **Google / OAuth** — cut for V1 (decision 4).
- **M1.5 backend migration** (`apply_transaction_mutation` + `client_mutations`)
  — still queued as its own reviewable package before M5/M7.

---

## 7. Issues / risks

| # | Issue | Impact | Action |
|---|---|---|---|
| I-1 | Android SDK still not installed | Auth has not run on a device — verification is analyzer + unit tests only | Install Android Studio + SDK; I can walk through it |
| I-7 | Reset deep link needs the Supabase redirect allow-list entry (§5) | Native reset link falls back to web until added | Web/Supabase owner adds `finroot://auth-callback` |
| I-8 | Email-confirmation on/off is a Supabase project setting not visible from here | `signUp` handles both paths, but which one users hit is unknown until tested | Confirm the project's "Confirm email" setting with the web owner |
| I-9 | `shared_preferences` is plain-text device storage | Only the theme + tenant id live there — neither sensitive | Fine as-is; secrets stay in the keystore |

None block M4.

---

## 8. Phase status

| Phase | Title | Status |
|---|---|---|
| **M1** | Architecture audit | ✅ complete (`docs/M1_ARCHITECTURE_AUDIT.md`) |
| **M2** | Flutter foundation | ✅ complete (`docs/M2_FOUNDATION_REPORT.md`) |
| **M3** | Authentication | ✅ complete (this report) |
| M1.5 | Additive `apply_transaction_mutation` RPC + `client_mutations` table | ⏳ approved, not written — due before M5/M7 |
| M4 | Local database (Drift + SQLCipher: cached subset, `sync_outbox`, `sync_cursor`, migrations) | ⬜ not started — **next** |
| M5 | Sync engine (upload/download, retry, idempotency, conflict, realtime, offline queue) | ⬜ not started |
| M6 | Mobile navigation + Home feed (establishes the mobile design language) | ⬜ not started |
| M7 | Quick Add — Expense / Income / Transfer (highest-priority UX) | ⬜ not started |
| M8 | Transactions + Accounts (list, detail, edit, delete, search, filters) | ⬜ not started |
| M9 | Trackers (list, create, detail, spend, category/account breakdown, assign, review, archive) | ⬜ not started |
| M10 | Budget + Goals | ⬜ not started |
| M11 | Investments + Net Worth (simplified) | ⬜ not started |
| M12 | Recurring + Reminders + Notifications (Money Owed cut from V1) | ⬜ not started |
| M13 | Bill Scan / OCR (reuses the existing `scan-receipt` edge function) | ⬜ not started |
| M14 | Voice-to-ledger | ⬜ not started |
| M15 | AI financial insights | ⬜ not started |
| M16 | Tablet adaptive experience (rail, split views) — foundation already in M2 | ⬜ not started |
| M17 | Accessibility + UX polish (UX-law audit, WCAG 2.2 AA) | ⬜ not started |
| M18 | Security + performance audit | ⬜ not started |
| M19 | Full testing (unit / widget / integration / sync / offline / device / tablet) | ⬜ not started |
| M20 | Production release (builds, icons, splash, store metadata, crash reporting) | ⬜ not started |

**Completed: 3 of 20** (M1, M2, M3). Plus M1.5 approved and pending.

---

## 9. Next — M4 (Local database)

Drift schema for the cached subset (accounts, categories, transactions,
trackers, budgets, goals) + `sync_outbox` + `sync_cursor`; SQLCipher key in the
keystore; a migration/version strategy. M4 also resolves the `drift_dev` ↔
`riverpod_lint` analyzer conflict noted in M2 (recommendation: don't add the
Riverpod lint plugin — the strict analyzer already covers it).

**Stopping here for approval, per the phase-gate rule.**
