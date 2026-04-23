import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zenvi/core/supabase/supabase_config.dart';
import 'package:zenvi/features/auth/data/auth_repository.dart';

// ─── Repository ──────────────────────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

// ─── Auth State Stream ────────────────────────────────────────────────────────
// Listens to Supabase auth changes (login, logout, token refresh, etc.)

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

// ─── Current User ─────────────────────────────────────────────────────────────

final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (state) => state.session?.user,
    loading: () => Supabase.instance.client.auth.currentUser, // use cached value while loading
    error: (err, _) => null,
  );
});

// ─── isAuthenticated ──────────────────────────────────────────────────────────

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});
