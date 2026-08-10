import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:zenvi/core/supabase/supabase_config.dart';
import 'package:zenvi/features/auth/domain/providers/auth_provider.dart';
import 'package:zenvi/features/appointments/domain/providers/appointment_providers.dart';
import 'package:zenvi/features/appointments/domain/models/appointment.dart';
import 'package:zenvi/shared/domain/models/profile.dart';
import 'package:zenvi/core/theme/zervi_theme.dart';
import 'package:zenvi/features/profile/domain/models/professional_client.dart';
import 'package:zenvi/features/profile/domain/providers/professional_client_providers.dart';

class CustomerWithAppointments {
  final Profile? profile;
  final ProfessionalClient? customClient;
  final List<Appointment> appointments;

  CustomerWithAppointments({
    this.profile,
    this.customClient,
    required this.appointments,
  });

  String get displayName => customClient?.fullName ?? profile?.fullName ?? 'Usuario';
  String? get email => customClient?.email;
  String? get phone => customClient?.phone;
  String? get avatarUrl => profile?.avatarUrl;
}

// Provider para resolver los clientes del profesional y sus turnos
final myCustomersProvider = FutureProvider<List<CustomerWithAppointments>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final supabase = ref.watch(supabaseClientProvider);
  
  // 1. Obtener todos los turnos del usuario
  final appointments = await ref.watch(userAppointmentsProvider.future);
  final providerAppts = appointments.where((a) => a.professionalId == user.id).toList();

  // 2. Obtener los clientes profesionales de la base de datos
  final customClientsList = await ref.watch(professionalClientsProvider.future);

  // 3. Obtener perfiles de clientes registrados que tengan turnos
  final registeredClientIdsWithAppts = providerAppts
      .map((a) => a.customerId)
      .where((id) => id != null)
      .cast<String>()
      .toSet();

  // Obtener los ids de perfiles ya cubiertos por los clientes profesionales
  final coveredProfileIds = customClientsList
      .map((c) => c.clientProfileId)
      .where((id) => id != null)
      .cast<String>()
      .toSet();

  // Los ids de perfiles que tienen turnos pero no están en professional_clients
  final remainingProfileIds = registeredClientIdsWithAppts.difference(coveredProfileIds);

  // Buscar perfiles de los clientes restantes
  List<Profile> remainingProfiles = [];
  if (remainingProfileIds.isNotEmpty) {
    try {
      final response = await supabase.from('profiles').select().inFilter('id', remainingProfileIds.toList());
      remainingProfiles = (response as List).map((json) => Profile.fromJson(json)).toList();
    } catch (_) {}
  }

  // Buscar perfiles de los customClients que están vinculados
  final linkedProfileIds = customClientsList
      .map((c) => c.clientProfileId)
      .where((id) => id != null)
      .cast<String>()
      .toSet();

  List<Profile> linkedProfiles = [];
  if (linkedProfileIds.isNotEmpty) {
    try {
      final response = await supabase.from('profiles').select().inFilter('id', linkedProfileIds.toList());
      linkedProfiles = (response as List).map((json) => Profile.fromJson(json)).toList();
    } catch (_) {}
  }

  final Map<String, Profile> profilesMap = {
    for (var p in linkedProfiles) p.id: p,
    for (var p in remainingProfiles) p.id: p,
  };

  final List<CustomerWithAppointments> result = [];

  // Agregar los de professional_clients
  for (var client in customClientsList) {
    final profile = client.clientProfileId != null ? profilesMap[client.clientProfileId] : null;
    final clientAppts = providerAppts.where((a) {
      return a.customClientId == client.id || 
             (client.clientProfileId != null && a.customerId == client.clientProfileId);
    }).toList();
    clientAppts.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    
    result.add(CustomerWithAppointments(
      profile: profile,
      customClient: client,
      appointments: clientAppts,
    ));
  }

  // Agregar los perfiles restantes (que tienen turno pero no están en la lista del profesional)
  for (var profile in remainingProfiles) {
    final clientAppts = providerAppts.where((a) => a.customerId == profile.id).toList();
    clientAppts.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

    result.add(CustomerWithAppointments(
      profile: profile,
      customClient: null,
      appointments: clientAppts,
    ));
  }

  return result;
});

class MyCustomersScreen extends ConsumerStatefulWidget {
  const MyCustomersScreen({super.key});

  @override
  ConsumerState<MyCustomersScreen> createState() => _MyCustomersScreenState();
}

class _MyCustomersScreenState extends ConsumerState<MyCustomersScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _isInviting = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showAddCustomerDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E222B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Registrar Cliente',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Nombre Completo',
                      labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Por favor ingresá el nombre';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Correo Electrónico (Opcional)',
                      labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Teléfono (Opcional)',
                      labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesCtrl,
                    maxLines: 2,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Notas / Detalles',
                      labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : Colors.black,
                foregroundColor: isDark ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final user = ref.read(currentUserProvider);
                  if (user == null) return;

                  final client = ProfessionalClient(
                    id: '', // Se autogenera en la DB
                    professionalId: user.id,
                    fullName: nameCtrl.text.trim(),
                    email: emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
                    phone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                    notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                    createdAt: DateTime.now(),
                  );

                  try {
                    await ref.read(professionalClientRepositoryProvider).createClient(client);
                    ref.invalidate(professionalClientsProvider);
                    ref.invalidate(myCustomersProvider);
                    
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Cliente registrado correctamente'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error al registrar cliente: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleInviteClient(BuildContext context, ProfessionalClient client) async {
    if (client.email == null || client.email!.isEmpty) return;

    setState(() => _isInviting = true);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    try {
      final repo = ref.read(professionalClientRepositoryProvider);
      
      // 1. Invitar al cliente (crearlo en auth.users + perfiles y auto-vincular)
      final invitedUserId = await repo.inviteClient(client.email!, client.fullName);
      
      if (invitedUserId != null) {
        // 2. Enviar el correo de restablecimiento / confirmación de contraseña de Supabase
        await ref.read(supabaseClientProvider).auth.resetPasswordForEmail(client.email!);
        
        ref.invalidate(professionalClientsProvider);
        ref.invalidate(myCustomersProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invitación enviada por correo a ${client.email}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('El servicio de invitación de Supabase devolvió un identificador nulo.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar invitación: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isInviting = false);
      }
    }
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
        actions: [
          IconButton(
            icon: Icon(Icons.person_add_alt_1_rounded, color: isDark ? Colors.white : Colors.black87),
            onPressed: () => _showAddCustomerDialog(context),
          ),
        ],
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
                  final name = c.displayName.toLowerCase();
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
                              ? 'Agregá un cliente usando el botón de arriba.'
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
    final name = item.displayName;
    final avatarUrl = item.avatarUrl;
    final totalAppts = item.appointments.length;
    final completedAppts = item.appointments.where((a) => a.status == AppointmentStatus.completed).length;
    
    final lastAppt = item.appointments.isNotEmpty ? item.appointments.first : null;
    final lastDateStr = lastAppt != null ? DateFormat('dd/MM/yyyy').format(lastAppt.scheduledAt) : 'Sin turnos';

    final isRegistered = item.profile != null || item.customClient?.clientProfileId != null;
    final hasEmail = item.email != null && item.email!.isNotEmpty;

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
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Etiqueta de estado
                          if (isRegistered)
                            _buildStatusTag(
                              label: 'Registrado',
                              color: Colors.green,
                              isDark: isDark,
                            )
                          else if (hasEmail)
                            _buildStatusTag(
                              label: 'Manual (Email)',
                              color: Colors.blue,
                              isDark: isDark,
                            )
                          else
                            _buildStatusTag(
                              label: 'Manual',
                              color: Colors.grey,
                              isDark: isDark,
                            ),
                        ],
                      ),
                      if (item.email != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.email!,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white30 : Colors.black45,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
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
                if (isRegistered)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final profileId = item.customClient?.clientProfileId ?? item.profile?.id;
                        if (profileId != null) {
                          context.push('/chat_user/$profileId');
                        }
                      },
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
                  )
                else if (hasEmail && item.customClient != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isInviting ? null : () => _handleInviteClient(context, item.customClient!),
                      icon: _isInviting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.mail_outline_rounded, size: 16),
                      label: const Text('Invitar a App'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                      label: const Text('Chat desc.'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.white12 : Colors.black12,
                        foregroundColor: isDark ? Colors.white30 : Colors.black38,
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

  Widget _buildStatusTag({
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
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
                child: appointments.isEmpty
                    ? Center(
                        child: Text(
                          'No hay turnos registrados con este cliente.',
                          style: TextStyle(
                            color: isDark ? Colors.white30 : Colors.black38,
                          ),
                        ),
                      )
                    : ListView.builder(
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
