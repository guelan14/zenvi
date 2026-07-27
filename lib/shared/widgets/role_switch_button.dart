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
    
    // Configuración de colores basada en el brillo de la pantalla y el modo actual
    final Color bgColor = isClient 
        ? (isDark ? Colors.white : Colors.black) 
        : (isDark ? const Color(0xFF1E222B) : Colors.white);
    
    final Color textColor = isClient 
        ? (isDark ? Colors.black : Colors.white) 
        : (isDark ? Colors.white70 : Colors.black87);
        
    final Color borderColor = isClient 
        ? (isDark ? Colors.white : Colors.black) 
        : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08));

    final Color arrowColor = isClient 
        ? (isDark ? Colors.black54 : Colors.white70) 
        : (isDark ? Colors.white54 : Colors.black54);

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
                        ? 'Cambiado a Modo Profesional 🛠️'
                        : 'Cambiado a Modo Cliente 🔍',
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderColor,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isClient ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (isClient ? const Color(0xFF10B981) : const Color(0xFF3B82F6)).withValues(alpha: 0.4),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isClient ? 'MODO CLIENTE' : 'MODO PRO',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: textColor,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 14,
                color: arrowColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
