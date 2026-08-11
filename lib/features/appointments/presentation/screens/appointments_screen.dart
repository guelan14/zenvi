import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:zenvi/features/appointments/domain/models/appointment.dart';
import 'package:zenvi/features/appointments/domain/providers/appointment_providers.dart';
import 'package:zenvi/features/auth/domain/providers/auth_provider.dart';
import 'package:zenvi/features/profile/domain/providers/profile_providers.dart';
import 'package:zenvi/features/messages/domain/providers/chat_providers.dart';
import 'package:zenvi/features/home/domain/models/listing.dart';
import 'package:zenvi/shared/widgets/zervi_skeleton.dart';
import 'package:zenvi/features/profile/presentation/screens/my_customers_screen.dart';

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

  List<Appointment> _getEventsForDay(
    List<Appointment> allAppointments,
    DateTime day,
  ) {
    return allAppointments.where((app) {
      return isSameDay(app.scheduledAt, day);
    }).toList();
  }

  void _showCreateAppointmentBottomSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _CreateAppointmentBottomSheet(
          initialDate: _selectedDay ?? DateTime.now(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appointmentsAsync = ref.watch(userAppointmentsProvider);
    final userId = ref.watch(currentUserProvider)?.id;
    final userMode = ref.watch(userModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Agenda',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
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

          final eventsForSelectedDay = _getEventsForDay(
            appointments,
            _selectedDay!,
          );

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
                    color: isDark ? Colors.white : Colors.black,
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle: TextStyle(
                    color: isDark ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  todayDecoration: BoxDecoration(
                    color: isDark ? Colors.white38 : Colors.black26,
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
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
                  titleTextStyle: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
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

                    final color = userMode == UserMode.client
                        ? Colors.green[600]
                        : Colors.blue[600];

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
                padding: const EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 16.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 10,
                      color: userMode == UserMode.client
                          ? Colors.green
                          : Colors.blue,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      userMode == UserMode.client
                          ? 'Mis Turnos Solicitados'
                          : 'Mis Trabajos Agendados',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1, color: Colors.black12),
              Expanded(
                child: eventsForSelectedDay.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white10
                                    : Colors.black.withOpacity(0.04),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.calendar_today_outlined,
                                size: 40,
                                color: isDark ? Colors.white30 : Colors.black38,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No hay turnos para este día.',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () =>
                                  _showCreateAppointmentBottomSheet(context),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Agendar Turno'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark
                                    ? Colors.white
                                    : Colors.black,
                                foregroundColor: isDark
                                    ? Colors.black
                                    : Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateAppointmentBottomSheet(context),
        backgroundColor: isDark ? Colors.white : Colors.black,
        foregroundColor: isDark ? Colors.black : Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 24),
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
        border: Border.all(color: color.withOpacity(0.2)),
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
                          const Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.black54,
                          ),
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
                          const Icon(
                            Icons.info_outline,
                            size: 14,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Estado: ${_getStatusText(event.status)}',
                            style: TextStyle(
                              color: _getStatusColor(event.status),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (event.status == AppointmentStatus.accepted ||
                              event.status == AppointmentStatus.completed) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'PAGADO',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.black26),
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
      case AppointmentStatus.proposed:
        return 'Propuesto';
    }
  }

  Color _getStatusColor(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.pending:
      case AppointmentStatus.proposed:
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

class _CreateAppointmentBottomSheet extends ConsumerStatefulWidget {
  final DateTime initialDate;
  const _CreateAppointmentBottomSheet({required this.initialDate});

  @override
  ConsumerState<_CreateAppointmentBottomSheet> createState() =>
      _CreateAppointmentBottomSheetState();
}

class _CreateAppointmentBottomSheetState
    extends ConsumerState<_CreateAppointmentBottomSheet> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? selectedContactId;
  String? selectedListingId;
  final notesController = TextEditingController();
  final priceController = TextEditingController();

  bool isLoadingContacts = false;
  List<Map<String, String>> resolvedContacts = [];

  bool isLoadingListings = false;
  List<Listing> localListings = [];
  Map<String, String> professionalNamesMap = {};

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final userMode = ref.watch(userModeProvider);
    final conversations =
        ref.watch(userConversationsStreamProvider).value ?? [];

    if (currentUserId == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E222B) : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: const Center(child: Text('Iniciá sesión para agendar turnos')),
      );
    }

    final List<Map<String, dynamic>> itemsList = [];

    if (userMode == UserMode.professional) {
      final customers = ref.watch(myCustomersProvider).value ?? [];
      for (var c in customers) {
        itemsList.add({
          'value': '${c.customClient?.clientProfileId ?? c.profile?.id ?? ''}|${c.customClient?.id ?? ''}',
          'name': c.displayName,
          'is_registered': c.profile != null || c.customClient?.clientProfileId != null,
        });
      }
      if (selectedContactId == null && itemsList.isNotEmpty) {
        selectedContactId = itemsList.first['value'];
      }
    } else {
      if (resolvedContacts.isEmpty &&
          !isLoadingContacts &&
          conversations.isNotEmpty) {
        isLoadingContacts = true;
        Future.microtask(() async {
          final list = <Map<String, String>>[];
          final profIds = <String>[];
          final namesMap = <String, String>{};
          for (var conv in conversations) {
            final oId = conv.initiatorId == currentUserId
                ? conv.recipientId
                : conv.initiatorId;
            try {
              final p = await ref.read(profileProvider(oId).future);
              if (p != null) {
                list.add({'id': oId, 'name': p.fullName ?? 'Usuario'});
                profIds.add(oId);
                namesMap[oId] = p.fullName ?? 'Usuario';
              }
            } catch (_) {
              list.add({'id': oId, 'name': 'Usuario ($oId)'});
              profIds.add(oId);
              namesMap[oId] = 'Usuario ($oId)';
            }
          }

          // Obtener publicaciones de todos los profesionales activos en chat
          List<Listing> listings = [];
          if (profIds.isNotEmpty) {
            try {
              final response = await ref.read(supabaseClientProvider)
                  .from('listings')
                  .select()
                  .inFilter('user_id', profIds);
              listings = (response as List).map((json) => Listing.fromJson(json)).toList();
            } catch (_) {}
          }

          if (mounted) {
            setState(() {
              resolvedContacts = list;
              professionalNamesMap = namesMap;
              localListings = listings;
              isLoadingContacts = false;
              if (localListings.isNotEmpty) {
                selectedListingId = localListings.first.id;
                selectedContactId = localListings.first.userId;
                if (localListings.first.price != null) {
                  priceController.text = localListings.first.price!
                      .toStringAsFixed(0);
                }
              }
            });
          }
        });
      }
    }

    if (userMode == UserMode.professional &&
        !isLoadingListings &&
        localListings.isEmpty) {
      isLoadingListings = true;
      Future.microtask(() async {
        try {
          final res = await ref.read(
            profileListingsProvider(currentUserId).future,
          );
          if (mounted) {
            setState(() {
              localListings = res;
              isLoadingListings = false;
              if (localListings.isNotEmpty) {
                selectedListingId = localListings.first.id;
                if (localListings.first.price != null) {
                  priceController.text = localListings.first.price!
                      .toStringAsFixed(0);
                }
              }
            });
          }
        } catch (_) {
          if (mounted) {
            setState(() => isLoadingListings = false);
          }
        }
      });
    }

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222B) : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            userMode == UserMode.professional
                ? 'Proponer Turno'
                : 'Solicitar Turno',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            userMode == UserMode.professional
                ? 'Agendá un turno con uno de tus clientes de chat.'
                : 'Solicitá un turno a uno de tus profesionales de chat.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 24),
          // Selección de Contacto y Publicación en orden según UserMode
          if (userMode == UserMode.professional) ...[
            // 1. Seleccionar Cliente
            Text(
              'Seleccionar Cliente',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            if (itemsList.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  'No tenés clientes registrados aún.',
                  style: TextStyle(
                    color: isDark ? Colors.white30 : Colors.black38,
                    fontSize: 13,
                  ),
                ),
              )
            else
              DropdownButtonFormField<String>(
                value: selectedContactId,
                dropdownColor: isDark ? const Color(0xFF1E222B) : Colors.white,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF14171E)
                      : const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                items: itemsList.map((c) {
                  return DropdownMenuItem<String>(
                    value: c['value'],
                    child: Text(c['name']),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    selectedContactId = val;
                    localListings = [];
                    selectedListingId = null;
                  });
                },
              ),
            const SizedBox(height: 20),

            // 2. Seleccionar Publicación / Servicio
            if (selectedContactId != null) ...[
              Text(
                'Servicio / Publicación',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              if (isLoadingListings)
                const Center(child: CircularProgressIndicator())
              else if (localListings.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    'No tenés publicaciones activas.',
                    style: TextStyle(
                      color: isDark ? Colors.white30 : Colors.black38,
                      fontSize: 13,
                    ),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: selectedListingId,
                  dropdownColor: isDark ? const Color(0xFF1E222B) : Colors.white,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF14171E)
                        : const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  items: localListings.map((l) {
                    return DropdownMenuItem<String>(
                      value: l.id,
                      child: Text(l.title, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      selectedListingId = val;
                      final selectedList = localListings.firstWhere(
                        (l) => l.id == val,
                      );
                      if (selectedList.price != null) {
                        priceController.text = selectedList.price!
                            .toStringAsFixed(0);
                      }
                    });
                  },
                ),
              const SizedBox(height: 20),
            ],
          ] else ...[
            // CLIENT MODE:
            // 1. Seleccionar Servicio primero
            Text(
              'Servicio / Publicación',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            if (isLoadingContacts)
              const Center(child: CircularProgressIndicator())
            else if (localListings.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  'No hay servicios disponibles de tus profesionales de chat.',
                  style: TextStyle(
                    color: isDark ? Colors.white30 : Colors.black38,
                    fontSize: 13,
                  ),
                ),
              )
            else
              DropdownButtonFormField<String>(
                value: selectedListingId,
                dropdownColor: isDark ? const Color(0xFF1E222B) : Colors.white,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF14171E)
                      : const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                items: localListings.map((l) {
                  final profName = professionalNamesMap[l.userId] ?? 'Profesional';
                  return DropdownMenuItem<String>(
                    value: l.id,
                    child: Text('${l.title} ($profName)', overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    selectedListingId = val;
                    final selectedList = localListings.firstWhere(
                      (l) => l.id == val,
                    );
                    selectedContactId = selectedList.userId;
                    if (selectedList.price != null) {
                      priceController.text = selectedList.price!
                          .toStringAsFixed(0);
                    }
                  });
                },
              ),
            const SizedBox(height: 20),

            // 2. Mostrar Profesional asociado
            if (selectedContactId != null) ...[
              Text(
                'Profesional',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF14171E) : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      color: isDark ? Colors.white54 : Colors.black54,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        professionalNamesMap[selectedContactId] ?? 'Profesional',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ],

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final date = await _showCustomDatePicker(
                      context: context,
                      initialDate: _selectedDate ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setState(() => _selectedDate = date);
                    }
                  },
                  icon: Icon(
                    Icons.calendar_today_rounded,
                    size: 18,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                  label: Text(
                    _selectedDate == null
                        ? 'Fecha'
                        : DateFormat('dd/MM/yyyy').format(_selectedDate!),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final time = await _showCustomTimePicker(
                      context: context,
                      initialTime: _selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
                    );
                    if (time != null) {
                      setState(() => _selectedTime = time);
                    }
                  },
                  icon: Icon(
                    Icons.access_time_rounded,
                    size: 18,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                  label: Text(
                    _selectedTime == null
                        ? 'Hora'
                        : _selectedTime!.format(context),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Precio
          if (userMode == UserMode.professional) ...[
            Text(
              'Monto / Presupuesto (\$)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Ej: 15000',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white30 : Colors.black38,
                ),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF14171E)
                    : const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
          ] else ...[
            // Para el cliente, mostramos el precio del servicio de forma informativa
            if (selectedListingId != null) ...[
              Text(
                'Precio del Servicio',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF14171E) : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.sell_outlined,
                      color: isDark ? Colors.white54 : Colors.black54,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      priceController.text.isNotEmpty && priceController.text != '0'
                          ? '\$${priceController.text}'
                          : 'A coordinar',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ],

          // Notas
          Text(
            'Notas o indicaciones especiales',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: notesController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Detallá indicaciones o aclaraciones para la cita...',
              hintStyle: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white30 : Colors.black38,
              ),
              filled: true,
              fillColor: isDark
                  ? const Color(0xFF14171E)
                  : const Color(0xFFF5F5F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 28),

          // Botón Confirmar
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed:
                  (_selectedDate == null ||
                      _selectedTime == null ||
                      selectedListingId == null ||
                      selectedContactId == null ||
                      _isSaving)
                  ? null
                  : () async {
                      setState(() => _isSaving = true);

                      final start = DateTime(
                        _selectedDate!.year,
                        _selectedDate!.month,
                        _selectedDate!.day,
                        _selectedTime!.hour,
                        _selectedTime!.minute,
                      );

                      final finalPrice =
                          double.tryParse(priceController.text.trim()) ?? 0.0;

                      String? selectedProfileId;
                      String? selectedCustomClientId;

                      if (userMode == UserMode.professional && selectedContactId != null) {
                        final parts = selectedContactId!.split('|');
                        selectedProfileId = parts[0].isNotEmpty ? parts[0] : null;
                        selectedCustomClientId = parts[1].isNotEmpty ? parts[1] : null;
                      } else {
                        selectedProfileId = selectedContactId;
                      }

                      final appointment = Appointment(
                        id: const Uuid().v4(),
                        listingId: selectedListingId!,
                        customerId: userMode == UserMode.professional
                            ? selectedProfileId
                            : currentUserId,
                        customClientId: userMode == UserMode.professional
                            ? selectedCustomClientId
                            : null,
                        professionalId: userMode == UserMode.professional
                            ? currentUserId
                            : selectedProfileId!,
                        scheduledAt: start,
                        price: finalPrice > 0 ? finalPrice : null,
                        status: userMode == UserMode.professional
                            ? AppointmentStatus.proposed
                            : AppointmentStatus.pending,
                        notes: notesController.text.trim().isNotEmpty
                            ? notesController.text.trim()
                            : null,
                        createdAt: DateTime.now(),
                      );

                      try {
                        await ref
                            .read(appointmentRepositoryProvider)
                            .createAppointment(appointment);

                        // Enviar mensaje al chat si el cliente tiene un perfil de chat registrado
                        final dateStr = DateFormat('dd/MM/yyyy').format(start);
                        final timeStr = DateFormat('HH:mm').format(start);
                        final priceStr = finalPrice > 0
                            ? ' por \$${finalPrice.toStringAsFixed(0)}'
                            : '';

                        final messageContent = userMode == UserMode.professional
                            ? '📅 Propuso un turno para el día $dateStr a las $timeStr hs$priceStr. (ID: ${appointment.id})'
                            : '📅 Solicitó un turno para el día $dateStr a las $timeStr hs$priceStr. (ID: ${appointment.id})';

                        if (selectedProfileId != null) {
                          final conversation = ref
                              .read(
                                currentConversationProvider(selectedProfileId),
                              )
                              .value;
                          if (conversation != null) {
                            await ref
                                .read(chatRepositoryProvider)
                                .sendMessage(
                                  conversation.id,
                                  currentUserId,
                                  messageContent,
                                );
                          }
                        }

                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                userMode == UserMode.professional
                                    ? 'Propuesta de turno enviada con éxito'
                                    : 'Turno solicitado con éxito',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _isSaving = false);
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : Colors.black,
                foregroundColor: isDark ? Colors.black : Colors.white,
                disabledBackgroundColor: isDark
                    ? Colors.white12
                    : Colors.black12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isSaving
                  ? const CircularProgressIndicator()
                  : Text(
                      userMode == UserMode.professional
                          ? 'Enviar Propuesta'
                          : 'Enviar Solicitud',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<DateTime?> _showCustomDatePicker({
    required BuildContext context,
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) async {
    DateTime tempDate = initialDate;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E222B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (BuildContext context) {
        return Container(
          height: 300,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancelar',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      'Seleccionar Fecha',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(tempDate),
                      child: const Text(
                        'Confirmar',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: CupertinoTheme(
                  data: CupertinoThemeData(
                    brightness: isDark ? Brightness.dark : Brightness.light,
                    textTheme: CupertinoTextThemeData(
                      dateTimePickerTextStyle: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: tempDate,
                    minimumDate: firstDate,
                    maximumDate: lastDate,
                    onDateTimeChanged: (DateTime newDate) {
                      tempDate = newDate;
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<TimeOfDay?> _showCustomTimePicker({
    required BuildContext context,
    required TimeOfDay initialTime,
  }) async {
    TimeOfDay tempTime = initialTime;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E222B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (BuildContext context) {
        return Container(
          height: 300,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancelar',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      'Seleccionar Hora',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(tempTime),
                      child: const Text(
                        'Confirmar',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: CupertinoTheme(
                  data: CupertinoThemeData(
                    brightness: isDark ? Brightness.dark : Brightness.light,
                    textTheme: CupertinoTextThemeData(
                      dateTimePickerTextStyle: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    initialDateTime: DateTime(2020, 1, 1, tempTime.hour, tempTime.minute),
                    onDateTimeChanged: (DateTime newDate) {
                      tempTime = TimeOfDay(hour: newDate.hour, minute: newDate.minute);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
