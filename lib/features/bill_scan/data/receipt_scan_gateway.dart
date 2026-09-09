import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/error_mapper.dart';
import '../../../core/error/failure.dart';
import '../../../core/providers/providers.dart';
import '../domain/captured_image.dart';
import '../domain/scan_result.dart';

/// Calls the shared `scan-receipt` Edge Function (Gemini vision, `verify_jwt`,
/// workspace membership check + 30/day rate limit — all server-side). No
/// backend change for M13; the mobile client just invokes what the web uses
/// (`src/pages/BillScan.tsx`).
abstract interface class ReceiptScanGateway {
  Future<ScanResult> scan(String tenantId, List<CapturedImage> images);
}

class SupabaseReceiptScanGateway implements ReceiptScanGateway {
  SupabaseReceiptScanGateway(this._client);
  final SupabaseClient _client;

  @override
  Future<ScanResult> scan(String tenantId, List<CapturedImage> images) async {
    try {
      final res = await _client.functions.invoke(
        'scan-receipt',
        body: {
          'tenant_id': tenantId,
          'images': [
            for (final img in images)
              {'data': img.toBase64(), 'mimeType': img.mimeType},
          ],
        },
      );
      final data = res.data;
      if (data is! Map) {
        throw const ValidationFailure(
          'That scan came back empty — try a clearer, straight-on photo.',
        );
      }
      return ScanResult.fromJson(Map<String, dynamic>.from(data));
    } on FunctionException catch (e, stack) {
      throw _mapFunctionError(e, stack);
    } catch (error, stack) {
      if (error is Failure) rethrow;
      throw mapError(error, stack);
    }
  }

  Failure _mapFunctionError(FunctionException e, StackTrace stack) {
    if (e is FunctionsFetchException) return NetworkFailure(cause: e);
    final detail = e.details;
    final message = detail is Map && detail['error'] is String
        ? detail['error'] as String
        : null;
    return switch (e.status) {
      401 => AuthFailure.sessionExpired(),
      403 => const PermissionFailure(
        message: 'Bill scan isn\'t available in this workspace.',
      ),
      429 => ValidationFailure(
        message ?? 'Daily scan limit reached. Try again tomorrow.',
        cause: e,
      ),
      422 => ValidationFailure(
        message ?? 'Could not read that receipt — try a clearer photo.',
        cause: e,
      ),
      400 => ValidationFailure(message ?? 'That receipt could not be sent.',
          cause: e),
      _ => UnexpectedFailure(cause: e),
    };
  }
}

final receiptScanGatewayProvider = Provider<ReceiptScanGateway>(
  (ref) => SupabaseReceiptScanGateway(ref.watch(supabaseClientProvider)),
  name: 'receiptScanGateway',
);
