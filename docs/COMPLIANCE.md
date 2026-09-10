# FinRoot Mobile — store compliance pack (M20)

**Date:** 2026-09-10 · Feeds Play Console + App Store Connect submission.
Everything here is **derived from the codebase** (dependencies, data flows,
manifests). Items marked **LEGAL** need sign-off from whoever owns FinRoot's
legal/privacy posture before first submission — this document is the engineering
input to that review, not the review itself.

---

## 1. What data the app handles

| Data | Source | Where it goes | Stored on device? | Purpose |
|---|---|---|---|---|
| Email address | user types at sign-in | Supabase Auth (`ludbntvhagefadfkhrjj`) | keystore session token only, not the address | authentication |
| Password | user types | Supabase Auth over HTTPS, never stored by the app | no | authentication |
| Financial records — transactions, accounts, trackers, budgets, goals, investments, net-worth entries, recurring items, reminders | user enters, or synced from the shared FinRoot backend | Supabase Postgres (shared with FinRoot web) | **yes — encrypted** Drift/SQLite cache (M4), AES-256 | the app's core function: offline money tracking |
| Receipt images (bill scan, M13) | device camera / photo library | POSTed to the `scan-receipt` Supabase Edge Function (Gemini vision), not retained by the app after the scan returns | transient only | extract line items from a receipt |
| Microphone audio (voice capture, M14) | device mic | **on-device** speech-to-text; the transcript is parsed locally. Audio never leaves the device. | no | pre-fill a transaction from speech |
| Device connectivity state | `connectivity_plus` | never leaves the device | no | drive the offline/online sync UI |

**Not collected:** no advertising ID, no analytics SDK, no crash-reporting SDK,
no location, no contacts, no third-party trackers. Grep confirms: the only
network egress is `*.supabase.co` (auth, PostgREST, Realtime, Storage, Edge
Functions).

---

## 2. Google Play — Data safety form answers

**Does your app collect or share any of the required user data types?** Yes.

| Play category | Collected | Shared | Processed ephemerally | Required | Purpose | Encrypted in transit |
|---|---|---|---|---|---|---|
| Personal info → Email address | Yes | No¹ | No | Yes (to use the app) | App functionality; Account management | Yes |
| Financial info → "Other financial info" (user's own transactions/balances) | Yes | No¹ | No | Yes | App functionality | Yes |
| Photos (bill scan) | Yes | No¹ | **Yes** (not retained) | No | App functionality | Yes |
| App activity / App info & performance / Location / Contacts / Audio | **No** | No | — | — | — | — |

¹ "Shared" in Play's sense = transfer to a *third party*. Supabase is FinRoot's
own backend processor under a DPA, not a third party, so these are **collected,
not shared**. **LEGAL:** confirm the Supabase relationship is documented as a
processor/sub-processor and that this classification holds.

**Security practices to declare:**
- Data is encrypted in transit (HTTPS/TLS, enforced — `usesCleartextTraffic=false`).
- Data is encrypted at rest on the device (AES-256, M4).
- Users can request data deletion — **LEGAL/PRODUCT:** FinRoot web is the system
  of record; point the Play "data deletion" URL at FinRoot's existing account
  deletion path. The mobile app's sign-out wipes the local copy (M18 F-2).
- Independent security review: no (self-reviewed, M18).

**Account deletion URL (required):** `https://<finroot-domain>/account/delete`
— **PRODUCT:** provide the real URL; must be reachable without installing the app.

---

## 3. Apple — App Privacy ("nutrition label") answers

**Data used to track you:** none.

**Data linked to you:**
- **Contact Info → Email Address** — App Functionality.
- **Financial Info → Other Financial Info** — App Functionality.
- **User Content → Photos or Videos** (receipt images) — App Functionality.

**Data not linked to you:** none additional.

For every item: not used for tracking, not used for third-party advertising, not
used for developer's advertising or marketing, not shared with data brokers.

**Audio data:** *not declared* — the mic transcript is produced by the OS
speech recogniser on-device and the app never transmits or stores audio. Apple's
guidance treats on-device-only processing that isn't sent anywhere as not
collected. **LEGAL:** confirm, given `speech_to_text` may fall back to a network
recogniser on some OS versions — if a network recogniser is ever used, "Audio
Data → App Functionality (not linked)" must be added. Consider forcing
`onDevice: true` (see R-M20-1).

---

## 4. Export compliance / encryption

The app uses:

1. **HTTPS / TLS** for all backend traffic — **exempt** (standard, via OS).
2. **AES-256** local database encryption, SQLite3MultipleCiphers compiled from
   source and bundled in the binary (M4) — **non-exempt** cryptography under EAR
   Category 5 Part 2 (5D002). This is why `ITSAppUsesNonExemptEncryption` is
   `true` in `ios/Runner/Info.plist`.

**Consequence — required filings before first public release (LEGAL):**

| Filing | Who | When |
|---|---|---|
| One-time **self-classification report** to the U.S. BIS + NSA/ENC (`crypt@bis.doc.gov`, `enc@nsa.gov`) for mass-market software using ENC / 740.17(b)(1) | FinRoot legal / export | before first submission |
| **Annual self-classification report** to BIS covering the calendar year | FinRoot legal | by Feb 1 each year |
| **French encryption declaration** (if distributing in France) | FinRoot legal | before FR availability |
| App Store Connect: upload the year's compliance documentation, or answer the export questions per build; a `.storekit`/compliance doc avoids the per-build prompt | release owner | each version, or once per year with doc |
| Play Console: no separate crypto filing, but the U.S. export laws checkbox on the app content page must be answered truthfully | release owner | once |

**Alternative position (needs counsel):** some finance apps treat local
data-at-rest encryption of the *user's own data* as ancillary and claim an
exemption, setting the flag to `false`. That is a legal call — **do not flip the
flag without written sign-off.** The conservative default in this repo is `true`.

---

## 5. Content rating

| Questionnaire | Answer |
|---|---|
| Violence, sexual content, profanity, controlled substances, gambling | none |
| User-generated content shared with others | no |
| Unrestricted web access | no |
| Data collection | yes — see §2/§3 |
| **Expected result** | Play: *Everyone* / *PEGI 3* · App Store: *4+* |
| Simulated gambling / real-money gambling | no |
| "Made for Kids" / child-directed | **no** — set explicitly; app is a personal-finance tool for adults |

---

## 6. Permissions ledger (store "why" strings)

| Platform | Permission | Trigger | User-facing string |
|---|---|---|---|
| Android | `INTERNET` | always | (no prompt) |
| Android | `POST_NOTIFICATIONS` | first reminder/recurring alert | system prompt; rationale shown in-app before requesting |
| Android | `RECEIVE_BOOT_COMPLETED` | — | (no prompt) re-arms scheduled reminders after reboot |
| Android | `RECORD_AUDIO` | user taps the voice-capture mic | system prompt |
| iOS | `NSCameraUsageDescription` | bill scan → camera | "FinRoot uses the camera so you can photograph a receipt to log an expense." |
| iOS | `NSPhotoLibraryUsageDescription` | bill scan → gallery | "FinRoot needs photo access so you can pick a receipt image to scan." |
| iOS | `NSMicrophoneUsageDescription` | voice capture | "FinRoot uses the microphone so you can speak an expense to log it." |
| iOS | `NSSpeechRecognitionUsageDescription` | voice capture | "FinRoot transcribes your speech on device to pre-fill a transaction." |

No background-location, no tracking permission (`NSUserTrackingUsageDescription`
is deliberately absent — the app does not track).

---

## 7. Open items for release owner

| # | Item | Owner |
|---|---|---|
| R-M20-1 | Pass `onDevice: true` to `speech_to_text` so audio can never reach a network recogniser — simplifies §3 audio declaration | eng |
| R-M20-2 | Real privacy-policy URL, hosted, reachable without the app (draft: `docs/PRIVACY_POLICY.md`) | legal + web owner |
| R-M20-3 | Real account-deletion URL for the Play Data safety form | product + web owner |
| R-M20-4 | Export self-classification filings (§4) | legal |
| R-M20-5 | Confirm Supabase DPA / sub-processor documentation for the "collected not shared" classification | legal |
| R-M20-6 | Decide `ITSAppUsesNonExemptEncryption` final value with counsel | legal |
