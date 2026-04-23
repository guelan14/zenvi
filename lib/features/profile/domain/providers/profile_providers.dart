import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenvi/core/supabase/supabase_config.dart';
import 'package:zenvi/features/auth/domain/providers/auth_provider.dart';
import 'package:zenvi/features/profile/data/profile_repository.dart';
import 'package:zenvi/shared/domain/models/profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});

final profileProvider = FutureProvider.family<Profile?, String>((ref, id) async {
  if (id == 'me') {
    final user = ref.watch(currentUserProvider);
    if (user == null) return null;
    return ref.watch(profileRepositoryProvider).getProfile(user.id);
  }
  return ref.watch(profileRepositoryProvider).getProfile(id);
});
