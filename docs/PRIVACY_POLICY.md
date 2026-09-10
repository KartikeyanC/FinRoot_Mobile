# FinRoot Mobile — privacy policy (DRAFT)

> **Status: DRAFT for legal review (R-M20-2).** This is engineering's description
> of what the app does with data, written in policy form. It must be reviewed by
> whoever owns FinRoot's legal/privacy posture, aligned with the FinRoot **web**
> privacy policy (same backend, same account), and **hosted at a public URL**
> before either store submission. The stores require the policy to be reachable
> without installing the app.

**Last updated:** _[date on publish]_

## Who we are

FinRoot ("we", "the app") is a personal-finance app for Android and iOS. It uses
the same account and backend as the FinRoot web application.

## What we collect and why

- **Your email address** — to create and sign you into your account.
- **Your financial records** — the transactions, accounts, balances, budgets,
  goals, trackers, investments, net-worth entries, recurring items and reminders
  you enter or that are already in your FinRoot account. This is the information
  the app exists to manage.
- **Receipt photos you choose to scan** — sent to our receipt-reading service to
  extract the amounts and items, then discarded. We do not keep the image after
  the scan completes.

We do **not** collect your location, contacts, or advertising identifiers. We do
**not** use analytics, advertising, or crash-reporting SDKs. We do **not** track
you across apps or websites.

**Microphone / voice:** if you use voice capture, your speech is transcribed by
your device's own speech recognition and the text is used to fill in a
transaction. Audio is not sent to us or stored.

## Where your data lives

- **On your device:** the app keeps an encrypted local copy of your financial
  data (AES-256) so it works offline. Signing out erases this local copy.
- **On our servers:** your data is stored in our backend database (Supabase),
  the same store used by FinRoot web, protected by row-level security so you only
  ever see your own workspaces. All traffic between the app and the backend is
  encrypted (TLS).

## Who we share it with

We do not sell your data and we do not share it with third parties for their own
purposes. We use service providers strictly to run FinRoot:

- **Supabase** — database, authentication and file storage (our processor).
- **Google (Gemini API)** — reads a receipt photo when you scan one, on our
  behalf, and does not retain it.

## Your choices

- **Access / export / delete:** manage your account and request deletion through
  FinRoot at _[account settings URL]_. Deleting your account removes your data
  from our backend.
- **Local data:** sign out in the app to wipe the on-device copy.
- **Permissions:** camera, photos, microphone and notifications are all optional
  and only requested when you use the related feature. You can revoke them in
  your device settings.

## Children

FinRoot is not directed to children and we do not knowingly collect data from
anyone under 13 (or the equivalent age in your country).

## Changes

We will post any changes to this policy at this URL and update the date above.

## Contact

_[privacy contact email / address]_
