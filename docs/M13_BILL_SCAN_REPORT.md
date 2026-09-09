# M13 — Bill scan · completion report

**Date:** 2026-09-09 · **Status:** complete, awaiting approval for M14
**Repo:** `F:\Movie\AK\Finroot App` · builds on `e37a6da` (M12)

---

## 1. Scope

Photograph a receipt → the **shared `scan-receipt` Edge Function** (Gemini
vision) extracts merchant / line items / total → review and correct →
log **one expense** through the normal Quick Add write path (cache + outbox,
offline-safe).

- **No backend change.** The mobile client invokes the same Edge Function the
  web `BillScan.tsx` uses. That function already does `verify_jwt`, a workspace
  membership check, and a 30-scans/day rate limit (per workspace, via
  `audit_log`).
- **`bill-scan` is a navigation-only menu** (web `menuContract`
  `NAVIGATION_ONLY_MENUS`): the mobile gate hides the screen; it does not gate
  any table.
- New dependency: **`image_picker` 1.2.3** (camera + gallery). OCR itself is
  server-side — no on-device model. Downscaling happens at pick time via
  `image_picker`'s own `maxWidth` / `imageQuality`.

---

## 2. What M13 built — `lib/features/bill_scan/`

| File | Purpose |
|---|---|
| `domain/scan_result.dart` | `ScanResult` / `ScanItem` / `ScanTaxLine` — the Edge Function's JSON shape (mirrors web `ScanResult`). `normalizeScanCategory` snaps the function's slightly-wider category enum to a real `kExpenseCategories` value (only genuine alias: "Travel & Transport" → "Transport") so a scanned expense never renders as unknown |
| `domain/scanned_row.dart` | `ScannedRow` (`item` / `tax` kind), `ScanMode` (`lumpsum` / `lineItem`), and the pure functions **ported with parity tests** from web `src/lib/billScan.ts`: `rowsFromScanResult` (one row per item + one per tax line, never merged; lumpsum uses the *stated* total, not a re-sum), `buildApprovalTransaction` (always ONE expense — sums current rows, majority category), `Reconciliation.of` (cross-check vs the printed total, ₹0.50 tolerance), `partitionRows` |
| `domain/captured_image.dart` | `CapturedImage` (bytes + mime + base64), `validateNewImages` (≤ 5 images, ≤ 8MB, JPG/PNG/WEBP — ported from web `validateNewFiles`), `mimeFromPath` |
| `data/receipt_camera.dart` | `ReceiptCamera` seam + `ImagePickerReceiptCamera` (camera / multi-gallery, downscaled). **Camera is device-unverified** |
| `data/receipt_scan_gateway.dart` | `ReceiptScanGateway` → `functions.invoke('scan-receipt', …)`; maps `FunctionException` status (401/403/422/429/400/5xx) to a `Failure` with the server's own message |
| `application/bill_scan_controller.dart` | `BillScanController` (`Notifier<BillScanState>`) — stage photos → `scan()` (tenant + online gate) → review → `setMode` / `editRow` / `removeRow` → `approve()` (submits via `quickAddControllerProvider`, then resets). A new photo after a scan invalidates the result |
| `presentation/bill_scan_screen.dart` · `row_edit_sheet.dart` | `/bill-scan` — three phases (staging / scanning / review); thumbnail strip, whole-bill ↔ line-items toggle, editable item cards, a compact tax strip, a reconciliation warning, "Log expense · ₹total" |

### Routing / native

- `/bill-scan` is a real screen; its "M13" tag is removed from the More list.
- **Android**: `image_picker` needs no manifest changes (camera goes through the
  system camera app; gallery uses the Photo Picker).
- **iOS** `Info.plist`: `NSCameraUsageDescription` + `NSPhotoLibraryUsageDescription`
  (device-unverified — no iOS toolchain).

---

## 3. Verification

| Check | Result |
|---|---|
| `flutter analyze` | ✅ **No issues found** |
| `flutter test` | ✅ **370 passing** (334 from M1–M12 + 36 new) |
| Device / emulator run | ⚠️ **not performed** — no Android SDK (M2 I-1). The camera path (`ImagePickerReceiptCamera`) and a real `scan-receipt` round-trip are unexercised. Everything else — the row arithmetic, category snapping, image validation, the whole controller flow (fake camera + fake gateway + fake Quick Add), and the screen's three phases — is tested. |

New test files: `bill_scan/scanned_row_test`, `bill_scan/captured_image_test`,
`bill_scan/scan_result_test`, `bill_scan/bill_scan_controller_test`,
`bill_scan/bill_scan_screen_test`.

---

## 4. Issues / risks

| # | Issue | Impact | Action |
|---|---|---|---|
| I-58 | **Camera capture is device-unverified** (no Android SDK). `image_picker` errors are caught and surfaced as a failure. | The scanner cannot be exercised end-to-end until a device run | First device run |
| I-59 | The scan itself needs a **connection** and a working `GEMINI_API_KEY` on the server. Offline, `scan()` returns a `NetworkFailure` before any upload. The *approve* step is offline-safe (normal outbox write). | No offline scanning | By design — matches the web |
| I-60 | Scanned receipts always log as an **expense in INR**. A non-INR receipt's `currency` is read for display but the approved transaction uses the row currency as-is; there is no FX step. | A foreign receipt logs at face value | Matches M11 I-48 / M12 I-53 (V1 is INR) |
| I-61 | The mobile scanner **always logs ONE transaction** (web parity). It does not create per-item transactions, and there is no line-item ledger. The whole-bill ↔ line-items toggle only changes what you *review*. | A user wanting each item as its own row can't | Matches web `buildApprovalTransaction`; deliberate (tax lines as ledger rows read as clutter) |
| I-62 | The Edge Function's category enum and `kExpenseCategories` are kept in step **by hand** (`normalizeScanCategory`). If the web function adds a category, an un-mapped one falls back to "Other". | A new server category silently becomes "Other" until the map is updated | Low; revisit if the web function's `CATEGORIES` list changes |
| I-63 | The 30/day scan **rate limit is server-side only** — the mobile app shows the 429 message but has no local counter or pre-emptive warning. | A heavy user hits the wall mid-task | Acceptable; the message is clear |

None block M14.

---

## 5. Phase status

| Phase | | Status |
|---|---|---|
| M1 – M12 | … · recurring · reminders · notifications | ✅ |
| M1.5 | `apply_transaction_mutation` + `client_mutations` (backend package, rev 2) | ⏳ awaiting web-owner review + apply |
| **M13** | **Bill scan** | ✅ **complete** (this report) |
| M14 | Voice capture (`speech_to_text`) | ⬜ **next** |
| M15–M20 | AI insights · tablet · a11y · security · testing · release | ⬜ |

**Completed: 13 of 20** (M1–M13).

---

## 6. Next — M14 (Voice capture)

Speak an expense ("spent 400 on groceries") → parse to a Quick Add draft
(`speech_to_text`, `permission_handler`). Whether parsing is a local grammar or
an Edge Function (Gemini) is the first call — the bill-scan pattern (thin
client, shared Edge Function) is the likely template.

**Stopping here for approval, per the phase-gate rule.**
