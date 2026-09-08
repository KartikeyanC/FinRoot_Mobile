import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Session + PKCE storage backed by the platform keystore/keychain rather than
/// SharedPreferences (M1 audit §7, brief §38: "secure token storage").
///
/// The web app keeps its session in `localStorage`, which is XSS-readable; a
/// native client has no such excuse.
// v11 Android defaults are already hardware-backed AES/GCM; `first_unlock` on
// iOS lets a background sync read the session after a reboot.
const _secure = FlutterSecureStorage(
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
);

const _sessionKey = 'finroot.supabase.session';

/// Persists the gotrue session string in secure storage.
class SecureLocalStorage extends LocalStorage {
  const SecureLocalStorage();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async => _secure.containsKey(key: _sessionKey);

  @override
  Future<String?> accessToken() => _secure.read(key: _sessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _secure.write(key: _sessionKey, value: persistSessionString);

  @override
  Future<void> removePersistedSession() => _secure.delete(key: _sessionKey);
}

/// Stores PKCE code verifiers during the OAuth / magic-link exchange.
class SecurePkceStorage extends GotrueAsyncStorage {
  const SecurePkceStorage();

  @override
  Future<String?> getItem({required String key}) =>
      _secure.read(key: 'finroot.pkce.$key');

  @override
  Future<void> setItem({required String key, required String value}) =>
      _secure.write(key: 'finroot.pkce.$key', value: value);

  @override
  Future<void> removeItem({required String key}) =>
      _secure.delete(key: 'finroot.pkce.$key');
}

/// Wipe every FinRoot secret on confirmed sign-out (brief §38, §51).
Future<void> purgeSecureStorage() => _secure.deleteAll();
