import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:decimal/decimal.dart';

/// Stage 7 — the phone's half of the ingestion de-dup key.
///
/// The Dart twin of `supabase/functions/_shared/ingest/normalize.ts`
/// (`canonicalDedupKey` / `computeRawPayloadHash`) in the web repo. The
/// database refuses a second row with the same `(tenant_id, raw_payload_hash)`
/// (migration `20261031120000_stage7_auto_ingest.sql`), so a payment seen in a
/// bank SMS here and again in an AA feed or a bank e-mail is stored once —
/// but only while both sides build the SAME string. The test vectors in
/// `test/features/payment_capture/ingest_hash_test.dart` are copied from
/// `normalize.test.ts`; change both in one commit, or neither.
///
///   user_id | amount (2 dp) | type | occurred_at as UTC minute | account_last4

/// `income` / `expense` — the only types an ingested row can have.
enum IngestType {
  income,
  expense;

  String get wire => name;
}

/// "2026-10-31T08:35Z" — the minute the hash is bucketed on, always UTC so a
/// phone in IST and a webhook in UTC agree.
String utcMinute(DateTime at) {
  final u = at.toUtc();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${u.year.toString().padLeft(4, '0')}-${two(u.month)}-${two(u.day)}'
      'T${two(u.hour)}:${two(u.minute)}Z';
}

String canonicalDedupKey({
  required String userId,
  required Decimal amount,
  required IngestType type,
  required DateTime occurredAt,
  String? accountLast4,
}) => [
  userId.trim().toLowerCase(),
  amount.toStringAsFixed(2),
  type.wire,
  utcMinute(occurredAt),
  accountLast4 ?? '',
].join('|');

/// Hex SHA-256 of [canonicalDedupKey].
String rawPayloadHash({
  required String userId,
  required Decimal amount,
  required IngestType type,
  required DateTime occurredAt,
  String? accountLast4,
}) => sha256
    .convert(
      utf8.encode(
        canonicalDedupKey(
          userId: userId,
          amount: amount,
          type: type,
          occurredAt: occurredAt,
          accountLast4: accountLast4,
        ),
      ),
    )
    .toString();
