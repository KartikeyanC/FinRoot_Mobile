# M2 — Flutter Foundation · completion report

**Date:** 2026-09-08 · **Status:** complete, awaiting approval for M3
**Repo:** `F:\Movie\AK\Finroot App` (standalone, `git init` done, nothing committed yet)

---

## 1. Decisions applied (from M1 sign-off)

| # | Decision | How it landed |
|---|---|---|
| 1 | Flutter over the web repo's Expo/monorepo plan | [`docs/adr/0001-flutter-supersedes-the-expo-plan.md`](adr/0001-flutter-supersedes-the-expo-plan.md) — written, with the parity-test mechanism that replaces the shared `@finroot/core` package |
| 2 | M1.5 migration approved, strictly additive, web-impact documented first | **Not written yet — deliberately.** M2 is client-only. Authored before M5/M7, as its own reviewable deliverable (see §7) |
| 3 | Cut Money Owed / Relationships from V1 | Removed from `kMoreEntries`; no table, no model, no screen anywhere in the codebase |
| 4 | Email + password only | Auth wiring is PKCE + keystore session; no Google/OAuth code, no Lovable SDK, no auth backend change |
| 5 | Riverpod | `flutter_riverpod ^3.4.3`, single `ProviderScope`, no competing state system |
| 6 | Standalone repo, one codebase for phone + tablet | One Flutter project; layout adapts by width via `WindowSize` |

**Identity:** display name `FinRoot`, application id / bundle id `com.finroot.mobile` — set on both platforms (see §4).

---

## 2. Toolchain

| | |
|---|---|
| Flutter | **3.47.2** stable, installed fresh at `F:\flutter` |
| Dart | 3.13.2 |
| Android SDK | ❌ **not installed** — blocks building/running on Android |
| Xcode / iOS | ❌ not possible on Windows |
| Windows / Chrome targets | ✓ available (not enabled for this project) |

> The bundled Flutter 3.44 inside the old `FinRoot Mobile APp` folder was 4 months
> stale and could not resolve current packages (`sqlite3_flutter_libs`, `riverpod_lint`
> both demanded a newer SDK). A clean 3.47.2 was cloned to `F:\flutter` so this
> project does not depend on an SDK nested inside an abandoned project.

---

## 3. What M2 established

### Project & configuration
- Flutter project scaffolded (`finroot_mobile`), Android + iOS platforms.
- **Build-time config** via `--dart-define-from-file`: `lib/core/config/app_config.dart`
  (`AppConfig` + `AppFlavor` dev/staging/prod), templates in `config/*.example.json`.
- `config/dev.json` holds the real Supabase URL + **anon/publishable** key and is
  **git-ignored** (verified: `git check-ignore` confirms it; only the examples are staged).
  `assertValid()` refuses a URL that isn't https, a short key, and anything containing
  `service_role`.

### Backend wiring (no queries yet)
- `lib/core/supabase/supabase_bootstrap.dart` — `Supabase.initialize` against the
  **same project as web** (`ludbntvhagefadfkhrjj`), PKCE flow, `debug` off in prod.
- `lib/core/supabase/secure_local_storage.dart` — session **and** PKCE verifiers stored in
  the Android Keystore / iOS Keychain (`first_unlock`), not SharedPreferences.
  `purgeSecureStorage()` for confirmed sign-out.

### Material 3 design system (`lib/design/`)
- **Tokens:** `app_colors` (forest-green brand + light/dark neutrals + semantic finance
  colours), `app_spacing` (4dp scale, `minTouchTarget = 48`), `app_radius`,
  `app_typography` (tabular-figure money styles: inline / large / hero), `app_breakpoints`.
- **Theme:** `AppTheme.light` / `AppTheme.dark` — flat cards, soft corners, 52dp buttons,
  themed nav bar / rail / sheets / inputs. Dark mode **redefines** the finance palette
  rather than inverting it, via the `FinanceColors` `ThemeExtension` (`context.finance`).
- **Components:** `AmountText` (sign outside symbol, direction by colour *and* sign),
  `AppCard`, `SectionHeader`, `LoadingView` / `EmptyView` / `ErrorView`,
  `CategoryBadge`, `TrackerBadge` (neutral tint, `T-` display convention),
  `PlaceholderScreen`. One barrel: `lib/design/design.dart`.

### Navigation architecture (`lib/navigation/`, `lib/app/router.dart`)
- go_router with `StatefulShellRoute.indexedStack` — each tab keeps its own stack.
- **Compact / medium:** bottom bar (Home · Transactions · **+** · Trackers · More) with the
  Quick Add FAB docked in the notch.
- **Expanded (tablet):** `NavigationRail` + Quick Add as the rail's leading action; content
  gets the remaining width, ready for M16's split views.
- `openQuickAdd()` picks bottom sheet (phone) vs centered dialog (tablet).
- Auth-aware redirect: signed out → `/auth`; signed in on `/auth` → Home.
- "More" list is data-driven from `kMoreEntries`, each entry tagged with the milestone
  that replaces its placeholder.

### Core services
- **Error handling:** sealed `Failure` hierarchy (`Network`, `Auth`, `Permission`,
  `Validation`, `Conflict`, `Unexpected`) + a single `mapError()` that interprets
  `PostgrestException` codes (`42501` → permission, `PGRST301` → session expired,
  `23xxx` → validation). No raw code ever reaches the UI.
- **Logging:** `AppLog` with a `redact()` helper; a `ProviderLogger` that logs provider
  *failures* but never provider *values*. Guarded zone + `FlutterError.onError` in
  `bootstrap.dart`.
- **Money:** `Money` wraps `Decimal` — never `double`; `toStorageString()` emits
  `numeric(14,2)` shape. `MoneyFormat` mirrors the web's `formatMoney`/`formatCompact`
  (sign outside symbol, `en_IN` lakh/crore, `—` for non-finite).
- **Providers:** `appConfig`, `supabaseClient`, `authEvent`, `session`, `currentUser`,
  `isSignedIn`, `connectivity`, `isOnline`.

### Shared domain constants
`lib/domain/constants.dart` mirrors the web's value lists — `TxnType`, expense/income
categories, the 7 budget buckets, goal categories, tracker types, payment modes, the 16
feature-menu ids, `trackerDisplayLabel()`. Each pinned by a test.

---

## 4. Files changed

**Created — 30 Dart files + config/docs** (117 files staged in git including generated
platform folders).

```
lib/main.dart                                    entrypoint
lib/bootstrap.dart                               guarded async startup
lib/app/app.dart                                 MaterialApp.router
lib/app/router.dart                              GoRouter + shell + redirect
lib/core/config/app_config.dart
lib/core/error/failure.dart
lib/core/error/error_mapper.dart
lib/core/logging/app_logger.dart
lib/core/logging/provider_logger.dart
lib/core/money/currency.dart
lib/core/money/money.dart
lib/core/money/money_format.dart
lib/core/providers/providers.dart
lib/core/supabase/supabase_bootstrap.dart
lib/core/supabase/secure_local_storage.dart
lib/design/design.dart                           barrel
lib/design/theme/app_theme.dart
lib/design/theme/finance_colors.dart
lib/design/tokens/{app_colors,app_spacing,app_radius,app_typography,app_breakpoints}.dart
lib/design/components/{amount_text,app_card,badges,placeholder_screen,section_header,state_views}.dart
lib/domain/constants.dart
lib/navigation/{destinations,app_shell,quick_add_entry}.dart
lib/features/home/presentation/home_screen.dart
lib/features/transactions/presentation/transactions_screen.dart
lib/features/trackers/presentation/trackers_screen.dart
lib/features/more/presentation/more_screen.dart
lib/features/quick_add/presentation/quick_add_sheet.dart
lib/features/auth/presentation/auth_screen.dart
lib/features/settings/presentation/settings_screen.dart

test/  7 files (see §5)
config/{dev.example.json,prod.example.json}      + git-ignored config/dev.json
docs/adr/0001-flutter-supersedes-the-expo-plan.md
docs/M2_FOUNDATION_REPORT.md                     this file
README.md                                        rewritten
analysis_options.yaml                            strict-casts/inference/raw-types + 18 extra lints
.gitignore                                       + /config/*.json (examples kept)
pubspec.yaml                                     dependency map, with later-phase deps documented
```

**Modified — platform identity:**
- `android/app/build.gradle.kts` — `namespace` and `applicationId` → `com.finroot.mobile`; `minSdk = 23` (secure storage / biometrics / SQLCipher headroom).
- `android/app/src/main/AndroidManifest.xml` — `android:label="FinRoot"`.
- `ios/Runner.xcodeproj/project.pbxproj` — `PRODUCT_BUNDLE_IDENTIFIER` → `com.finroot.mobile` (tests → `com.finroot.mobile.RunnerTests`).
- `ios/Runner/Info.plist` — `CFBundleDisplayName` → `FinRoot`.

**Dependencies installed:** `flutter_riverpod`, `supabase_flutter`, `go_router`,
`flutter_secure_storage`, `local_auth`, `connectivity_plus`, `decimal`, `intl`, `logging`,
`uuid`, `equatable`; dev: `flutter_lints`, `mocktail`.

---

## 5. Tests

`flutter test` — **28 passing, 0 failing**, 7 files:

| File | Covers |
|---|---|
| `test/core/money/money_format_test.dart` | sign placement, `en_IN` lakh/crore grouping, `—` for NaN/∞, lakh/crore short form |
| `test/core/money/money_test.dart` | exact `Decimal` parse/serialise, symbol-stripping input, 8-digit addition without drift, cross-currency assert |
| `test/core/money/fx_parity_test.dart` | **parity pin** — FX table + currency list vs the web `src/lib/finance.ts` |
| `test/domain/constants_test.dart` | **parity pin** — categories, buckets, tracker types, menu ids, `T-` convention |
| `test/core/config/app_config_test.dart` | flavor mapping, defaults, `assertValid` rejects a missing URL |
| `test/design/app_theme_test.dart` | both themes build + carry `FinanceColors`; income/expense render signed; tracker badge shows `T-` |
| `test/navigation/breakpoints_test.dart` | 600 / 840 size-class thresholds, rail only when expanded |

---

## 6. Gates

| Gate | Result |
|---|---|
| `flutter analyze` | ✅ **No issues found** (strict-casts, strict-inference, strict-raw-types + 18 extra lints) |
| `flutter test` | ✅ **28 passing** |
| `dart format lib test` | ✅ applied (22 files reflowed) |
| Regression risk to the web app | ✅ **none** — no file outside `F:\Movie\AK\Finroot App` was modified; no migration written; no Supabase schema, RLS, RPC or data touched |
| Device smoke run | ⚠️ **not performed** — no Android SDK (see §8) |

---

## 7. What was deliberately NOT built in M2

- No feature screens — Home/Transactions/Trackers/More/Quick Add are walkable placeholders
  that name their milestone.
- No data layer, no repositories, no Supabase queries (M4–M5).
- No local database — `drift` / `sqlite3_flutter_libs` / `build_runner` are documented in
  `pubspec.yaml` as M4 additions but **not installed**: `drift_dev` currently conflicts with
  `riverpod_lint`/`custom_lint` on `analyzer`, and M4 resolves that rather than carrying a
  broken constraint now.
- **No M1.5 backend migration.** Approved, but M2 is client-only. It will be delivered as a
  separate reviewable package — the migration SQL, the web-impact analysis you asked for,
  and a verification checklist — before M5/M7 need it.
- No Money Owed / Relationships anywhere (cut per decision 3).
- No Google sign-in (cut per decision 4).

---

## 8. Issues / risks raised in M2

| # | Issue | Impact | Suggested action |
|---|---|---|---|
| **I-1** | **Android SDK not installed.** `flutter doctor` cannot locate one, so the app has never been compiled to a device binary or run. Verification so far is analyzer + unit/widget tests only. | Blocks M3 verification on a real device | Install Android Studio + SDK (or point `flutter config --android-sdk` at an existing one). I can walk through it. |
| **I-2** | iOS cannot be built or tested from Windows. | iOS is unverified until a Mac is available | Plan a macOS machine / CI runner before M19–M20. |
| **I-3** | Flutter is not on the system `PATH` (`F:\flutter\bin`). Every command needs the full path. | Friction only | Add `F:\flutter\bin` to PATH. |
| **I-4** | `drift_dev` ↔ `riverpod_lint`/`custom_lint` `analyzer` conflict. | Deferred to M4 | M4 picks one: drop the Riverpod lint plugin, or pin `analyzer`. Recommendation: drop the lint plugin — `flutter_lints` + the strict analyzer settings already cover it. |
| **I-5** | The FX table and value lists are now duplicated in Dart (unavoidable with Flutter). | Silent drift if the web file changes | Mitigated by the two parity tests. **Every future Dart money rule must ship with one** — this is the ADR-M001 contract. |
| **I-6** | `supabase_flutter` deprecates `anonKey` in favour of `publishableKey`. | Cosmetic today | One-line change when we next bump the package. |

None of these block starting M3.

---

## 9. Ready for M3 — Authentication

M3 will implement, against the **unchanged** existing auth architecture:
sign-in, sign-up, sign-out, session restore from the keystore, password reset via deep
link (`finroot://`), the workspace/membership fetch + tenant selection, the
`get_effective_menus` gate that drives the More list, and the "sign-in intent" guard that
stops gotrue's `SIGNED_IN`-on-restore from defeating a future app lock.

**Stopping here for approval, per the phase-gate rule.**
