import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenvi/features/home/domain/models/listing.dart';
import 'package:zenvi/features/auth/domain/providers/auth_provider.dart';
import 'package:zenvi/features/profile/domain/providers/profile_providers.dart';
import 'package:zenvi/features/appointments/domain/models/appointment.dart';
import 'package:zenvi/features/appointments/domain/providers/appointment_providers.dart';
import 'package:zenvi/features/messages/domain/providers/chat_providers.dart';
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: profileAsync.when(
          loading: () => const Text('Cargando...'),
          error: (_, __) => const Text('Error al cargar'),
          data: (profile) {
            final name = profile?.fullName ?? widget.listing?.title ?? 'Usuario';
            final avatarUrl = profile?.avatarUrl;
            
            return Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.black12,
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null ? Text(name[0].toUpperCase()) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.listing != null)
                        Text(
                          widget.listing!.title,
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
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
            icon: const Icon(Icons.more_vert, color: Colors.black),
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Banner de Turno ───────────────────────────────────────────────
          if (widget.listing != null) _buildAppointmentBanner(),

          // ─── Lista de Mensajes ─────────────────────────────────────────────
          Expanded(
            child: conversationAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: Colors.black)),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (conversation) {
                if (conversation == null) return const Center(child: Text('No se pudo cargar la conversación'));
                
                final messagesAsync = ref.watch(messagesStreamProvider(conversation.id));
                return messagesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: Colors.black)),
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

  Widget _buildAppointmentBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.calendar_today_rounded, size: 20, color: Colors.black87),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Querés agendar un turno?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  'Consultá los horarios disponibles.',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _showRequestAppointment(context, ref),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
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
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? Colors.black : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: [
            if (!isMe)
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isMe ? Colors.white : Colors.black87,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildSystemMessage(String text) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 11, color: Colors.black45, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildInput(String? conversationId, String? currentUserId) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F1F1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Escribí un mensaje...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(fontSize: 14, color: Colors.black38),
                ),
                onSubmitted: (_) {
                  _sendMessage(conversationId, currentUserId);
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
            child: IconButton(
              onPressed: () => _sendMessage(conversationId, currentUserId),
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
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

  Future<void> _showRequestAppointment(BuildContext context, WidgetRef ref) async {
    if (widget.listing == null) return;
    
    final user = ref.read(currentUserProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Iniciá sesión para solicitar un turno')),
      );
      return;
    }

    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (date == null) return;

    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );

    if (time == null) return;

    final start = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final end = start.add(const Duration(hours: 1)); // Default 1 hour

    final appointment = Appointment(
      id: const Uuid().v4(),
      listingId: widget.listing!.id,
      customerId: user.id,
      professionalId: widget.listing!.authorId,
      scheduledAt: start,
      createdAt: DateTime.now(),
    );

    try {
      await ref.read(appointmentRepositoryProvider).createAppointment(appointment);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Turno solicitado con éxito'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al solicitar turno: $e')),
      );
    }
  }
}
