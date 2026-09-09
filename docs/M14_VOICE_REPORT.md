# M14 — Voice capture · completion report

**Date:** 2026-09-09 · **Status:** complete, awaiting approval for M15
**Repo:** `F:\Movie\AK\Finroot App` · builds on `d58002b` (M13)

---

## 1. Scope

Speak a transaction — *"spent 400 on groceries with card yesterday"* — and the
app transcribes it **on device**, parses it with a **local grammar** to a Quick
Add draft, lets you review / correct, then logs it through the normal write
path (cache + outbox, offline-safe).

- **No backend, no Edge Function, no NLU model.** The transcript → draft step is
  a deterministic regex/keyword parser (`voice_parse.dart`). This keeps voice
  entry **fully offline** and cheap. A Gemini-backed parser is noted as a future
  enhancement (I-66).
- **No menu gate** — there is no `voice` feature menu (the web has no voice
  feature). Session + role gate the write (via `QuickAddController`).
- New dependency: **`speech_to_text` 7.4.0** (it manages its own mic
  permission; `permission_handler` was not needed).

---

## 2. What M14 built — `lib/features/voice/`

| File | Purpose |
|---|---|
| `domain/voice_parse.dart` | `VoiceDraft` + **`parseUtterance(transcript, {now})`** — a local grammar that extracts: **amount** (`400`, `rs 1,200`, `₹2.5k`, `1.2 lakh`, `500 rupees`, decimals), **kind** (spend verbs → expense, `got`/`received`/`salary` → income, `moved`/`transfer` → transfer), **category** (a synonym table → a `kExpenseCategories` / `kIncomeCategories` value), **payment mode** (`upi`/`gpay`/`phonepe` → UPI, etc.), **date** (`today`, `yesterday`, `day before yesterday`, `N days ago`, weekday names → most recent past occurrence), **note** (the object of "for"/"bought"). `understood` = an amount was found. `resolvedCategory` fills `Other` when nothing matched (the server requires a category) |
| `data/speech_service.dart` | `SpeechService` seam + `SpeechToTextService` (`ensureReady` → init + mic permission; `start` streams partial + final transcripts; `stop`). Dictation mode, 30s cap, 4s pause-to-finish. **Device-unverified** |
| `application/voice_capture_controller.dart` | `VoiceCaptureController` (`Notifier<VoiceCaptureState>`) — idle → listening (live transcript) → review; `editDraft` overrides any parsed field; `confirm()` submits via `quickAddControllerProvider` (refuses a transfer — those need two accounts — and an amount-less draft) |
| `presentation/voice_screen.dart` | `/voice` — a big mic button with the live transcript, then a review form (expense/income toggle, editable amount, category, payment mode, date, note) and "Log it" |

### Routing / native

- `/voice` is a real screen; its "M14" tag is removed from the More list.
- **Android** `AndroidManifest.xml`: `RECORD_AUDIO` + an `android.speech.RecognitionService` `<queries>` entry (Android 11+ package visibility).
- **iOS** `Info.plist`: `NSMicrophoneUsageDescription` + `NSSpeechRecognitionUsageDescription`.

---

## 3. Verification

| Check | Result |
|---|---|
| `flutter analyze` | ✅ **No issues found** |
| `flutter test` | ✅ **404 passing** (370 from M1–M13 + 34 new) |
| Device / emulator run | ⚠️ **not performed** — no Android SDK / mic (M2 I-1). `SpeechToTextService` is unexercised. The parser (23 cases), the whole controller flow (fake speech + fake Quick Add), and the screen's two phases are tested. |

New test files: `voice/voice_parse_test`, `voice/voice_capture_controller_test`,
`voice/voice_screen_test`.

---

## 4. Issues / risks

| # | Issue | Impact | Action |
|---|---|---|---|
| I-64 | **Speech recognition is device-unverified** (no Android SDK / mic). `SpeechToTextService` errors resolve to a "microphone is off" message. | Voice cannot be exercised end to end until a device run | First device run |
| I-65 | The parser is a **local grammar**, English-only, tuned for Indian-English money phrasing (`k` / `lakh` / `crore`, UPI apps). It handles the common shapes and leaves anything ambiguous null for the review step to fill; it will miss unusual phrasings. | A messy sentence lands on the review form with fields blank rather than wrong | The review step is always shown — nothing is logged unseen |
| I-66 | No **AI / Edge Function** parsing. A Gemini-backed parser (like `scan-receipt`) would be far more robust but needs a new Edge Function (web-owner coordination) and a connection. | Lower accuracy than an LLM would give | Revisit alongside M15 (AI insights), which will already be adding an AI surface |
| I-67 | **Word-number amounts** ("twelve hundred") are not parsed — only digits (+ `k`/`lakh`/`crore` suffixes). | "spent twelve hundred on fuel" → no amount, review form blank amount | Low; most dictation produces digits |
| I-68 | **Transfers** are detected ("moved 5000 to savings") but not logged — the review form disables "Log it" and points to Quick Add, since a transfer needs a source and destination account. | A spoken transfer can't be completed here | By design; matches the account-picker requirement |
| I-69 | Voice always logs as **INR**. | A foreign-currency utterance logs at face value | Matches M11 I-48 / M12 I-53 / M13 I-60 (V1 is INR) |

None block M15.

---

## 5. Phase status

| Phase | | Status |
|---|---|---|
| M1 – M13 | … · notifications · bill scan | ✅ |
| M1.5 | `apply_transaction_mutation` + `client_mutations` (backend package, rev 2) | ⏳ awaiting web-owner review + apply |
| **M14** | **Voice capture** | ✅ **complete** (this report) |
| M15 | AI insights | ⬜ **next** |
| M16–M20 | tablet · a11y · security · testing · release | ⬜ |

**Completed: 14 of 20** (M1–M14).

---

## 6. Next — M15 (AI insights)

Spending-pattern insights and nudges on Home (the M6 "Insights" placeholder).
Almost certainly a **new shared Edge Function** (Gemini over the user's recent
aggregates) — so the first questions are what it's fed (derived figures only,
never raw rows off-device beyond what the dashboard already exposes), and
whether the web owner wants to own that function. This is the first M-phase
that likely **requires backend coordination**.

**Stopping here for approval, per the phase-gate rule.**
