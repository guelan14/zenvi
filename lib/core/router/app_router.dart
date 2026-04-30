import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenvi/core/shell/main_shell.dart';
import 'package:zenvi/features/auth/domain/providers/auth_provider.dart';
import 'package:zenvi/features/auth/presentation/screens/auth_screen.dart';
import 'package:zenvi/features/home/presentation/screens/home_screen.dart';
import 'package:zenvi/features/home/presentation/screens/listing_detail_screen.dart';
import 'package:zenvi/features/home/presentation/screens/map_screen.dart';
import 'package:zenvi/features/messages/presentation/screens/messages_screen.dart';
import 'package:zenvi/features/publish/presentation/screens/publish_screen.dart';
import 'package:zenvi/features/profile/presentation/screens/profile_screen.dart';
import 'package:zenvi/features/appointments/presentation/screens/appointments_screen.dart';
import 'package:zenvi/features/messages/presentation/screens/chat_screen.dart';
import 'package:zenvi/features/home/domain/providers/home_providers.dart';
import 'package:zenvi/features/home/domain/models/listing.dart';

/// Routes that require authentication. Unauthenticated access redirects to /auth.
const _protectedRoutes = {'/messages', '/profile/me', '/agenda', '/chat'};

// ─── Notifier (bridges Riverpod → GoRouter refreshListenable) ─────────────────

class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(Ref ref) {
    ref.listen<bool>(
      isAuthenticatedProvider,
      (prev, next) => notifyListeners(),
    );
  }
}

// ─── Router Provider ──────────────────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthNotifier(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      final isAuthenticated = ref.read(isAuthenticatedProvider);
      final location = state.matchedLocation;

      // Not authenticated + protected route → send to /auth
      if (!isAuthenticated && _protectedRoutes.any((route) => location.startsWith(route))) {
        return '/auth?redirect=${Uri.encodeComponent(location)}';
      }

      // Already authenticated + going to /auth → send to destination
      if (isAuthenticated && location == '/auth') {
        final redirectTo = state.uri.queryParameters['redirect'];
        return redirectTo != null
            ? Uri.decodeComponent(redirectTo)
            : '/profile/me';
      }

      return null;
    },
    routes: [
      // ─── Shell with persistent Bottom Nav ─────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          GoRoute(path: '/map', builder: (context, state) => const MapScreen()),
          GoRoute(
            path: '/agenda',
            builder: (context, state) => const AppointmentsScreen(),
          ),
          GoRoute(
            path: '/messages',
            builder: (context, state) => const MessagesScreen(),
          ),
          GoRoute(
            path: '/profile/me',
            builder: (context, state) => const ProfileScreen(profileId: 'me'),
          ),
        ],
      ),

      // ─── Auth (full-screen, no bottom nav) ──────────────────────────────
      GoRoute(
        path: '/auth',
        builder: (context, state) {
          final redirect = state.uri.queryParameters['redirect'];
          return AuthScreen(
            redirectTo: redirect != null ? Uri.decodeComponent(redirect) : null,
          );
        },
      ),

      // ─── Other full-screen routes ────────────────────────────────────────
      GoRoute(
        path: '/publish',
        builder: (context, state) {
          final type = state.uri.queryParameters['type'] == 'job'
              ? ListingType.job
              : ListingType.service;
          return PublishScreen(initialType: type);
        },
      ),
      GoRoute(
        path: '/profile/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ProfileScreen(profileId: id);
        },
      ),
      GoRoute(
        path: '/listing/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ListingDetailScreen(listingId: id);
        },
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) {
          final listingId = state.pathParameters['id']!;
          final listings = ref.read(listingsProvider(null)).value ?? [];
          final listing = listings.firstWhere(
            (l) => l.id == listingId,
            orElse: () => Listing(
              id: listingId,
              authorId: '',
              title: 'Cargando...',
              description: '',
              type: ListingType.service,
              createdAt: DateTime.now(),
            ),
          );
          return ChatScreen(listing: listing);
        },
      ),
      GoRoute(
        path: '/chat_user/:id',
        builder: (context, state) {
          final userId = state.pathParameters['id']!;
          return ChatScreen(otherUserId: userId);
        },
      ),
    ],
  );
});
