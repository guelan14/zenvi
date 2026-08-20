import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:zenvi/core/theme/zervi_theme.dart';
import 'package:zenvi/features/appointments/domain/models/appointment.dart';
import 'package:zenvi/features/appointments/domain/providers/appointment_providers.dart';
import 'package:zenvi/features/auth/domain/providers/auth_provider.dart';
import 'package:zenvi/features/profile/domain/providers/profile_providers.dart';
import 'package:zenvi/shared/domain/models/profile.dart';
import 'package:zenvi/shared/widgets/zervi_skeleton.dart';
import 'package:zenvi/features/profile/domain/models/professional_client.dart';
import 'package:zenvi/features/profile/domain/providers/professional_client_providers.dart';
import 'package:zenvi/features/messages/domain/providers/chat_providers.dart';
import 'package:zenvi/features/home/domain/providers/home_providers.dart';

class AppointmentDetailScreen extends ConsumerWidget {
  final String appointmentId;

  const AppointmentDetailScreen({super.key, required this.appointmentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentAsync = ref.watch(appointmentByIdProvider(appointmentId));
    final currentUserId = ref.watch(currentUserProvider)?.id;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Detalle del Turno'),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: isDark ? Colors.white : Colors.black,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: appointmentAsync.when(
        loading: () => const ZerviAppointmentDetailSkeleton(),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Error al cargar el turno: $error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
        data: (appointment) {
          if (appointment == null) {
            return const Center(child: Text('El turno solicitado no existe.'));
          }

          final isBlockedDay = appointment.notes != null && appointment.notes!.startsWith('[BLOCKED_DAY]');
          if (isBlockedDay) {
            return _buildBlockedDayDetailView(context, ref, appointment, isDark, currentUserId);
          }

          final isReminder = appointment.notes != null && appointment.notes!.startsWith('[PERSONAL_REMINDER]');
          if (isReminder) {
            return _buildReminderDetailView(context, ref, appointment, isDark, currentUserId);
          }

          final isProfessional = appointment.professionalId == currentUserId;
          final otherUserId = isProfessional
              ? appointment.customerId
              : appointment.professionalId;

          final otherProfileAsync = otherUserId != null
              ? ref.watch(profileProvider(otherUserId))
              : const AsyncValue<Profile?>.data(null);

          final customClientAsync = appointment.customClientId != null
              ? ref.watch(professionalClientByIdProvider(appointment.customClientId!))
              : const AsyncValue<ProfessionalClient?>.data(null);
          final listingAsync = ref.watch(
            listingByIdProvider(appointment.listingId),
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Tarjeta de Estado Principal
                _buildStatusHeader(context, appointment),
                const SizedBox(height: 20),

                if (appointment.status == AppointmentStatus.accepted ||
                    appointment.status == AppointmentStatus.completed) ...[
                  _buildPaymentCard(context, appointment, listingAsync.value),
                  const SizedBox(height: 20),
                ],

                // 2. Fecha y Hora
                _buildDateTimeCard(context, appointment),
                const SizedBox(height: 20),

                // 3. Detalle del Servicio
                listingAsync.when(
                  loading: () => const ZerviListingCardSkeleton(),
                  error: (e, _) => const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No se pudo cargar la información del servicio.',
                      ),
                    ),
                  ),
                  data: (listing) {
                    if (listing == null) return const SizedBox();
                    return _buildListingCard(context, listing, appointment);
                  },
                ),
                const SizedBox(height: 20),

                // 4. Datos de la otra persona (Profesional / Cliente / Externo)
                if (otherUserId != null)
                  otherProfileAsync.when(
                    loading: () => const ZerviContactCardSkeleton(),
                    error: (e, _) => const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('No se pudo cargar el perfil del contacto.'),
                      ),
                    ),
                    data: (profile) {
                      if (profile == null) return const SizedBox();
                      return _buildContactCard(context, profile, isProfessional);
                    },
                  )
                else
                  customClientAsync.when(
                    loading: () => const ZerviContactCardSkeleton(),
                    error: (e, _) => const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('No se pudo cargar la información del cliente.'),
                      ),
                    ),
                    data: (client) {
                      if (client == null) return const SizedBox();
                      return _buildCustomClientCard(context, client, isDark);
                    },
                  ),

                // 5. Notas
                if (appointment.notes != null &&
                    appointment.notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildNotesCard(context, appointment.notes!),
                ],

                const SizedBox(height: 32),

                // 6. Botones de Acción
                _buildActionButtons(
                  context,
                  ref,
                  appointment,
                  isProfessional,
                  otherUserId,
                  currentUserId,
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusHeader(BuildContext context, Appointment appointment) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color color;
    String statusText;
    IconData icon;

    switch (appointment.status) {
      case AppointmentStatus.pending:
        color = Colors.orange;
        statusText = 'Pendiente de confirmación';
        icon = Icons.hourglass_empty_rounded;
        break;
      case AppointmentStatus.proposed:
        color = Colors.orange;
        statusText = 'Propuesta de turno';
        icon = Icons.mail_outline_rounded;
        break;
      case AppointmentStatus.accepted:
        color = Colors.green;
        statusText = 'Confirmado';
        icon = Icons.check_circle_outline_rounded;
        break;
      case AppointmentStatus.rejected:
        color = Colors.red;
        statusText = 'Rechazado';
        icon = Icons.cancel_outlined;
        break;
      case AppointmentStatus.completed:
        color = Colors.blue;
        statusText = 'Completado';
        icon = Icons.done_all_rounded;
        break;
      case AppointmentStatus.cancelled:
        color = Colors.red;
        statusText = 'Cancelado';
        icon = Icons.block_rounded;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(ZerviTheme.borderRadius),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estado del Turno',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 18,
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (appointment.status == AppointmentStatus.accepted ||
                        appointment.status == AppointmentStatus.completed) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_rounded, color: Colors.green, size: 10),
                            SizedBox(width: 4),
                            Text(
                              'PAGADO',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Colors.green,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(
    BuildContext context,
    Appointment appointment,
    dynamic listing,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double? displayPrice = appointment.price ?? (listing?.price != null ? (listing!.price as num).toDouble() : null);
    final priceText = displayPrice != null
        ? '\$${displayPrice.toStringAsFixed(0)}'
        : 'A convenir';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(ZerviTheme.borderRadius),
        border: Border.all(color: Colors.green.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : const Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.payments_outlined,
              color: Colors.green,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'INFORMACIÓN DE PAGO',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'PAGADO',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Método:',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    const Text(
                      'Mercado Pago (Simulado)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Monto Total:',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    Text(
                      priceText,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeCard(BuildContext context, Appointment appointment) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dayName = DateFormat('EEEE', 'es_ES').format(appointment.scheduledAt);
    final dateStr = DateFormat(
      'd \'de\' MMMM, yyyy',
      'es_ES',
    ).format(appointment.scheduledAt);
    final hourStr = DateFormat('HH:mm').format(appointment.scheduledAt);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(ZerviTheme.borderRadius),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : const Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.calendar_today_rounded,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dayName.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$hourStr hs',
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListingCard(BuildContext context, dynamic listing, Appointment appointment) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double? displayPrice = appointment.price ?? (listing?.price != null ? (listing!.price as num).toDouble() : null);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(ZerviTheme.borderRadius),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : const Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SERVICIO / TRABAJO',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/listing/${listing.id}'),
                child: Row(
                  children: [
                    Text(
                      'Ver publicación',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            listing.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 16,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
              const SizedBox(width: 4),
              Text(
                listing.city ?? 'Posadas, Misiones',
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          if (displayPrice != null) ...[
            const SizedBox(height: 8),
            Text(
              '\$${displayPrice.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContactCard(
    BuildContext context,
    dynamic profile,
    bool isProfessional,
  ) {
    final title = isProfessional ? 'Cliente' : 'Profesional';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(ZerviTheme.borderRadius),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : const Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white54 : Colors.black54,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: isDark ? Colors.white12 : Colors.black12,
                backgroundImage:
                    profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty
                    ? NetworkImage(profile.avatarUrl!)
                    : null,
                child: profile.avatarUrl == null || profile.avatarUrl!.isEmpty
                    ? Icon(
                        Icons.person,
                        color: isDark ? Colors.white54 : Colors.black54,
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.fullName ?? 'Usuario de Zenvi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        profile.bio!,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: isDark ? Colors.white : Colors.black,
                ),
                onPressed: () => context.push('/chat_user/${profile.id}'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard(BuildContext context, String notes) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(ZerviTheme.borderRadius),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : const Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NOTAS ADICIONALES',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white54 : Colors.black54,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            notes,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black87,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    WidgetRef ref,
    Appointment appointment,
    bool isProfessional,
    String? otherUserId,
    String? currentUserId,
  ) {
    final repository = ref.read(appointmentRepositoryProvider);

    final isProposedByProfessional = appointment.status == AppointmentStatus.proposed || appointment.createdByProvider == true;

    Future<void> updateStatus(
      AppointmentStatus newStatus,
      String successMsg,
    ) async {
      try {
        await repository.updateAppointmentStatus(appointment.id, newStatus);

        // Invalidate providers to trigger rebuild of detailed screen & general agenda list
        ref.invalidate(appointmentByIdProvider(appointment.id));
        ref.invalidate(userAppointmentsProvider);

        if (currentUserId != null && otherUserId != null) {
          final conversation = await ref
              .read(chatRepositoryProvider)
              .getOrCreateConversation(currentUserId, otherUserId);

          final statusLabel = newStatus == AppointmentStatus.accepted
              ? 'aceptado'
              : newStatus == AppointmentStatus.rejected
              ? 'rechazado'
              : newStatus == AppointmentStatus.completed
              ? 'marcado como completado'
              : 'cancelado';

          final messageContent =
              'El turno (ID: ${appointment.id}) fue $statusLabel.';
          await ref
              .read(chatRepositoryProvider)
              .sendMessage(conversation.id, currentUserId, messageContent);
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(successMsg),
              backgroundColor: Colors.black87,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al actualizar el turno: $e'),
              backgroundColor: Colors.red[800],
            ),
          );
        }
      }
    }

    Future<void> confirmCompletion() async {
      try {
        await repository.confirmAppointmentCompletion(appointment.id, isProfessional: isProfessional);

        // Invalidate providers to trigger rebuild of detailed screen & general agenda list
        ref.invalidate(appointmentByIdProvider(appointment.id));
        ref.invalidate(userAppointmentsProvider);

        if (currentUserId != null && otherUserId != null) {
          final conversation = await ref
              .read(chatRepositoryProvider)
              .getOrCreateConversation(currentUserId, otherUserId);

          final updatedAppointment = await repository.getAppointmentById(appointment.id);
          final isBothCompleted = updatedAppointment?.status == AppointmentStatus.completed;

          final String messageContent;
          if (isBothCompleted) {
            messageContent = '¡El trabajo fue completado por ambas partes! Ya podés dejar tu calificación.';
          } else {
            messageContent = isProfessional
                ? 'El profesional confirmó la finalización del trabajo (esperando confirmación del cliente).'
                : 'El cliente confirmó la finalización del trabajo (esperando confirmación del profesional).';
          }

          await ref
              .read(chatRepositoryProvider)
              .sendMessage(conversation.id, currentUserId, messageContent);
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Finalización confirmada correctamente.'),
              backgroundColor: Colors.black87,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al confirmar finalización: $e'),
              backgroundColor: Colors.red[800],
            ),
          );
        }
      }
    }

    if (appointment.status == AppointmentStatus.pending || appointment.status == AppointmentStatus.proposed) {
      final showAcceptReject = appointment.status == AppointmentStatus.proposed ? !isProfessional : isProfessional;

      if (showAcceptReject) {
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => updateStatus(
                  AppointmentStatus.rejected,
                  'Turno rechazado correctamente.',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Rechazar',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => updateStatus(
                  AppointmentStatus.accepted,
                  'Turno aceptado. ¡Agenda actualizada!',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Aceptar',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      } else {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => updateStatus(
              AppointmentStatus.cancelled,
              isProposedByProfessional ? 'Propuesta de turno cancelada.' : 'Solicitud de turno cancelada.',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              isProposedByProfessional ? 'Cancelar Propuesta' : 'Cancelar Solicitud',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    }

    if (appointment.status == AppointmentStatus.accepted) {
      final hasIConfirmed = isProfessional ? appointment.providerConfirmedCompletion : appointment.clientConfirmedCompletion;
      final hasOtherConfirmed = isProfessional ? appointment.clientConfirmedCompletion : appointment.providerConfirmedCompletion;

      return Column(
        children: [
          if (hasIConfirmed)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      hasOtherConfirmed
                          ? 'Finalización confirmada por ambos.'
                          : 'Confirmaste la finalización. Esperando confirmación del ${isProfessional ? 'cliente' : 'profesional'}.',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: confirmCompletion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  isProfessional ? 'Marcar Completado' : 'Confirmar Finalización',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => updateStatus(
                AppointmentStatus.cancelled,
                'El turno ha sido cancelado.',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Cancelar Turno',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      );
    }

    return const SizedBox();
  }

  Widget _buildCustomClientCard(BuildContext context, ProfessionalClient client, bool isDark) {
    return Card(
      color: isDark ? const Color(0xFF1E222B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
        ),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Datos del Cliente (Externo)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                  child: Text(
                    client.fullName.isNotEmpty ? client.fullName[0].toUpperCase() : 'C',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        client.fullName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (client.email != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          client.email!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white30 : Colors.black45,
                          ),
                        ),
                      ],
                      if (client.phone != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          client.phone!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white30 : Colors.black45,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockedDayDetailView(
    BuildContext context,
    WidgetRef ref,
    Appointment appointment,
    bool isDark,
    String? currentUserId,
  ) {
    final reason = appointment.notes!.replaceFirst('[BLOCKED_DAY]', '').trim();
    final displayReason = reason.isNotEmpty ? reason : 'Feriado / Día no laborable';
    final dateStr = DateFormat('EEEE, d \'de\' MMMM \'de\' yyyy', 'es_ES').format(appointment.scheduledAt);
    final isProfessional = appointment.professionalId == currentUserId;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? Colors.red.withOpacity(0.12) : Colors.red.withOpacity(0.06),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.redAccent.withOpacity(0.3), width: 2),
                ),
                child: const Icon(
                  Icons.block,
                  size: 64,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Día Bloqueado',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Establecido como no laborable',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              const SizedBox(height: 32),
              
              Card(
                color: isDark ? const Color(0xFF1E222B) : Colors.grey[100],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_month, color: isDark ? Colors.white70 : Colors.black54),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Fecha',
                                  style: TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dateStr,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Divider(),
                      ),
                      Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: isDark ? Colors.white70 : Colors.black54),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Motivo',
                                  style: TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  displayReason,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              
              if (isProfessional) ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            backgroundColor: isDark ? const Color(0xFF1E2E3D) : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: const Text('Habilitar Día', style: TextStyle(fontWeight: FontWeight.bold)),
                            content: const Text('¿Estás seguro de que quieres habilitar este día? Volverá a estar disponible para recibir turnos de tus clientes.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Habilitar'),
                              ),
                            ],
                          );
                        },
                      );

                      if (confirmed == true) {
                        try {
                          await ref.read(appointmentRepositoryProvider).deleteAppointment(appointment.id);
                          ref.invalidate(userAppointmentsProvider);
                          if (context.mounted) {
                            context.pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Día habilitado con éxito'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error al habilitar día: $e'), backgroundColor: Colors.redAccent),
                            );
                          }
                        }
                      }
                    },
                    icon: const Icon(Icons.lock_open_rounded),
                    label: const Text('Habilitar Día / Eliminar Bloqueo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReminderDetailView(
    BuildContext context,
    WidgetRef ref,
    Appointment appointment,
    bool isDark,
    String? currentUserId,
  ) {
    final note = appointment.notes!.replaceFirst('[PERSONAL_REMINDER]', '').trim();
    final displayNote = note.isNotEmpty ? note : 'Sin indicaciones';
    final dateStr = DateFormat('EEEE, d \'de\' MMMM \'de\' yyyy', 'es_ES').format(appointment.scheduledAt);
    final timeStr = DateFormat('HH:mm').format(appointment.scheduledAt);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? Colors.purple.withOpacity(0.12) : Colors.purple.withOpacity(0.06),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.purpleAccent.withOpacity(0.3), width: 2),
                ),
                child: const Icon(
                  Icons.bookmark_added_outlined,
                  size: 64,
                  color: Colors.purpleAccent,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Recordatorio Personal',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 32),
              
              Card(
                color: isDark ? const Color(0xFF1E222B) : Colors.grey[100],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_month, color: isDark ? Colors.white70 : Colors.black54),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Fecha y Hora',
                                  style: TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$dateStr a las $timeStr hs',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Divider(),
                      ),
                      Row(
                        children: [
                          Icon(Icons.notes, color: isDark ? Colors.white70 : Colors.black54),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Indicaciones / Notas',
                                  style: TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  displayNote,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          backgroundColor: isDark ? const Color(0xFF1E2E3D) : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: const Text('Eliminar Recordatorio', style: TextStyle(fontWeight: FontWeight.bold)),
                          content: const Text('¿Estás seguro de que quieres eliminar este recordatorio personal?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Eliminar'),
                            ),
                          ],
                        );
                      },
                    );

                    if (confirmed == true) {
                      try {
                        await ref.read(appointmentRepositoryProvider).deleteAppointment(appointment.id);
                        ref.invalidate(userAppointmentsProvider);
                        if (context.mounted) {
                          context.pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Recordatorio eliminado con éxito'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error al eliminar recordatorio: $e'), backgroundColor: Colors.redAccent),
                          );
                        }
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Eliminar Recordatorio', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
