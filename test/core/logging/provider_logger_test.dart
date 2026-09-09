import 'package:finroot_mobile/core/error/failure.dart';
import 'package:finroot_mobile/core/logging/provider_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// M18 F-1 — a provider failure must not put a raw backend exception body
/// (server message / details / hint) into the device log.

Future<LogRecord> _failAndCapture(Object thrown) async {
  final records = <LogRecord>[];
  Logger.root.level = Level.ALL;
  final sub = Logger.root.onRecord.listen(records.add);
  addTearDown(sub.cancel);

  final container = ProviderContainer(observers: const [ProviderLogger()]);
  addTearDown(container.dispose);

  // `providerDidFail` fires for a synchronous build failure.
  final p = Provider<int>((ref) => throw thrown, name: 'thing');
  expect(() => container.read(p), throwsA(anything));
  await Future<void>.delayed(Duration.zero);

  return records.firstWhere((r) => r.message.contains('failed'));
}

void main() {
  test('a raw PostgrestException is reduced to its type', () async {
    final record = await _failAndCapture(
      const PostgrestException(
        message: 'relation "secret_internal_table" does not exist',
        code: '42P01',
        hint: 'do not surface this',
      ),
    );

    expect(record.error, isNot(isA<PostgrestException>()));
    expect('${record.error}', isNot(contains('secret_internal_table')));
    expect('${record.error}', isNot(contains('do not surface this')));
    // The stack trace (code locations only) is still kept for debugging.
    expect(record.stackTrace, isNotNull);
  });

  test('a mapped Failure passes through (its toString is fixed, safe copy)', () async {
    final record = await _failAndCapture(const UnexpectedFailure());
    expect(record.error, isA<Failure>());
  });
}
