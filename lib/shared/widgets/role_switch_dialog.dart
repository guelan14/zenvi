import 'package:flutter/material.dart';
import 'package:zenvi/core/theme/zervi_theme.dart';

class RoleSwitchDialog extends StatelessWidget {
  final bool switchingToProfessional;
  final VoidCallback onConfirm;

  const RoleSwitchDialog({
    super.key,
    required this.switchingToProfessional,
    required this.onConfirm,
  });

  static Future<void> show(
    BuildContext context, {
    required bool switchingToProfessional,
    required VoidCallback onConfirm,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return RoleSwitchDialog(
          switchingToProfessional: switchingToProfessional,
          onConfirm: onConfirm,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = switchingToProfessional ? const Color(0xFF3B82F6) : const Color(0xFF10B981);
    final icon = switchingToProfessional ? Icons.construction_rounded : Icons.search_rounded;
    final title = switchingToProfessional ? '¿Cambiar a Modo Profesional?' : '¿Cambiar a Modo Cliente?';
    final description = switchingToProfessional
        ? 'En este modo gestionarás tus servicios ofrecidos, visualizarás tus métricas de rendimiento y administrarás tu agenda de trabajos.'
        : 'En este modo podrás explorar servicios disponibles, buscar en el mapa interactivo y programar turnos con profesionales.';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: isDark ? const Color(0xFF1E222B) : Colors.white,
      elevation: 24,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icono animado/premium superior
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 36),
            ),
            const SizedBox(height: 20),
            // Título
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            // Descripción descriptiva
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white60 : Colors.black54,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            // Botones de acción
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                      ),
                    ),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onConfirm();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Confirmar',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
