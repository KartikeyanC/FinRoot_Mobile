import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/error_mapper.dart';
import '../../core/providers/providers.dart';

/// The signed-in user's `profiles` row (web `profiles` table — display_name,
/// username, mobile, onboarding flags). M3 reads it and edits display_name;
/// the rest is surfaced in later phases.
class Profile {
  const Profile({required this.id, this.displayName, this.username});

  final String id;
  final String? displayName;
  final String? username;

  factory Profile.fromRow(Map<String, dynamic> row) => Profile(
    id: row['id'] as String,
    displayName: row['display_name'] as String?,
    username: row['username'] as String?,
  );
}

final profileProvider = FutureProvider<Profile?>((ref) async {
  if (!ref.watch(isSignedInProvider)) return null;
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return null;
  try {
    final row = await client
        .from('profiles')
        .select('id, display_name, username')
        .eq('id', userId)
        .maybeSingle();
    return row == null ? null : Profile.fromRow(row);
  } catch (error, stack) {
    throw mapError(error, stack);
  }
}, name: 'profile');

final profileControllerProvider = Provider<ProfileController>(
  (ref) => ProfileController(ref),
  name: 'profileController',
);

class ProfileController {
  ProfileController(this._ref);
  final Ref _ref;

  Future<void> updateDisplayName(String name) async {
    final client = _ref.read(supabaseClientProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await client
          .from('profiles')
          .update({'display_name': name.trim()})
          .eq('id', userId);
      _ref.invalidate(profileProvider);
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }
}
