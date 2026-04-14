import 'package:flutter/material.dart';

class AppointmentButton extends StatelessWidget {
  final VoidCallback onPressed;

  const AppointmentButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.calendar_today_outlined, size: 18),
      label: const Text('Asignar Cita'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        elevation: 4,
        shadowColor: Colors.blue.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
