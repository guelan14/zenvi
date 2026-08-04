import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zenvi/features/auth/domain/providers/auth_provider.dart';
import 'package:zenvi/features/profile/domain/providers/profile_providers.dart';

class _NavDestinationItem {
  final String route;
  final Widget icon;
  final Widget selectedIcon;
  final String label;

  const _NavDestinationItem({
    required this.route,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

/// The persistent shell that holds the bottom nav bar.
/// All tab screens render inside [child].
class MainShell extends ConsumerWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  List<_NavDestinationItem> _getDestinations(
    UserMode userMode,
    bool isAuthenticated,
    bool isDark,
  ) {
    final selectedColor = isDark ? Colors.black : Colors.white;
    return [
      _NavDestinationItem(
        route: '/',
        icon: const Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded, color: selectedColor),
        label: 'Inicio',
      ),
      // El mapa se muestra en ambos modos
      _NavDestinationItem(
        route: '/map',
        icon: const Icon(Icons.map_outlined),
        selectedIcon: Icon(Icons.map_rounded, color: selectedColor),
        label: 'Mapa',
      ),
      // Las métricas solo se muestran en el modo profesional
      if (userMode == UserMode.professional)
        _NavDestinationItem(
          route: '/metrics',
          icon: const Icon(Icons.bar_chart_outlined),
          selectedIcon: Icon(Icons.bar_chart_rounded, color: selectedColor),
          label: 'Métricas',
        ),
      _NavDestinationItem(
        route: '/agenda',
        icon: const Icon(Icons.calendar_month_outlined),
        selectedIcon: Icon(Icons.calendar_month_rounded, color: selectedColor),
        label: 'Agenda',
      ),
      _NavDestinationItem(
        route: '/messages',
        icon: _NavIcon(
          icon: Icons.chat_bubble_outline_rounded,
          showBadge: !isAuthenticated,
        ),
        selectedIcon: Icon(Icons.chat_bubble_rounded, color: selectedColor),
        label: 'Mensajes',
      ),
      _NavDestinationItem(
        route: '/profile/me',
        icon: _NavIcon(
          icon: Icons.person_outline_rounded,
          showBadge: !isAuthenticated,
        ),
        selectedIcon: Icon(Icons.person_rounded, color: selectedColor),
        label: 'Perfil',
      ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final userMode = ref.watch(userModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final destinations = _getDestinations(userMode, isAuthenticated, isDark);

    final location = GoRouterState.of(context).uri.toString();
    int selectedIndex = 0;
    for (int i = 0; i < destinations.length; i++) {
      final dest = destinations[i];
      if (dest.route == '/' && location == '/') {
        selectedIndex = i;
        break;
      }

      if (dest.route == '/messages' &&
          (location.startsWith('/messages') || location.startsWith('/chat'))) {
        selectedIndex = i;
        break;
      }
      if (dest.route == '/agenda' &&
          (location.startsWith('/agenda') ||
              location.startsWith('/appointment'))) {
        selectedIndex = i;
        break;
      }
      if (dest.route == '/profile/me' &&
          (location.startsWith('/profile') || location.startsWith('/user'))) {
        selectedIndex = i;
        break;
      }
      if (dest.route == '/metrics' && location.startsWith('/metrics')) {
        selectedIndex = i;
        break;
      }
      if (dest.route == '/map' && location.startsWith('/map')) {
        selectedIndex = i;
        break;
      }
    }

    return Scaffold(
      body: child,
      // ─── FAB ─────────────────────────────────────────────────────────────
      floatingActionButton: location == '/'
          ? FloatingActionButton.extended(
              onPressed: () {
                if (userMode == UserMode.client) {
                  context.push('/publish?type=job');
                } else {
                  context.push('/publish?type=service');
                }
              },
              backgroundColor: isDark ? Colors.white : Colors.black,
              foregroundColor: isDark ? Colors.black : Colors.white,
              icon: const Icon(Icons.add, size: 20),
              label: Text(
                userMode == UserMode.client
                    ? 'Publicar Pedido'
                    : 'Ofrecer Servicio',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.2,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      // ─── Bottom Nav ───────────────────────────────────────────────────────
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF1E222B) : const Color(0xFFEEEEEE),
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) {
              context.go(destinations[index].route);
            },
            backgroundColor: Theme.of(context).cardColor,
            elevation: 0,
            indicatorColor: isDark ? Colors.white : Colors.black,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: destinations.map((d) {
              return NavigationDestination(
                icon: d.icon,
                selectedIcon: d.selectedIcon,
                label: d.label,
              );
            }).toList(),
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
