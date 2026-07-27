import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:go_router/go_router.dart';
import 'package:zenvi/features/appointments/domain/models/appointment.dart';
import 'package:zenvi/features/appointments/domain/providers/appointment_providers.dart';
import 'package:zenvi/features/auth/domain/providers/auth_provider.dart';
import 'package:zenvi/features/profile/domain/providers/profile_providers.dart';
import 'package:zenvi/shared/widgets/zervi_skeleton.dart';
import 'package:zenvi/shared/widgets/role_switch_button.dart';
import 'package:intl/intl.dart';

class AppointmentsScreen extends ConsumerStatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  List<Appointment> _getEventsForDay(List<Appointment> allAppointments, DateTime day) {
    return allAppointments.where((app) {
      return isSameDay(app.scheduledAt, day);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final appointmentsAsync = ref.watch(userAppointmentsProvider);
    final userId = ref.watch(currentUserProvider)?.id;
    final userMode = ref.watch(userModeProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Agenda',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: RoleSwitchButton(),
          ),
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime.now();
                _selectedDay = _focusedDay;
              });
            },
          ),
        ],
      ),
      body: appointmentsAsync.when(
        loading: () => const ZerviAgendaSkeleton(),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (allAppointments) {
          final appointments = allAppointments.where((app) {
            if (userMode == UserMode.client) {
              return app.customerId == userId;
            } else {
              return app.professionalId == userId;
            }
          }).toList();

          final eventsForSelectedDay = _getEventsForDay(appointments, _selectedDay!);

          return Column(
            children: [
              TableCalendar<Appointment>(
                firstDay: DateTime.now().subtract(const Duration(days: 365)),
                lastDay: DateTime.now().add(const Duration(days: 365)),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                eventLoader: (day) => _getEventsForDay(appointments, day),
                startingDayOfWeek: StartingDayOfWeek.monday,
                 calendarStyle: CalendarStyle(
                  selectedDecoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  todayDecoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.black26,
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                  ),
                  markerDecoration: const BoxDecoration(
                    color: Colors.grey,
                    shape: BoxShape.circle,
                  ),
                  outsideDaysVisible: false,
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, events) {
                    if (events.isEmpty) return const SizedBox();
                    
                    final color = userMode == UserMode.client ? Colors.green[600] : Colors.blue[600];
                    
                    return Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 10,
                      color: userMode == UserMode.client ? Colors.green : Colors.blue,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      userMode == UserMode.client
                          ? 'Mis Turnos Solicitados'
                          : 'Mis Trabajos Agendados',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1, color: Colors.black12),
              Expanded(
                child: eventsForSelectedDay.isEmpty
                    ? const Center(
                        child: Text(
                          'No hay turnos para este día.',
                          style: TextStyle(color: Colors.black54, fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: eventsForSelectedDay.length,
                        itemBuilder: (context, index) {
                          final event = eventsForSelectedDay[index];
                          final isMyWork = userMode == UserMode.professional;
                          
                          return _buildEventCard(event, isMyWork);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEventCard(Appointment event, bool isMyWork) {
    final startTimeStr = DateFormat('HH:mm').format(event.scheduledAt);
    
    final color = isMyWork ? Colors.blue : Colors.green;
    final title = isMyWork ? 'Trabajo Programado' : 'Turno Reservado';
    final icon = isMyWork ? Icons.work_outline : Icons.person_outline;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            context.push('/appointment/${event.id}');
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color[700]),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: color[900],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 14, color: Colors.black54),
                          const SizedBox(width: 4),
                          Text(
                            startTimeStr,
                            style: const TextStyle(color: Colors.black87),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.info_outline, size: 14, color: Colors.black54),
                          const SizedBox(width: 4),
                          Text(
                            'Estado: ${_getStatusText(event.status)}',
                            style: TextStyle(
                              color: _getStatusColor(event.status),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.black26),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getStatusText(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.pending:
        return 'Pendiente';
      case AppointmentStatus.accepted:
        return 'Aceptado';
      case AppointmentStatus.rejected:
        return 'Rechazado';
      case AppointmentStatus.completed:
        return 'Completado';
      case AppointmentStatus.cancelled:
        return 'Cancelado';
    }
  }

  Color _getStatusColor(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.pending:
        return Colors.orange;
      case AppointmentStatus.accepted:
        return Colors.green;
      case AppointmentStatus.rejected:
      case AppointmentStatus.cancelled:
        return Colors.red;
      case AppointmentStatus.completed:
        return Colors.blue;
    }
  }
}
