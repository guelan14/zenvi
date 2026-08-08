import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:zenvi/core/supabase/supabase_config.dart';
import 'package:zenvi/features/auth/domain/providers/auth_provider.dart';
import 'package:zenvi/features/appointments/domain/providers/appointment_providers.dart';
import 'package:zenvi/features/appointments/domain/models/appointment.dart';
import 'package:zenvi/shared/domain/models/profile.dart';
import 'package:zenvi/core/theme/zervi_theme.dart';

class CustomerWithAppointments {
  final Profile profile;
  final List<Appointment> appointments;

  CustomerWithAppointments({
    required this.profile,
    required this.appointments,
  });
}

// Provider para resolver los clientes del profesional y sus turnos
final myCustomersProvider = FutureProvider<List<CustomerWithAppointments>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  // 1. Obtener todos los turnos del usuario
  final appointments = await ref.watch(userAppointmentsProvider.future);
  
  // 2. Filtrar únicamente donde el usuario actual actúa como profesional
  final providerAppts = appointments.where((a) => a.professionalId == user.id).toList();

  // 3. Agrupar turnos por customerId
  final Map<String, List<Appointment>> groups = {};
  for (var a in providerAppts) {
    groups.putIfAbsent(a.customerId, () => []).add(a);
  }

  if (groups.isEmpty) return [];

  // 4. Obtener perfiles de todos los clientes agrupados en una sola consulta bulk
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase.from('profiles').select().inFilter('id', groups.keys.toList());

  final profiles = (response as List).map((json) => Profile.fromJson(json)).toList();

  // 5. Mapear y ordenar por fecha de turno más reciente
  return profiles.map((profile) {
    final clientAppts = groups[profile.id] ?? [];
    clientAppts.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    return CustomerWithAppointments(
      profile: profile,
      appointments: clientAppts,
    );
  }).toList();
});

class MyCustomersScreen extends ConsumerStatefulWidget {
  const MyCustomersScreen({super.key});

  @override
  ConsumerState<MyCustomersScreen> createState() => _MyCustomersScreenState();
}

class _MyCustomersScreenState extends ConsumerState<MyCustomersScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(myCustomersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Mis Clientes',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Barra de búsqueda Premium
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E222B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    color: isDark ? Colors.white30 : Colors.black38,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Buscar cliente por nombre...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white30 : Colors.black38,
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim().toLowerCase();
                        });
                      },
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                      child: Icon(
                        Icons.clear_rounded,
                        color: isDark ? Colors.white54 : Colors.black45,
                        size: 18,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Lista de clientes
          Expanded(
            child: customersAsync.when(
              loading: () => _buildLoadingSkeleton(),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'Ocurrió un error al cargar la cartera de clientes.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                  ),
                ),
              ),
              data: (customers) {
                final filtered = customers.where((c) {
                  final name = c.profile.fullName?.toLowerCase() ?? '';
                  return name.contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline_rounded,
                          size: 64,
                          color: isDark ? Colors.white24 : Colors.black12,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty 
                              ? 'Aún no tenés clientes registrados.' 
                              : 'No se encontraron coincidencias.',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Cuando un cliente reserve un turno aparecerá acá.'
                              : 'Probá con otros términos de búsqueda.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white30 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _buildCustomerCard(context, item, isDark);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(BuildContext context, CustomerWithAppointments item, bool isDark) {
    final name = item.profile.fullName ?? 'Usuario';
    final avatarUrl = item.profile.avatarUrl;
    final totalAppts = item.appointments.length;
    final completedAppts = item.appointments.where((a) => a.status == AppointmentStatus.completed).length;
    
    final lastAppt = item.appointments.first;
    final lastDateStr = DateFormat('dd/MM/yyyy').format(lastAppt.scheduledAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null || avatarUrl.isEmpty
                      ? Text(
                          name[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                // Información principal
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Fila de estadísticas rápidas
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildStatTag(
                              icon: Icons.calendar_month_rounded,
                              label: '$totalAppts turnos',
                              color: isDark ? const Color(0xFF9C27B0) : const Color(0xFF7B1FA2),
                              isDark: isDark,
                            ),
                            const SizedBox(width: 8),
                            if (completedAppts > 0) ...[
                              _buildStatTag(
                                icon: Icons.check_circle_rounded,
                                label: '$completedAppts completados',
                                color: isDark ? const Color(0xFF4CAF50) : const Color(0xFF388E3C),
                                isDark: isDark,
                              ),
                              const SizedBox(width: 8),
                            ],
                            _buildStatTag(
                              icon: Icons.access_time_filled_rounded,
                              label: 'Último: $lastDateStr',
                              color: isDark ? Colors.white30 : Colors.black45,
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, thickness: 1),
            const SizedBox(height: 12),
            // Acciones Rápidas
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _showAppointmentHistory(context, name, item.appointments),
                    icon: const Icon(Icons.history_rounded, size: 16),
                    label: const Text('Historial'),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? Colors.white70 : Colors.black54,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/chat_user/${item.profile.id}'),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                    label: const Text('Chat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : Colors.black,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
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

  Widget _buildStatTag({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    final tagBg = color.withOpacity(isDark ? 0.15 : 0.08);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tagBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 140,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E222B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 120,
                            height: 14,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                width: 60,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 80,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAppointmentHistory(BuildContext context, String customerName, List<Appointment> appointments) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).padding.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E222B) : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
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
                'Historial de Turnos',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Historial de servicios acordados con $customerName',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: appointments.length,
                  itemBuilder: (context, index) {
                    final appt = appointments[index];
                    final dateStr = DateFormat('dd/MM/yyyy').format(appt.scheduledAt);
                    final timeStr = DateFormat('HH:mm').format(appt.scheduledAt);
                    final priceStr = appt.price != null ? '\$${appt.price!.toStringAsFixed(0)}' : 'A coordinar';
                    
                    Color statusColor;
                    String statusLabel;
                    switch (appt.status) {
                      case AppointmentStatus.accepted:
                        statusColor = Colors.blue;
                        statusLabel = 'Aceptado';
                        break;
                      case AppointmentStatus.rejected:
                        statusColor = Colors.red;
                        statusLabel = 'Rechazado';
                        break;
                      case AppointmentStatus.completed:
                        statusColor = Colors.green;
                        statusLabel = 'Completado';
                        break;
                      case AppointmentStatus.cancelled:
                        statusColor = Colors.grey;
                        statusLabel = 'Cancelado';
                        break;
                      default:
                        statusColor = Colors.orange;
                        statusLabel = 'Pendiente';
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF14171E) : const Color(0xFFF9F9F9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.calendar_today_rounded, size: 14, color: isDark ? Colors.white54 : Colors.black45),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$dateStr a las $timeStr hs',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Monto / Presupuesto:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white54 : Colors.black54,
                                ),
                              ),
                              Text(
                                priceStr,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: appt.status == AppointmentStatus.completed && appt.price != null
                                      ? Colors.green
                                      : (isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                            ],
                          ),
                          if (appt.notes != null && appt.notes!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Detalles:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white30 : Colors.black38,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              appt.notes!,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : Colors.black54,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
