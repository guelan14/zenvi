import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zenvi/shared/domain/models/availability.dart';

class WeeklyAvailabilityGrid extends StatefulWidget {
  final List<Availability> slots;
  const WeeklyAvailabilityGrid({super.key, required this.slots});

  @override
  State<WeeklyAvailabilityGrid> createState() => _WeeklyAvailabilityGridState();
}

class _WeeklyAvailabilityGridState extends State<WeeklyAvailabilityGrid> {
  int _selectedDay = 1; // Default to Monday (1)
  
  @override
  void initState() {
    super.initState();
    // Default to today's weekday (1-7), or first day that has slots
    final today = DateTime.now().weekday;
    final dayOfWeek = today % 7; // Sunday=0, Monday=1...
    
    final hasSlotsToday = widget.slots.any((s) => s.dayOfWeek == dayOfWeek);
    if (hasSlotsToday) {
      _selectedDay = dayOfWeek;
    } else if (widget.slots.isNotEmpty) {
      _selectedDay = widget.slots.first.dayOfWeek;
    } else {
      _selectedDay = dayOfWeek;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dayNames = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
    final dayFullNames = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];

    // Group slots by day
    final Map<int, List<Availability>> groupedSlots = {};
    for (var slot in widget.slots) {
      if (!groupedSlots.containsKey(slot.dayOfWeek)) {
        groupedSlots[slot.dayOfWeek] = [];
      }
      groupedSlots[slot.dayOfWeek]!.add(slot);
    }

    if (groupedSlots.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E222B) : const Color(0xFFF9F9F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Icon(Icons.chat_bubble_outline_rounded, color: isDark ? Colors.white54 : Colors.black45, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Sin horarios fijos. Consultar disponibilidad por chat.',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Days list re-ordered from Monday (1) to Sunday (0)
    final orderedDays = [1, 2, 3, 4, 5, 6, 0];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 20,
                  color: isDark ? Colors.blue[300] : Colors.blue[600],
                ),
                const SizedBox(width: 8),
                Text(
                  'Horarios de Atención',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          
          // Horizontal Days selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: orderedDays.map((dayNum) {
                final hasSlots = groupedSlots.containsKey(dayNum) && groupedSlots[dayNum]!.isNotEmpty;
                final isSelected = _selectedDay == dayNum;

                Color bg = Colors.transparent;
                Color border = Colors.transparent;
                Color text = isDark ? Colors.white30 : Colors.black38;

                if (hasSlots) {
                  if (isSelected) {
                    bg = isDark ? Colors.white : Colors.black;
                    text = isDark ? Colors.black : Colors.white;
                  } else {
                    bg = isDark ? const Color(0xFF252A36) : const Color(0xFFF1F1F1);
                    border = isDark ? Colors.white10 : Colors.black.withOpacity(0.05);
                    text = isDark ? Colors.white : Colors.black87;
                  }
                }

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedDay = dayNum;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(12),
                          border: border != Colors.transparent ? Border.all(color: border) : null,
                        ),
                        child: Text(
                          dayNames[dayNum],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: hasSlots ? FontWeight.bold : FontWeight.normal,
                            color: text,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Info of selected day
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14171E) : const Color(0xFFF9F9F9),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Builder(
              builder: (context) {
                final daySlots = groupedSlots[_selectedDay];
                if (daySlots == null || daySlots.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'El profesional no atiende los ${dayFullNames[_selectedDay]}s.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white30 : Colors.black45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }

                daySlots.sort((a, b) => a.startTime.hour.compareTo(b.startTime.hour));

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dayFullNames[_selectedDay],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...daySlots.map((slot) {
                      final startStr = Availability.formatTime(slot.startTime);
                      final endStr = Availability.formatTime(slot.endTime);

                      // Calculate percentages for the timeline bar
                      final startMin = slot.startTime.hour * 60 + slot.startTime.minute;
                      final endMin = slot.endTime.hour * 60 + slot.endTime.minute;
                      final totalMin = 24 * 60;

                      final startPct = startMin / totalMin;
                      final widthPct = (endMin - startMin) / totalMin;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.access_time_rounded, size: 14, color: isDark ? Colors.white30 : Colors.black45),
                                    const SizedBox(width: 6),
                                    Text(
                                      '$startStr a $endStr hs',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Jornada laboral',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white30 : Colors.black38,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Visual Timeline Bar
                            Container(
                              width: double.infinity,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Stack(
                                children: [
                                  FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: startPct + widthPct,
                                    child: Container(
                                      alignment: Alignment.centerRight,
                                      child: FractionallySizedBox(
                                        widthFactor: widthPct / (startPct + widthPct),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.blue[400] : Colors.blue[600],
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Hour markers under timeline
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('00:00', style: TextStyle(fontSize: 9, color: isDark ? Colors.white24 : Colors.black26)),
                                Text('06:00', style: TextStyle(fontSize: 9, color: isDark ? Colors.white24 : Colors.black26)),
                                Text('12:00', style: TextStyle(fontSize: 9, color: isDark ? Colors.white24 : Colors.black26)),
                                Text('18:00', style: TextStyle(fontSize: 9, color: isDark ? Colors.white24 : Colors.black26)),
                                Text('24:00', style: TextStyle(fontSize: 9, color: isDark ? Colors.white24 : Colors.black26)),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
