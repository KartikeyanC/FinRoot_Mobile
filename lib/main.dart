import 'bootstrap.dart';

/// Default entrypoint.
///
/// Run with the local config:
///   flutter run --dart-define-from-file=config/dev.json
///
/// A `service_role` key must never be passed here — the anon/publishable key
/// only, protected by RLS (M1 audit §9).
Future<void> main() => bootstrap();
