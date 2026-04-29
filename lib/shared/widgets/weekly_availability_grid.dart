import 'package:flutter/material.dart';
import 'package:zenvi/shared/domain/models/availability.dart';

class WeeklyAvailabilityGrid extends StatelessWidget {
  final List<Availability> slots;
  const WeeklyAvailabilityGrid({super.key, required this.slots});

  @override
  Widget build(BuildContext context) {
    final days = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];
    
    final Map<int, List<Availability>> groupedSlots = {};
    for (var slot in slots) {
      if (!groupedSlots.containsKey(slot.dayOfWeek)) {
        groupedSlots[slot.dayOfWeek] = [];
      }
      groupedSlots[slot.dayOfWeek]!.add(slot);
    }

    if (groupedSlots.isEmpty) {
      return const Text('Consultar disponibilidad por chat.', style: TextStyle(color: Colors.black45, fontSize: 14));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: List.generate(7, (index) {
          // Lunes(1) a Domingo(0)
          final actualDay = (index + 1) % 7;
          final daySlots = groupedSlots[actualDay];
          
          if (daySlots == null || daySlots.isEmpty) return const SizedBox.shrink();

          daySlots.sort((a, b) => a.startTime.hour.compareTo(b.startTime.hour));

          final timeStrings = daySlots.map((slot) {
            final start = Availability.formatTime(slot.startTime);
            final end = Availability.formatTime(slot.endTime);
            return '$start a $end';
          }).join(',  ');

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    days[actualDay],
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                  ),
                ),
                Expanded(
                  child: Text(
                    timeStrings,
                    style: const TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
