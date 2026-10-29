import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/providers/providers.dart';
import '../domain/live_price.dart';

/// Asks the `live-price` edge function for a batch of prices — the same
/// function and request the web dashboard uses, so both devices share its
/// cache. Prices only; a failure is an empty map (the screen then simply
/// shows stored values), never an error dialog.
abstract interface class LivePriceGateway {
  Future<Map<String, double>> fetch(List<LiveWant> wants);
}

class SupabaseLivePriceGateway implements LivePriceGateway {
  SupabaseLivePriceGateway(this._client);
  final SupabaseClient _client;
  final _log = AppLog.of('live-price');

  /// The function's own sanity bound on one request.
  static const maxSymbols = 100;

  @override
  Future<Map<String, double>> fetch(List<LiveWant> wants) async {
    if (wants.isEmpty) return const {};
    try {
      final res = await _client.functions.invoke(
        'live-price',
        body: {
          'symbols': [for (final w in wants.take(maxSymbols)) w.toJson()],
        },
      );
      return parseLivePrices(res.data);
    } on Object catch (e) {
      _log.warning('live-price failed: ${e.runtimeType}');
      return const {};
    }
  }
}

/// `{ prices: { "yahoo:ITC.NS": 265.5, "mf:119551": null } }` → the numbers.
Map<String, double> parseLivePrices(Object? data) {
  if (data is! Map) return const {};
  final prices = data['prices'];
  if (prices is! Map) return const {};
  final out = <String, double>{};
  prices.forEach((k, v) {
    final n = v is num ? v.toDouble() : double.tryParse('$v');
    if (k is String && n != null && n.isFinite && n > 0) out[k] = n;
  });
  return out;
}

final livePriceGatewayProvider = Provider<LivePriceGateway>(
  (ref) => SupabaseLivePriceGateway(ref.watch(supabaseClientProvider)),
  name: 'livePriceGateway',
);
