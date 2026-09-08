import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    _log.warning(
      'provider "${context.provider.name ?? context.provider.runtimeType}" failed',
      error,
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
