import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../error/failure.dart';
import 'app_logger.dart';

/// Logs provider failures (and, in debug, lifecycle) without ever printing a
/// provider's value — a provider may hold finance data.
final class ProviderLogger extends ProviderObserver {
  const ProviderLogger();

  static final _log = AppLog.of('riverpod');

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    // Never forward the raw error object — a `PostgrestException` /
    // `AuthException` toString() carries the server's message / details / hint,
    // which §12 says must not reach a device log. A mapped `Failure` is safe
    // (its toString() is `runtimeType: <fixed copy>`); anything else is
    // reduced to its type. The stack trace (code locations only) is kept.
    final safe = error is Failure ? error : error.runtimeType;
    _log.warning(
      'provider "${context.provider.name ?? context.provider.runtimeType}" '
      'failed',
      safe,
      stackTrace,
    );
  }

  @override
  void didAddProvider(ProviderObserverContext context, Object? value) {
    if (kDebugMode) {
      _log.finer('+ ${context.provider.name ?? context.provider.runtimeType}');
    }
  }

  @override
  void didDisposeProvider(ProviderObserverContext context) {
    if (kDebugMode) {
      _log.finer('- ${context.provider.name ?? context.provider.runtimeType}');
    }
  }
}
