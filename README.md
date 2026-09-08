# FinRoot Mobile

A mobile-first Flutter client for FinRoot — daily money control on Android and
iOS phones, with an adaptive tablet layout in the **same codebase**.

It is not a port of the FinRoot web dashboard. It shares the web app's
**backend, database, auth, RLS, tenant model and financial data**, and nothing
else: no second ledger, no duplicate transactions, no parallel business rules.

- Architecture audit: [`docs/M1_ARCHITECTURE_AUDIT.md`](docs/M1_ARCHITECTURE_AUDIT.md)
- Foundation report: [`docs/M2_FOUNDATION_REPORT.md`](docs/M2_FOUNDATION_REPORT.md)
- Decisions: [`docs/adr/`](docs/adr/)

## Requirements

| Tool | Version used |
|---|---|
| Flutter | 3.47.2 stable (`F:\flutter`) |
| Dart | 3.13.2 |
| Android SDK | **not installed yet** — needed to build/run on Android |
| Xcode | macOS only — iOS builds are not possible on this machine |

Add Flutter to `PATH` (`F:\flutter\bin`) or call it by full path.

## Configure

Build-time config comes from a git-ignored JSON file — nothing secret is
committed. Copy the template and fill it in:

```bash
cp config/dev.example.json config/dev.json
```

`SUPABASE_ANON_KEY` is the **publishable/anon** key. A `service_role` key must
never appear in this repo, in a `--dart-define`, or in a build.

## Run

```bash
flutter run --dart-define-from-file=config/dev.json
```

## Checks

```bash
flutter analyze && flutter test && dart format --set-exit-if-changed lib test
```

## Layout

```
lib/
  app/          MaterialApp + GoRouter
  bootstrap.dart  guarded async startup
  core/
    config/     compile-time config (dart-define)
    error/      Failure types + one error mapper
    logging/    redacting logger + Riverpod observer
    money/      Money (Decimal), currency, formatting
    providers/  Riverpod roots (config, supabase, auth, connectivity)
    supabase/   client init + keystore-backed session storage
  design/       tokens → theme → components (the design system)
  domain/       shared value lists mirrored from the web repo
  features/     one folder per feature, presentation-first
  navigation/   destinations, adaptive shell, quick-add entry
```

## Rules that do not bend

- **Trackers are a dimension, not a ledger.** `transactions.tracker_id` is one
  optional nullable column. Assigning one never moves money.
- **Money is `Decimal`, never `double`.** The server column is `numeric(14,2)`.
- **Every read filters `tenant_id`; every write sets it.** RLS returns rows for
  all of a user's workspaces.
- **Never log** an amount, account id, description, token or raw server error.
- **Never edit an existing Supabase migration.** Backend changes are additive
  and coordinated with the web app's owner.
