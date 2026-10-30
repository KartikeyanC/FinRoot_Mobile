import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/providers.dart';
import '../domain/symbol_search.dart';

/// Looks a stock, fund or coin up by name through the `live-price` function
/// (`{ search: { provider, q } }`), like the web. Empty on any failure -
/// typing the ticker by hand still works.
abstract interface class SymbolSearchGateway {
  Future<List<SymbolHit>> search({required String asset, required String query});
}

class SupabaseSymbolSearchGateway implements SymbolSearchGateway {
  SupabaseSymbolSearchGateway(this._client);
  final SupabaseClient _client;

  @override
  Future<List<SymbolHit>> search({
    required String asset,
    required String query,
  }) async {
    final q = query.trim();
    if (q.length < minSymbolQuery) return const [];
    final provider = asset == 'mutual_funds' ? 'mf' : 'yahoo';
    try {
      final res = await _client.functions.invoke(
        'live-price',
        body: {
          'search': {'provider': provider, 'q': q},
        },
      );
      return parseSymbolHits(provider, res.data, crypto: asset == 'crypto');
    } on Object {
      return const [];
    }
  }
}

final symbolSearchGatewayProvider = Provider<SymbolSearchGateway>(
  (ref) => SupabaseSymbolSearchGateway(ref.watch(supabaseClientProvider)),
  name: 'symbolSearchGateway',
);
