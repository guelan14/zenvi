import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zenvi/features/auth/domain/providers/auth_provider.dart';
import 'package:zenvi/shared/widgets/zervi_fab.dart';

/// The persistent shell that holds the bottom nav bar.
/// All tab screens render inside [child].
class MainShell extends ConsumerWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/map')) return 1;
    if (location.startsWith('/messages')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = _selectedIndex(context);
    final isAuthenticated = ref.watch(isAuthenticatedProvider);

    return Scaffold(
      body: child,
      // ─── FAB ─────────────────────────────────────────────────────────────
      floatingActionButton: selectedIndex == 0
          ? ZerviFAB(
              onPublishService: () => context.push('/publish?type=service'),
              onPublishJob: () => context.push('/publish?type=job'),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      // ─── Bottom Nav ───────────────────────────────────────────────────────
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) {
              switch (index) {
                case 0:
                  context.go('/');
                case 1:
                  context.go('/map');
                case 2:
                  context.go('/messages');
                case 3:
                  context.go('/profile/me');
              }
            },
            backgroundColor: Colors.white,
            elevation: 0,
            indicatorColor: Colors.black,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded, color: Colors.white),
                label: 'Inicio',
              ),
              const NavigationDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map_rounded, color: Colors.white),
                label: 'Mapa',
              ),
              NavigationDestination(
                icon: _NavIcon(
                  icon: Icons.chat_bubble_outline_rounded,
                  showBadge: !isAuthenticated,
                ),
                selectedIcon: const Icon(Icons.chat_bubble_rounded, color: Colors.white),
                label: 'Mensajes',
              ),
              NavigationDestination(
                icon: _NavIcon(
                  icon: Icons.person_outline_rounded,
                  showBadge: !isAuthenticated,
                ),
                selectedIcon: const Icon(Icons.person_rounded, color: Colors.white),
                label: 'Perfil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nav icon with an optional small dot badge (shown when auth is required).
class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool showBadge;

  const _NavIcon({required this.icon, required this.showBadge});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (showBadge)
          Positioned(
            top: -2,
            right: -4,
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFFEF4444),
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}
