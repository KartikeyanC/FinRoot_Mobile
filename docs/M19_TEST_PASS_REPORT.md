# M19 — Full test pass · completion report

**Date:** 2026-09-10 · **Status:** complete for everything runnable without an
Android/iOS device; residual device checklist in §5. Awaiting approval for M20.
**Repo:** `F:\Movie\AK\Finroot App` · builds on `38ddcbe` (M18)

---

## 1. Scope & the device constraint

M19 in the M1 plan is "full test pass — device, offline, regression, Android +
iOS, phone + tablet, portrait/landscape". The device half has been blocked
since **M2 I-1**: no Android SDK on this machine, iOS impossible on Windows.
`flutter doctor` confirms — Android toolchain absent; **Windows desktop and web
toolchains present**, but the app targets Android + iOS only and running it on
a desktop shell would exercise none of the seams that are actually unverified
(the native plugins).

So M19 delivered the maximum verification possible here, on real
infrastructure, and turns the rest into a bounded handoff checklist (§5).

**No app-source behaviour change beyond four layout-overflow fixes.** No
backend change, no new dependency.

---

## 2. What was verified

### Encryption at rest — now proven (was device-unverified since M4)

`test/data/local/encrypted_database_test.dart` runs against the **real
SQLite3MultipleCiphers** build on this machine (the other DB tests use the
in-memory executor):

| Check | Result |
|---|---|
| the cipher is compiled in (`PRAGMA cipher` answers) | ✅ |
| a keyed file's first 16 bytes are **not** `SQLite format 3` | ✅ |
| opening the file with no key fails to read the schema | ✅ |
| the correct 32-byte key round-trips the data | ✅ |
| a wrong key is rejected (`SqliteException`) | ✅ |
| Drift builds its **full 8-table schema** on an encrypted file, closes, and reopens it with the same key | ✅ |

### Offline → sync → confirm, end to end

`test/integration/offline_capture_sync_test.dart` — the real
`MutationEnqueuer` + real (in-memory) Drift + real `SyncEngine` /
`OutboxProcessor`, only the network gateway faked:

- capture offline → cache row `pendingCreate` + one outbox entry → a sync
  attempt while offline sends nothing → reconnect → the row flips to `synced`,
  `pendingMutationId` cleared, outbox drained;
- edit offline → `pendingUpdate` → sync → `synced`;
- delete offline → `pendingDelete` → sync (`deleted: true`) → row gone;
- a transient network failure holds the entry pending (not failed), then a
  forced retry drains it.

This complements the existing M5 sync unit tests (backoff, delta-pull
pending-edit protection, tombstones, prune, failure dispositions, replay
idempotency).

### Layout — every screen × breakpoint × orientation × text scale

`test/regression/layout_matrix_test.dart` — 7 primary screens (Home,
Transactions, Trackers, Accounts, More, Auth, Quick Add) each pumped at:

- compact / medium / expanded, **portrait and landscape** (360×740 … 1320×900);
- 1.3× text scale on a 390×780 phone.

**49 cases, all green** — after fixing four real overflows this pass found (§3).

### Full regression

`flutter analyze` clean · `flutter test` — **517 passing** (459 from M1–M18 +
58 new). The suite runs on this Windows box including the real Drift native
library.

---

## 3. Bugs found & fixed this pass

| Widget | Trigger | Fix |
|---|---|---|
| `auth_screen.dart` `_ModeSwitcher` | small phone / large text — the "New to FinRoot? · Create account" `Row` overflowed by ~120px | `Row` → `Wrap` (button drops below the prompt) |
| `sync_status_widgets.dart` `SyncStatusChip` | 1.3× scale — "Synced 5m ago" overflowed the Home header by ~10px | the label `Text` is now `Flexible` + ellipsis |
| `tracker_progress.dart` bar row | 1.3× scale / long budget — `spent + " of ₹50,000"` overflowed by ~24px | the amount + "of" pair is a `Flexible` inner row, each part ellipsised |
| `accounts_screen.dart` `_AccountTile` | 1.3× scale / long balance — the balance `AmountText` overflowed by ~16px | balance wrapped in `Flexible` |

Also: `tracker_progress` had a **latent M17 regression** — `semanticsValue:
'${utilization}%'` on the `LinearProgressIndicator` asserts the value is 0–100%
and threw for an over-budget tracker (122%). The M17 a11y test's fixture was
94% and missed it. Now the utilisation goes in `semanticsLabel` ("Spent 122% of
budget"), which has no range constraint.

---

## 4. Still not verifiable here

| Area | Why | Covered instead by |
|---|---|---|
| The app **launching** on Android / iOS | no SDK / Mac | analyzer + 517 tests against overridden providers and real Drift |
| `workmanager` background sync firing | native scheduler | `background_sync.dart` logic is unit-tested; the OS hook is not |
| `flutter_local_notifications` delivering / rescheduling after reboot | native receivers | `planNotifications()` planner + `NotificationCoordinator` are unit-tested |
| `image_picker` camera + gallery | native | `ReceiptCamera` seam is faked in tests |
| `speech_to_text` mic + on-device recogniser | native | `parseUtterance` grammar is unit-tested; the STT seam is faked |
| the `finroot://auth-callback` **intent** on a real OS | native deep link | `PasswordRecoveryController` bridge is unit-tested |
| Android `allowBackup` / `data_extraction_rules` taking effect | needs a build | manifest + XML reviewed (M18 F-5) |
| app-switcher / screenshot behaviour | needs a device | — |
| `flutter_secure_storage` on device (keystore) | needs a device | code-reviewed (M18) |
| real RLS behaviour (a non-member write is actually blocked) | needs a live workspace | M1.5 SQL reviewed (M18 §2); the SQL file's own post-apply checklist |

---

## 5. Device-verification checklist (M19 handoff)

For whoever has an Android device + emulator + tablet (and, for iOS, a Mac).
`flutter run --dart-define-from-file=config/dev.json`.

**Smoke**
- [ ] cold start → auth screen; sign in; land on Home with a real balance
- [ ] rotate every tab portrait ↔ landscape; resize a foldable / tablet across 600 and 840 dp
- [ ] Home feed pull-to-refresh; the sync chip changes state

**Offline**
- [ ] airplane mode → add an expense (Quick Add), a transfer, an income → each shows "Pending" instantly
- [ ] force-quit + reopen while offline → the pending rows are still there
- [ ] reconnect → the banner clears, markers go, `dashboard_summary` refreshes
- [ ] airplane mode → edit then delete a synced row → reconnect → server matches
- [ ] two devices, same workspace, edit the same row offline on both → reconnect → last-write-wins, no dupes

**Native seams**
- [ ] grant then deny notification permission; a recurring item due tomorrow schedules a local notification; reboot the device → it still fires
- [ ] Bill scan: camera capture + gallery pick; the `scan-receipt` function returns; review + approve → one expense in the ledger
- [ ] Voice: speak "spent 250 rupees on groceries yesterday" → review form pre-filled → confirm
- [ ] open a password-reset email link → app opens on the reset screen → set a new password → signed in
- [ ] background the app during a sync → return → sync resumes; leave overnight → `workmanager` ran

**Encryption / sign-out**
- [ ] pull `finroot.sqlite` off the device (`adb`), confirm bytes are not plaintext
- [ ] sign out → the file and the keystore entries are gone; airplane-mode sign-out also wipes
- [ ] reinstall → no previous-user data

**iOS (Mac)**
- [ ] repeat Smoke + Offline + the deep link + Dynamic Type at the largest setting
- [ ] VoiceOver: the amount reads "Expense …", a transaction row is one item, the sync banner announces

**Store readiness (feeds M20)**
- [ ] Android `allowBackup=false` verified via `adb shell bmgr`
- [ ] `ITSAppUsesNonExemptEncryption` set; export-compliance answered

---

## 6. Phase status

| Phase | | Status |
|---|---|---|
| M1 – M18 | … · a11y · security | ✅ |
| M1.5 | `apply_transaction_mutation` + `client_mutations` | ⏳ awaiting web-owner review + apply |
| **M19** | **Full test pass** — encryption-at-rest proven, offline loop + layout matrix green, 517 tests | ✅ **complete** here (device checklist §5 is the handoff) |
| M20 | Release prep — store listings, signing, versioning, compliance, the §5 checklist run on real devices | ⬜ **next** |

**Completed: 19 of 20** (M1–M19).

---

## 7. Next — M20 (Release preparation)

App-store metadata and screenshots, signing config (Android keystore, iOS
provisioning), version/build numbering, the export-compliance and
non-exempt-encryption declarations from M18, a `README` / runbook for the
build, and — the gate — the §5 device checklist actually run on hardware by
someone who has it.

**Stopping here for approval, per the phase-gate rule.**
