import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zenvi/features/profile/domain/providers/profile_providers.dart';
import 'package:zenvi/shared/widgets/role_switch_dialog.dart';

class RoleSwitchButton extends ConsumerWidget {
  const RoleSwitchButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userMode = ref.watch(userModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isClient = userMode == UserMode.client;
    
    // Colores muy suaves y elegantes que se adaptan al fondo
    final Color bgColor = isDark 
        ? Colors.white.withValues(alpha: 0.07) 
        : Colors.black.withValues(alpha: 0.05);
    
    final Color contentColor = isDark 
        ? Colors.white70 
        : Colors.black87;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          RoleSwitchDialog.show(
            context,
            switchingToProfessional: isClient,
            onConfirm: () {
              ref.read(userModeProvider.notifier).toggleMode();
              context.go('/');
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isClient
                        ? 'Cambiado a Modo Profesional'
                        : 'Cambiado a Modo Cliente',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  duration: const Duration(seconds: 1),
                  backgroundColor: isDark ? Colors.white : Colors.black,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          );
        },
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isClient ? 'Cliente' : 'Profesional',
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: contentColor,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.swap_horiz_rounded,
                  size: 16,
                  color: contentColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
