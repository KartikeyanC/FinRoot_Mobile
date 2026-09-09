# M12 — Recurring items + Reminders · completion report

**Date:** 2026-09-09 · **Status:** complete, awaiting approval for M13
**Repo:** `F:\Movie\AK\Finroot App` · builds on `4360eac` (M11)

---

## 1. Scope

Three related surfaces, all **online-only / not cached** (M1 audit), plus the
first on-device scheduling:

| Piece | Table(s) | Menu gate |
|---|---|---|
| **Recurring** income / expense templates + "mark paid/received" | `recurring_items`, RPC `mark_recurring_generated` | none — the web reaches these from the always-on Income / Expenses pages; session + role + connectivity still gate every write |
| **Per-item reminder** ("bell" on a recurring card) | `recurring_reminders` | none (as above) |
| **Reminders** ledger (bills / buffers / maturities) | `reminders` | `reminders` (ADR-0002, web `menuContract`) |
| **Local notifications** | — | — |
| **Home "Upcoming" card** | reads the above | reminders portion hidden when `reminders` is locked |

**No backend change, no web impact** — all three tables and the RPC already
exist and are already in the web's data export.

First new dependencies since M5: **`flutter_local_notifications` 22.3.0** +
**`timezone` 0.11.1**.

---

## 2. What M12 built

### Recurring — `lib/features/recurring/`

| File | Purpose |
|---|---|
| `domain/recurring_item.dart` | `RecurringItem` / `RecurringDraft`; `RecurringType` (`income`/`expense`), `RecurringFrequency` (`monthly`/`weekly`/`yearly`/`one-time`); **`bumpDate`** ported from web `src/hooks/useRecurring.ts` — month/year steps clamp to the last valid day (Jan 31 → Feb 28/29), parity-tested against the web suite and the server's `mark_recurring_generated` |
| `domain/reminder_setting.dart` | `ReminderSetting` (`enabled` / `daysBefore` / `note`) + `isDue` window arithmetic, ported from web `src/lib/recurringReminders.ts` (inclusive both ends, calendar-date compare — no DST drift) |
| `data/recurring_gateway.dart` | `recurring_items` list / create (returns the client-generated id) / update / delete + `markGenerated` → `mark_recurring_generated` RPC. Mobile writes `currency: 'INR'`, `fx_rate: 1` |
| `data/recurring_reminders_gateway.dart` | `recurring_reminders` list (→ `Map<itemId, ReminderSetting>`) / upsert on `(tenant_id, recurring_item_id)` / delete |
| `application/recurring_providers.dart` | `recurringItemsProvider` (FutureProvider, not cached), `recurringByTypeProvider` (family, active + sorted), `recurringRemindersProvider`, `reminderSettingForProvider` (family) |
| `application/recurring_editor_controller.dart` | create (optionally sets the bell in the same flow) / update / delete / `markGenerated` (RPC **then** `syncNow(force)` so the generated transaction pulls into the local cache) / `saveReminder` / `removeReminder` — session + role + online gate |
| `presentation/recurring_screen.dart` | `/recurring` — Income / Expense tabs, cards with a due chip, "Mark paid/received", the bell, delete |
| `presentation/recurring_form_sheet.dart` | add / edit; create also offers an inline "remind me N days before" |
| `presentation/reminder_popover.dart` | `ReminderBell` — the per-item reminder sheet |

### Reminders ledger — `lib/features/reminders/`

| File | Purpose |
|---|---|
| `domain/reminder.dart` | `Reminder` / `ReminderDraft`; `ReminderContext` (`fixed_due`/`balance_buffer`/`maturity`), `ReminderFrequency` (`one_time`/`monthly`/`quarterly`); **`rolledForward`** display transform ported from web `rollForward` (a past recurring fixed-due jumps to its next occurrence, a stale one-off reads completed — no write-on-read); `reminderMessage` ported from `defaultMessage`. Web-only fields (`grace`, `verify_liquidity`, `maturity_leads`, `debt`, `source`) are **round-tripped verbatim** in `extra` |
| `data/reminders_gateway.dart` | `reminders` list / create / update / `setStatus` / delete |
| `application/reminders_providers.dart` | `remindersProvider` (rolled-forward), `activeRemindersProvider` |
| `application/reminders_editor_controller.dart` | create / update / complete / reopen / delete — session + role + **menu(`reminders`)** + online gate |
| `presentation/reminders_screen.dart` · `reminder_form_sheet.dart` | `/reminders` — chronological list, Done / Reopen / delete; the smart-field form (frequency shows only for `fixed_due`) |

### Notifications — `lib/features/notifications/`

| File | Purpose |
|---|---|
| `domain/planned_notification.dart` | **pure planner** `planNotifications({recurringItems, reminderSettings, reminders, now})` → deterministic `List<PlannedNotification>` with stable 31-bit ids. A bell fires `daysBefore` ahead at 09:00 local; a reminder fires on its due date at 09:00; past instants are dropped. Fully unit-tested |
| `data/notification_service.dart` | `NotificationService` seam + `LocalNotificationService` over `flutter_local_notifications` (init + `timezone`, permission request, cancel-all-then-reschedule). **Device-unverified** |
| `application/notification_coordinator.dart` | `NotificationCoordinator` — debounced recompute on any change to the three providers + on app resume; `cancelAll` on sign-out. `NotificationScope` mounted beside `SyncScope` in `app.dart` |

### Home

`home_upcoming_card.dart` replaces the M6 placeholder: merges recurring items
(next due ≤ 30 days) and active reminders (≤ 30 days), nearest first, top 4,
each row taps through to `/recurring` or `/reminders`. Hides itself when empty;
drops the reminders half when that menu is locked. `HomeUpcomingCard` moved out
of `home_placeholders.dart` (which keeps only `HomeInsightsCard`).

### Native (device-unverified)

- **Android** `AndroidManifest.xml`: `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`,
  and the three `flutter_local_notifications` receivers.
- **Android** `build.gradle.kts`: core-library desugaring +
  `desugar_jdk_libs:2.1.4` (plugin needs `java.time` on `minSdk` 23).
- **iOS** `AppDelegate.swift`: `UNUserNotificationCenter` delegate wiring.

### Routing

`/recurring` and `/reminders` are real screens; their "M12" tags are removed
from the More list.

---

## 3. Verification

| Check | Result |
|---|---|
| `flutter analyze` | ✅ **No issues found** |
| `flutter test` | ✅ **334 passing** (273 from M1–M11 + 61 new) |
| Device / emulator run | ⚠️ **not performed** — no Android SDK (M2 I-1). Screens are widget-tested against overridden providers; `bumpDate`, `ReminderSetting.isDue`, `Reminder.rolledForward` / `reminderMessage`, both editor controllers and the notification planner against fakes / pinned dates. |

New test files: `recurring/bump_date_test`, `recurring/reminder_setting_test`,
`recurring/recurring_editor_test`, `recurring/recurring_screen_test`,
`reminders/reminder_test`, `reminders/reminders_editor_test`,
`reminders/reminders_screen_test`, `notifications/notification_plan_test`,
`home/home_upcoming_card_test`.

---

## 4. Issues / risks

| # | Issue | Impact | Action |
|---|---|---|---|
| I-51 | **`flutter_local_notifications` is device-unverified** (same status `workmanager` had at M5). The Android receivers / `POST_NOTIFICATIONS` / desugaring and the iOS delegate are wired but not exercised — no Android SDK, no macOS. `LocalNotificationService` swallows every platform error. | Scheduled OS notifications may not fire until a device run. **The in-app "Upcoming" card is the primary, tested surface.** | First device run |
| I-52 | Notifications are **scheduled from the client** while the app runs — `NotificationCoordinator` recomputes on data change / resume. No server push, no background job. If the app is never opened, nothing new is scheduled and `nextDueDate` never advances (that needs "Mark paid"). | A user who never opens the app gets no nudges | Matches the web (no cron either); a push channel is a later phase |
| I-53 | Reminders are **INR-first** — the form has no currency picker; a web-created reminder's currency is preserved and displayed. Recurring templates are written `currency: 'INR', fx_rate: 1`; the web's multi-currency + FX-rate fields are web-only. | A non-INR recurring item created on mobile loses its currency intent | Matches M11 I-48 (V1 is INR) |
| I-54 | The **reminders** model is simplified: `debt` installment linkage, `grace`, `verify_liquidity` and `maturity_leads` are **round-tripped but not editable** on mobile. Debt linkage in particular depends on the debts feature, which is CUT from V1 (Money Owed/Relationships). | A debt-linked or liquidity-check reminder shows as a plain reminder on mobile; editing it keeps those fields intact | Widen if the debts feature returns |
| I-55 | `recurring_items` RLS is `auth.uid() = user_id` (not tenant-membership). A workspace admin **cannot** edit or mark a recurring item another member created; they see it (tenant-scoped query) but writes 42501. | Mirrors the web exactly | By design |
| I-56 | `mark_recurring_generated` writes the transaction **server-side**, outside the M5 outbox. The screen calls `syncNow(force)` right after, but the new row is only in the local cache once that pull completes — a beat of lag, and nothing if the pull fails. | Brief delay before the generated transaction appears in the ledger / Home feed | Acceptable; the RPC is the idempotency guarantee (BUG-104) |
| I-57 | The Home "Upcoming" card and the two screens read **online-only** providers. Offline they simply show nothing / an error-retry; they never populate from cache. | No offline view of what's coming up | Matches the M1 cache policy for these tables |

None block M13.

---

## 5. Phase status

| Phase | | Status |
|---|---|---|
| M1 – M11 | … · investments · net worth | ✅ |
| M1.5 | `apply_transaction_mutation` + `client_mutations` (backend package, rev 2) | ⏳ awaiting web-owner review + apply |
| **M12** | **Recurring + Reminders + local notifications** | ✅ **complete** (this report) |
| M13 | Bill scan (camera / OCR) | ⬜ **next** |
| M14–M20 | voice · AI · tablet · a11y · security · testing · release | ⬜ |

**Completed: 12 of 20** (M1–M12).

---

## 6. Next — M13 (Bill scan)

Camera capture + OCR to pre-fill a Quick Add draft (`image_picker` / `camera`,
`image`; menu `bill-scan`). Whether OCR runs on-device or via an Edge Function
is the first design call.

**Stopping here for approval, per the phase-gate rule.**
