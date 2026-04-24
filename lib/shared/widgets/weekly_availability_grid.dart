import 'package:flutter/material.dart';
import 'package:zenvi/shared/domain/models/availability.dart';

class WeeklyAvailabilityGrid extends StatelessWidget {
  final List<Availability> slots;
  const WeeklyAvailabilityGrid({super.key, required this.slots});

  @override
  Widget build(BuildContext context) {
    final days = ['D', 'L', 'M', 'X', 'J', 'V', 'S'];
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (index) {
          final daySlots = slots.where((s) => s.dayOfWeek == index).toList();
          final hasSlots = daySlots.isNotEmpty;
          
          return Column(
            children: [
              Text(
                days[index],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: hasSlots ? Colors.black : Colors.black26,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: hasSlots ? Colors.black : Colors.transparent,
                  shape: BoxShape.circle,
                  border: hasSlots ? null : Border.all(color: Colors.black12),
                ),
                child: hasSlots 
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
              ),
              const SizedBox(height: 8),
              if (hasSlots)
                Text(
                  '${daySlots.length} r.',
                  style: const TextStyle(fontSize: 9, color: Colors.black54),
                )
              else
                const Text('-', style: TextStyle(fontSize: 9, color: Colors.black26)),
            ],
          );
        }),
      ),
    );
  }
}
