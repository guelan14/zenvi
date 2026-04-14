import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zenvi/shared/widgets/zervi_fab.dart';

/// The persistent shell that holds the bottom nav bar.
/// All tab screens render inside [child].
class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/messages')) return 1;
    if (location.startsWith('/profile')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndex(context);

    return Scaffold(
      body: child,
      // ─── FAB ────────────────────────────────────────────────────────────────
      floatingActionButton: selectedIndex == 0
          ? ZerviFAB(
              onPublishService: () => context.push('/publish?type=service'),
              onPublishJob: () => context.push('/publish?type=job'),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      // ─── Bottom Nav ─────────────────────────────────────────────────────────
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
                  context.go('/messages');
                case 2:
                  context.go('/profile/me');
              }
            },
            backgroundColor: Colors.white,
            elevation: 0,
            indicatorColor: Colors.black,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded, color: Colors.white),
                label: 'Inicio',
              ),
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline_rounded),
                selectedIcon: Icon(Icons.chat_bubble_rounded, color: Colors.white),
                label: 'Mensajes',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded, color: Colors.white),
                label: 'Perfil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
