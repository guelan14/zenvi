import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenvi/core/shell/main_shell.dart';
import 'package:zenvi/features/home/presentation/screens/home_screen.dart';
import 'package:zenvi/features/messages/presentation/screens/messages_screen.dart';
import 'package:zenvi/features/publish/presentation/screens/publish_screen.dart';
import 'package:zenvi/features/profile/presentation/screens/profile_screen.dart';
import 'package:zenvi/features/home/domain/models/listing.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      // ─── Shell with persistent Bottom Nav ─────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
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
      // ─── Full-screen routes (no bottom nav) ───────────────────────────────
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
    ],
  );
});
