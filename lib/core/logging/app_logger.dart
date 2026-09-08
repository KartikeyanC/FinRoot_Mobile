import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// App-wide logging.
///
/// Rules (M1 audit §12, brief §38): **never log** an amount, account id,
/// description, token, RPC payload, or a raw server exception body. Loggers
/// carry event names and coarse status only. [redact] is the escape hatch when
/// a value must be referenced at all.
abstract final class AppLog {
  static bool _init = false;

  static void init({Level level = kReleaseMode ? Level.WARNING : Level.ALL}) {
    if (_init) return;
    _init = true;
    Logger.root.level = level;
    Logger.root.onRecord.listen((r) {
      final line = '[${r.level.name}] ${r.loggerName}: ${r.message}';
      developer.log(
        line,
        name: 'finroot',
        level: r.level.value,
        error: r.error,
        stackTrace: r.stackTrace,
        time: r.time,
      );
      if (kDebugMode) {
        // ignore: avoid_print
        print(line);
      }
    });
  }

  static Logger of(String name) => Logger(name);
}

/// Collapse a potentially sensitive value to something safe to log:
/// `redact("aji@example.com")` -> `a***@e***`, `redact(<uuid>)` -> `1a2b…`.
String redact(Object? value) {
  final s = value?.toString() ?? 'null';
  if (s.isEmpty) return '∅';
  if (s.contains('@')) {
    final parts = s.split('@');
    return '${_head(parts.first)}@${_head(parts.last)}';
  }
  if (s.length <= 6) return '${s[0]}***';
  return '${s.substring(0, 4)}…';
}

String _head(String s) => s.isEmpty ? '∅' : '${s[0]}***';
