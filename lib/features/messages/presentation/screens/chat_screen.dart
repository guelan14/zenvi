import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:zenvi/features/home/domain/models/listing.dart';
import 'package:zenvi/features/auth/domain/providers/auth_provider.dart';
import 'package:zenvi/features/profile/domain/providers/profile_providers.dart';
import 'package:zenvi/features/appointments/domain/models/appointment.dart';
import 'package:zenvi/features/appointments/domain/providers/appointment_providers.dart';
import 'package:zenvi/features/messages/domain/providers/chat_providers.dart';
import 'package:zenvi/features/home/domain/providers/home_providers.dart';
import 'package:uuid/uuid.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final Listing? listing;
  final String? otherUserId;
  const ChatScreen({super.key, this.listing, this.otherUserId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final targetUserId = widget.listing?.authorId ?? widget.otherUserId;
    if (targetUserId == null) {
      return const Scaffold(body: Center(child: Text('Error: No target user specified')));
    }

    final currentUser = ref.watch(currentUserProvider);
    final conversationAsync = ref.watch(currentConversationProvider(targetUserId));
    final profileAsync = ref.watch(profileProvider(targetUserId));

    final conversation = conversationAsync.value;
    Listing? activeListing = widget.listing;
    if (activeListing == null && conversation != null && conversation.serviceRequestId != null) {
      final listingAsync = ref.watch(listingByIdProvider(conversation.serviceRequestId!));
      activeListing = listingAsync.value;
    }

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
        title: profileAsync.when(
          loading: () => const Text('Cargando...'),
          error: (_, __) => const Text('Error al cargar'),
          data: (profile) {
            final name = profile?.fullName ?? activeListing?.title ?? 'Usuario';
            final avatarUrl = profile?.avatarUrl;
            
            return Row(
              children: [
                CircleAvatar(
                  backgroundColor: isDark ? Colors.white10 : Colors.black12,
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null 
                      ? Text(
                          name[0].toUpperCase(),
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        ) 
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (activeListing != null)
                        Text(
                          activeListing.title,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.more_vert, color: isDark ? Colors.white : Colors.black),
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Banner de Turno ───────────────────────────────────────────────
          if (activeListing != null) _buildAppointmentBanner(activeListing),

          Expanded(
            child: conversationAsync.when(
              loading: () => Center(child: CircularProgressIndicator(color: isDark ? Colors.white : Colors.black)),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (conversation) {
                if (conversation == null) return const Center(child: Text('No se pudo cargar la conversación'));
                
                final messagesAsync = ref.watch(messagesStreamProvider(conversation.id));
                return messagesAsync.when(
                  loading: () => Center(child: CircularProgressIndicator(color: isDark ? Colors.white : Colors.black)),
                  error: (err, _) => Center(child: Text('Error: $err')),
                  data: (messages) {
                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(20),
                      itemCount: messages.length + 1,
                      itemBuilder: (context, index) {
                        if (index == messages.length) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildSystemMessage('Iniciaste una conversación por este servicio'),
                          );
                        }
                        
                        final msg = messages[index];
                        final isMe = msg.senderId == currentUser?.id;
                        return _buildMessageBubble(msg.content, isMe: isMe);
                      },
                    );
                  },
                );
              },
            ),
          ),

          // ─── Input ─────────────────────────────────────────────────────────
          _buildInput(conversationAsync.value?.id, currentUser?.id),
        ],
      ),
    );
  }

  Widget _buildAppointmentBanner(Listing listing) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.calendar_today_rounded, size: 20, color: isDark ? Colors.white : Colors.black87),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Querés agendar un turno?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  'Consultá los horarios disponibles.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _showRequestAppointment(context, ref, listing),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.white : Colors.black,
              foregroundColor: isDark ? Colors.black : Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Solicitar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, {required bool isMe}) {
    final regExp = RegExp(r'\(ID: ([a-fA-F0-9\-]+)\)');
    final hasAppointmentId = regExp.hasMatch(text);
    String displayText = text;
    String? appointmentId;

    if (hasAppointmentId) {
      final match = regExp.firstMatch(text);
      appointmentId = match?.group(1);
      displayText = text.replaceAll(regExp, '').trim();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (hasAppointmentId && appointmentId != null) {
      final cardColor = isMe 
          ? (isDark ? Colors.white : Colors.black87) 
          : (isDark ? const Color(0xFF1E222B) : Colors.white);
      final borderColor = isMe 
          ? (isDark ? Colors.white : Colors.black) 
          : (isDark ? Colors.white10 : Colors.black12);
      final iconColor = isMe 
          ? (isDark ? Colors.black : Colors.white) 
          : Colors.blue[600];
      final textColor = isMe 
          ? (isDark ? Colors.black : Colors.white) 
          : (isDark ? Colors.white : Colors.black87);
      final actionTextColor = isMe 
          ? (isDark ? Colors.black : Colors.white) 
          : (isDark ? Colors.blue[400] : Colors.blue[700]);

      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      color: iconColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        displayText,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 1, color: isDark ? Colors.white10 : Colors.black12),
              InkWell(
                onTap: () => context.push('/appointment/$appointmentId'),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  child: Text(
                    'Ver Detalle del Turno',
                    style: TextStyle(
                      color: actionTextColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final bubbleBg = isMe
        ? (isDark ? Colors.white : Colors.black)
        : (isDark ? const Color(0xFF1E222B) : Colors.white);
    final bubbleTextColor = isMe
        ? (isDark ? Colors.black : Colors.white)
        : (isDark ? Colors.white : Colors.black87);
    final border = isDark && !isMe ? Border.all(color: Colors.white10) : null;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: bubbleBg,
          border: border,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: [
            if (!isMe)
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: bubbleTextColor,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildSystemMessage(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white54 : Colors.black45,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildInput(String? conversationId, String? currentUserId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFEEEEEE))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF14171E) : const Color(0xFFF1F1F1),
                borderRadius: BorderRadius.circular(24),
                border: isDark ? Border.all(color: Colors.white10) : null,
              ),
              child: TextField(
                controller: _messageController,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Escribí un mensaje...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white30 : Colors.black38,
                  ),
                ),
                onSubmitted: (_) {
                  _sendMessage(conversationId, currentUserId);
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white : Colors.black,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () => _sendMessage(conversationId, currentUserId),
              icon: Icon(
                Icons.send_rounded,
                color: isDark ? Colors.black : Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage(String? conversationId, String? currentUserId) async {
    final text = _messageController.text;
    if (text.isEmpty || conversationId == null || currentUserId == null) return;
    _messageController.clear();
    try {
      await ref.read(chatRepositoryProvider).sendMessage(conversationId, currentUserId, text);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _showRequestAppointment(BuildContext context, WidgetRef ref, Listing listing) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Iniciá sesión para solicitar un turno')),
      );
      return;
    }

    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    final notesController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
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
                    'Solicitar Turno',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Elegí la fecha y hora para el servicio.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Botón de fecha
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now().add(const Duration(days: 1)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 30)),
                            );
                            if (date != null) {
                              setState(() => selectedDate = date);
                            }
                          },
                          icon: Icon(
                            Icons.calendar_today_rounded,
                            size: 18,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          label: Text(
                            selectedDate == null
                                ? 'Seleccionar Fecha'
                                : DateFormat('dd/MM/yyyy').format(selectedDate!),
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(
                              color: isDark ? Colors.white10 : Colors.black12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Botón de hora
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: const TimeOfDay(hour: 9, minute: 0),
                            );
                            if (time != null) {
                              setState(() => selectedTime = time);
                            }
                          },
                          icon: Icon(
                            Icons.access_time_rounded,
                            size: 18,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          label: Text(
                            selectedTime == null
                                ? 'Seleccionar Hora'
                                : selectedTime!.format(context),
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(
                              color: isDark ? Colors.white10 : Colors.black12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Campo de notas
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
                      hintText: 'Detallá tu necesidad o indicaciones para llegar...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white30 : Colors.black38,
                      ),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF14171E) : const Color(0xFFF5F5F5),
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
                  
                  // Botón confirmar
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (selectedDate == null || selectedTime == null)
                          ? null
                          : () async {
                              final start = DateTime(
                                selectedDate!.year,
                                selectedDate!.month,
                                selectedDate!.day,
                                selectedTime!.hour,
                                selectedTime!.minute,
                              );

                              final appointment = Appointment(
                                id: const Uuid().v4(),
                                listingId: listing.id,
                                customerId: user.id,
                                professionalId: listing.authorId,
                                scheduledAt: start,
                                notes: notesController.text.trim().isNotEmpty
                                    ? notesController.text.trim()
                                    : null,
                                createdAt: DateTime.now(),
                              );

                              try {
                                await ref
                                    .read(appointmentRepositoryProvider)
                                    .createAppointment(appointment);

                                final dateStr = DateFormat('dd/MM/yyyy').format(start);
                                final timeStr = DateFormat('HH:mm').format(start);
                                final messageContent =
                                    '📅 Solicitó un turno para el día $dateStr a las $timeStr hs. (ID: ${appointment.id})';

                                final targetUserId = widget.listing?.authorId ?? widget.otherUserId;
                                if (targetUserId != null) {
                                  final conversation = ref
                                      .read(currentConversationProvider(targetUserId))
                                      .value;
                                  if (conversation != null) {
                                    await ref
                                        .read(chatRepositoryProvider)
                                        .sendMessage(
                                          conversation.id,
                                          user.id,
                                          messageContent,
                                        );
                                  }
                                }

                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Turno solicitado con éxito'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.white : Colors.black,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        disabledBackgroundColor: isDark ? Colors.white10 : Colors.black12,
                        disabledForegroundColor: isDark ? Colors.white30 : Colors.black38,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Solicitar Turno',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
