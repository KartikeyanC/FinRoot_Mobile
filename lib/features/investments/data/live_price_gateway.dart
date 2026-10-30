import 'dart:collection';

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

/// A batch of prices plus whether the lookup itself failed (as opposed to
/// nothing being asked for, or the function simply having no price).
class LivePriceResult {
  const LivePriceResult(this.prices, {this.failed = false});
  final Map<String, double> prices;
  final bool failed;
}

/// A [Map] of prices that also remembers the lookup failed, so the
/// Map-returning providers keep their type while the screen can say
/// "unavailable".
class LivePrices extends UnmodifiableMapView<String, double> {
  LivePrices(super.map, {this.lookupFailed = false});
  final bool lookupFailed;
}

/// Gateways that can tell a failed lookup from an empty answer.
abstract interface class CheckedLivePriceGateway implements LivePriceGateway {
  Future<LivePriceResult> fetchChecked(List<LiveWant> wants);
}

class SupabaseLivePriceGateway implements CheckedLivePriceGateway {
  SupabaseLivePriceGateway(this._client);
  final SupabaseClient _client;
  final _log = AppLog.of('live-price');

  /// The function's own sanity bound on one request.
  static const maxSymbols = 100;

  @override
  Future<Map<String, double>> fetch(List<LiveWant> wants) async =>
      (await fetchChecked(wants)).prices;

  @override
  Future<LivePriceResult> fetchChecked(List<LiveWant> wants) async {
    if (wants.isEmpty) return const LivePriceResult({});
    try {
      final res = await _client.functions.invoke(
        'live-price',
        body: {
          'symbols': [for (final w in wants.take(maxSymbols)) w.toJson()],
        },
      );
      final data = res.data;
      // The function answers 200 with `error` set when its own lookup broke.
      final failed = data is! Map || data['prices'] is! Map;
      if (failed) _log.warning('live-price returned no price map');
      return LivePriceResult(parseLivePrices(data), failed: failed);
    } on Object catch (e) {
      _log.warning('live-price failed: ${e.runtimeType}');
      return const LivePriceResult({}, failed: true);
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
