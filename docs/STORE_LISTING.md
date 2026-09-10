# FinRoot Mobile — store listing copy (M20)

**Date:** 2026-09-10 · Draft copy for Google Play and the App Store. Product/
marketing owns final wording; this is a complete, submittable starting point that
matches what the app actually does as of M19.

---

## Identity

| Field | Value |
|---|---|
| App name (both stores) | **FinRoot** |
| Android package | `com.finroot.mobile` |
| iOS bundle id | `com.finroot.mobile` |
| Version / build (first submission) | `1.0.0 (1)` — see `docs/RELEASE.md` §Versioning |
| Primary category | Finance |
| Secondary category (Play) | — |
| Content rating | Everyone / 4+ (see `docs/COMPLIANCE.md` §5) |
| Price | Free, no in-app purchases, no ads |
| Countries | **PRODUCT** — default India-first (en_IN money formatting); confirm the wider list |

---

## Google Play

**App name** (30 chars max): `FinRoot`

**Short description** (80 chars max):
> Track daily spending, accounts and budgets — works offline, syncs when you're back.

**Full description** (4000 chars max):
> FinRoot is a fast, private way to stay on top of your money every day.
>
> Log an expense in seconds — type it, snap the receipt, or just say it. Your
> accounts, budgets, trackers and goals stay up to date whether or not you have
> a signal; FinRoot saves everything locally and syncs in the background the
> moment you're back online.
>
> **Capture**
> • Quick Add for expenses, income and transfers
> • Scan a receipt and FinRoot pulls out the line items
> • Speak a transaction — "spent 250 on groceries yesterday" — and review before saving
>
> **See where you stand**
> • A home feed that leads with your real balance across every account
> • Spending by category, month over month
> • Budget jars with progress and days remaining
> • Savings goals with contributions
> • Trackers to tag any set of transactions — a trip, a project, a person — without moving money
> • Investments and net worth in one place
>
> **Stay ahead**
> • Recurring items and reminders, with local notifications
> • Plain-language insights: overspending, unusual months, goals within reach
>
> **Built for phones and tablets** — one app, a layout that adapts to a bigger screen.
>
> **Private by default**
> • Your financial data is encrypted on your device
> • All traffic is encrypted in transit
> • No ads, no trackers, no selling your data
>
> FinRoot shares its backend with the FinRoot web app — sign in with the same
> account and your data is already there.

**Tags / keywords** (Play uses the description; no separate keyword field.)

**Graphic assets required** — see §Assets checklist below.

---

## App Store

**Name** (30 chars): `FinRoot`

**Subtitle** (30 chars): `Daily money, works offline`

**Promotional text** (170 chars, updatable without review):
> Capture expenses by typing, scanning a receipt, or speaking. Budgets, goals and
> balances that stay current offline and sync when you're back.

**Description** (4000 chars) — reuse the Play full description above (drop the
"one app for phones and tablets" line only if you ship an iPhone-only build;
current build supports iPad).

**Keywords** (100 chars, comma-separated, no spaces):
> budget,expense,money,finance,tracker,spending,savings,offline,receipt,accounts,personal finance

**Support URL:** `https://<finroot-domain>/support` — **PRODUCT**
**Marketing URL** (optional): `https://<finroot-domain>`
**Privacy Policy URL** (required): `https://<finroot-domain>/privacy` — **LEGAL**, draft in `docs/PRIVACY_POLICY.md`

**App Review notes:**
> Sign-in required (email + password). Test account:
>   email: <REVIEW_ACCOUNT_EMAIL>
>   password: <REVIEW_ACCOUNT_PASSWORD>
> The account is pre-populated with sample transactions, accounts and budgets.
> Bill scan uses a server function (Gemini vision) to read a receipt photo;
> voice capture is on-device. No other backend services.

**PRODUCT/ENG:** create the review account in the shared Supabase project before
submission and keep it seeded.

---

## Assets checklist (cannot be produced without a device / designer)

| Asset | Spec | Status |
|---|---|---|
| App icon (adaptive, Android) | 512×512 PNG + adaptive foreground/background | ❌ still the default Flutter icon — **BLOCKER**, see `docs/RELEASE.md` §Icon |
| App icon (iOS) | 1024×1024 PNG, no alpha | ❌ default |
| Play feature graphic | 1024×500 PNG | ❌ |
| Play phone screenshots | 2–8, 16:9 or 9:16, min 1080px | ❌ needs a device/emulator |
| Play 7" + 10" tablet screenshots | 2–8 each (adaptive layout is a selling point — show two-pane) | ❌ |
| App Store 6.7" iPhone screenshots | 3–10, 1290×2796 | ❌ needs a Mac + simulator |
| App Store 13" iPad screenshots | 3–10, 2048×2732 | ❌ |
| App preview video (optional) | — | skip for v1 |

**Screenshot plan** (once hardware exists — 5 frames, same on both stores):
1. Home feed with a real balance + sync chip
2. Quick Add (expense) with the account picker
3. Bill scan review screen
4. Budgets with jar progress
5. Tablet two-pane (Transactions list + detail) — landscape

Suggested captions: "Your balance, always current" · "Log it in seconds" ·
"Scan a receipt" · "Budgets that keep up" · "Made for your tablet too".
