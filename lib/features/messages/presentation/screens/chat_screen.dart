import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
import 'package:zenvi/shared/domain/models/availability.dart';

import 'package:shared_preferences/shared_preferences.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final Listing? listing;
  final String? otherUserId;
  const ChatScreen({super.key, this.listing, this.otherUserId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  bool _isBlocked = false;

  @override
  void initState() {
    super.initState();
    _loadBlockState();
  }

  Future<void> _loadBlockState() async {
    final targetId = widget.otherUserId ?? widget.listing?.authorId;
    if (targetId != null && targetId.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final blockedUsers = prefs.getStringList('blocked_users') ?? [];
      if (mounted) {
        setState(() {
          _isBlocked = blockedUsers.contains(targetId);
        });
      }
    }
  }

  Future<void> _toggleBlockChat(String targetId) async {
    final prefs = await SharedPreferences.getInstance();
    final blockedUsers = prefs.getStringList('blocked_users') ?? [];
    if (_isBlocked) {
      blockedUsers.remove(targetId);
    } else {
      blockedUsers.add(targetId);
    }
    await prefs.setStringList('blocked_users', blockedUsers);
    if (mounted) {
      setState(() {
        _isBlocked = !_isBlocked;
      });
    }
  }

  Future<void> _confirmDeleteChat(BuildContext context, WidgetRef ref, String conversationId) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E2E3D) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Eliminar Chat', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('¿Estás seguro de que quieres eliminar esta conversación? Se borrarán todos los mensajes de forma permanente.'),
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
        await ref.read(chatRepositoryProvider).deleteConversation(conversationId);
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Conversación eliminada con éxito'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar chat: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

    final initialListing = widget.listing;
    final hasRealListing = initialListing != null && initialListing.authorId.isNotEmpty;

    Listing? activeListing = hasRealListing ? initialListing : null;
    if (!hasRealListing && initialListing != null) {
      final listingAsync = ref.watch(listingByIdProvider(initialListing.id));
      activeListing = listingAsync.value;
    }

    final tempTargetUserId = activeListing?.authorId.isNotEmpty == true 
        ? activeListing!.authorId 
        : widget.otherUserId;

    final conversationAsync = ref.watch(currentConversationProvider(tempTargetUserId ?? ''));
    final conversation = conversationAsync.value;

    if (activeListing == null && conversation != null && conversation.serviceRequestId != null) {
      final listingAsync = ref.watch(listingByIdProvider(conversation.serviceRequestId!));
      activeListing = listingAsync.value;
    }

    final targetUserId = activeListing?.authorId.isNotEmpty == true 
        ? activeListing!.authorId 
        : widget.otherUserId;

    if (targetUserId == null || targetUserId.isEmpty) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      );
    }

    final profileAsync = ref.watch(profileProvider(targetUserId));
    final availabilityAsync = ref.watch(availabilityProvider(targetUserId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final userMode = ref.watch(userModeProvider);
    final isProvider = userMode == UserMode.professional ||
        (activeListing != null &&
            (activeListing.type == ListingType.service
                ? activeListing.authorId == currentUser?.id
                : activeListing.authorId != currentUser?.id));
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
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: isDark ? Colors.white : Colors.black),
            color: isDark ? const Color(0xFF1E222B) : Colors.white,
            onSelected: (value) async {
              if (value == 'block') {
                await _toggleBlockChat(targetUserId);
              } else if (value == 'delete' && conversation != null) {
                await _confirmDeleteChat(context, ref, conversation.id);
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem<String>(
                  value: 'block',
                  child: Row(
                    children: [
                      Icon(
                        _isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _isBlocked ? 'Desbloquear chat' : 'Bloquear chat',
                        style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                if (conversation != null)
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          color: isDark ? Colors.white70 : Colors.black87,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Eliminar chat',
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        ),
                      ],
                    ),
                  ),
              ];
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildAppointmentBanner(activeListing, isProvider, availabilityAsync.value),

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
          _buildInput(
            conversationAsync.value?.id,
            currentUser?.id,
            isProvider,
            activeListing,
            availabilityAsync.value,
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentBanner(Listing? listing, bool isProvider, List<Availability>? availability) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasNoFixedSchedule = !isProvider && availability != null && availability.isEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222B) : const Color(0xFFF9F9F9),
        border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF252A36) : const Color(0xFFF1F1F1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              hasNoFixedSchedule ? Icons.chat_bubble_outline_rounded : Icons.calendar_month_rounded, 
              size: 22, 
              color: isDark ? Colors.white : Colors.black87
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasNoFixedSchedule 
                      ? 'Coordiná tu turno por chat'
                      : (isProvider ? 'Proponer Turno / Presupuesto' : 'Solicitar un Turno'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasNoFixedSchedule
                      ? 'Este profesional atiende con horarios dinámicos. Acordá un momento aquí.'
                      : (isProvider 
                          ? 'Definí fecha, hora y precio para tu cliente.'
                          : 'Elegí el servicio y propone tu horario.'),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          if (!hasNoFixedSchedule)
            ElevatedButton(
              onPressed: () => _showRequestAppointment(context, ref, listing),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : Colors.black,
                foregroundColor: isDark ? Colors.black : Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                isProvider ? 'Proponer' : 'Solicitar',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
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

  Widget _buildInput(String? conversationId, String? currentUserId, bool isProvider, Listing? activeListing, List<Availability>? availability) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isBlocked) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E222B) : Colors.white,
          border: Border(top: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFEEEEEE))),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
          ),
          child: const Text(
            'Chat bloqueado. Desbloquéalo desde el menú superior para poder enviar mensajes.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar mensaje: $e')),
        );
      }
    }
  }

  Future<void> _showRequestAppointment(BuildContext context, WidgetRef ref, Listing? listing) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Iniciá sesión para solicitar un turno')),
      );
      return;
    }

    final userMode = ref.read(userModeProvider);
    final isProvider = userMode == UserMode.professional ||
        (listing != null &&
            (listing.type == ListingType.service
                ? listing.authorId == user.id
                : listing.authorId != user.id));

    final targetUserId = listing?.authorId.isNotEmpty == true 
        ? listing!.authorId 
        : widget.otherUserId;

    if (targetUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No se pudo determinar el contacto')),
      );
      return;
    }

    final professionalId = isProvider ? user.id : targetUserId;

    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    final notesController = TextEditingController();
    final priceController = TextEditingController(
      text: listing?.price != null ? listing!.price!.toStringAsFixed(0) : '',
    );

    String? selectedListingId = listing?.id;
    bool isLoadingListings = false;
    List<Listing> localListings = [];
    List<Appointment>? professionalAppointments;
    bool isLoadingAppointments = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: StatefulBuilder(
              builder: (context, setState) {
                final isDark = Theme.of(context).brightness == Brightness.dark;

                if (listing == null && localListings.isEmpty && !isLoadingListings) {
                  isLoadingListings = true;
                  Future.microtask(() async {
                    try {
                      final res = await ref.read(profileListingsProvider(professionalId).future);
                      setState(() {
                        localListings = res;
                        isLoadingListings = false;
                        if (localListings.isNotEmpty) {
                          selectedListingId = localListings.first.id;
                          if (localListings.first.price != null) {
                            priceController.text = localListings.first.price!.toStringAsFixed(0);
                          }
                        }
                      });
                    } catch (e) {
                      setState(() => isLoadingListings = false);
                    }
                  });
                }

                if (professionalAppointments == null && !isLoadingAppointments) {
                  isLoadingAppointments = true;
                  Future.microtask(() async {
                    try {
                      final apps = await ref.read(appointmentRepositoryProvider).getAppointmentsForUser(professionalId);
                      setState(() {
                        professionalAppointments = apps;
                        isLoadingAppointments = false;
                      });
                    } catch (_) {
                      setState(() => isLoadingAppointments = false);
                    }
                  });
                }

                final availableHeight = MediaQuery.of(context).size.height - MediaQuery.of(context).viewInsets.bottom;

                return AnimatedPadding(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                  duration: const Duration(milliseconds: 100),
                  curve: Curves.decelerate,
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: availableHeight * 0.85,
                    ),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E222B) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isProvider ? 'Proponer Turno' : 'Solicitar Turno',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                            color: isDark ? Colors.white70 : Colors.black54,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isProvider 
                            ? 'Establecé la fecha, hora y presupuesto para el cliente.'
                            : 'Establecé la fecha, hora y presupuesto para el profesional.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                  if (listing == null) ...[
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
                          isProvider
                              ? 'No tenés publicaciones activas creadas.'
                              : 'El profesional no tiene publicaciones activas.',
                          style: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 13),
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: selectedListingId,
                        dropdownColor: isDark ? const Color(0xFF1E222B) : Colors.white,
                        decoration: InputDecoration(
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
                        items: localListings.map((l) {
                          return DropdownMenuItem<String>(
                            value: l.id,
                            child: Text(
                              l.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            selectedListingId = val;
                            final selectedList = localListings.firstWhere((l) => l.id == val);
                            if (selectedList.price != null) {
                              priceController.text = selectedList.price!.toStringAsFixed(0);
                            }
                          });
                        },
                      ),
                    const SizedBox(height: 20),
                  ],

                  OutlinedButton.icon(
                    onPressed: () async {
                      final date = await _showCustomDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now().add(const Duration(days: 1)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (date != null) {
                        setState(() {
                          selectedDate = date;
                          selectedTime = null; // Reset time when date changes
                        });
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
                          : 'Fecha: ${DateFormat('dd/MM/yyyy').format(selectedDate!)}',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      side: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Selección de Horarios y Slots
                  if (selectedDate != null) ...[
                    _buildTimeSlotsSection(
                      professionalId: professionalId,
                      selectedDate: selectedDate!,
                      appointments: professionalAppointments ?? [],
                      isDark: isDark,
                      selectedTime: selectedTime,
                      onTimeSelected: (time) {
                        setState(() => selectedTime = time);
                      },
                    ),
                    const SizedBox(height: 20),
                  ],

                  Text(
                    isProvider ? 'Presupuesto propuesto (\$)' : 'Presupuesto acordado / ofrecido (\$)',
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
                  const SizedBox(height: 20),
                  
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
                      fillColor: isDark ? const Color(0xFF14171E) : const Color(0xFFF5F5F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: (selectedDate == null || selectedTime == null || selectedListingId == null)
                  ? null
                  : () async {
                      final start = DateTime(
                        selectedDate!.year,
                        selectedDate!.month,
                        selectedDate!.day,
                        selectedTime!.hour,
                        selectedTime!.minute,
                      );

                      final finalPrice = double.tryParse(priceController.text.trim()) ?? 0.0;

                      final appointment = Appointment(
                        id: const Uuid().v4(),
                        listingId: selectedListingId!,
                        customerId: isProvider ? targetUserId : user.id,
                        professionalId: professionalId,
                        scheduledAt: start,
                        price: finalPrice > 0 ? finalPrice : null,
                        status: AppointmentStatus.pending,
                        createdByProvider: isProvider,
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
                        final priceStr = finalPrice > 0 ? ' por \$${finalPrice.toStringAsFixed(0)}' : '';
                        
                        final messageContent = isProvider
                            ? '📅 Propuso un turno para el día $dateStr a las $timeStr hs$priceStr. (ID: ${appointment.id})'
                            : '📅 Solicitó un turno para el día $dateStr a las $timeStr hs$priceStr. (ID: ${appointment.id})';

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

                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isProvider
                                  ? 'Propuesta de turno enviada con éxito'
                                  : 'Turno solicitado con éxito'),
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
              child: Text(
                isProvider ? 'Enviar Propuesta' : 'Enviar Solicitud',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  },
),
),
);
},
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
          height: 460,
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
                    const SizedBox(width: 60),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: isDark
                        ? const ColorScheme.dark(
                            primary: Colors.blueAccent,
                            onPrimary: Colors.white,
                            surface: const Color(0xFF1E222B),
                            onSurface: Colors.white,
                          )
                        : const ColorScheme.light(
                            primary: Colors.black,
                            onPrimary: Colors.white,
                            surface: Colors.white,
                            onSurface: Colors.black87,
                          ),
                  ),
                  child: CalendarDatePicker(
                    initialDate: tempDate,
                    firstDate: firstDate,
                    lastDate: lastDate,
                    onDateChanged: (DateTime newDate) {
                      Navigator.of(context).pop(newDate);
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

  Widget _buildTimeSlotsSection({
    required String professionalId,
    required DateTime selectedDate,
    required List<Appointment> appointments,
    required bool isDark,
    required TimeOfDay? selectedTime,
    required ValueChanged<TimeOfDay?> onTimeSelected,
  }) {
    String targetProfileId = professionalId;
    if (professionalId.contains('|')) {
      final parts = professionalId.split('|');
      targetProfileId = parts[0].isNotEmpty ? parts[0] : '';
    }

    if (targetProfileId.isEmpty) return const SizedBox.shrink();

    final availabilityAsync = ref.watch(availabilityProvider(targetProfileId));

    return availabilityAsync.when(
      data: (slots) {
        Appointment? blockedEvent;
        for (var app in appointments) {
          if (app.scheduledAt.year == selectedDate.year &&
              app.scheduledAt.month == selectedDate.month &&
              app.scheduledAt.day == selectedDate.day &&
              app.notes != null &&
              app.notes!.startsWith('[BLOCKED_DAY]')) {
            blockedEvent = app;
            break;
          }
        }

        if (blockedEvent != null) {
          final reason = blockedEvent.notes!.replaceFirst('[BLOCKED_DAY]', '').trim();
          final displayReason = reason.isNotEmpty ? reason : 'Feriado / Día no laborable';
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C1E21) : const Color(0xFFFDE8E8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.block, color: Colors.redAccent, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Día no laborable / bloqueado por el profesional. Motivo: $displayReason',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.red[300] : Colors.red[900],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (slots.isEmpty) {
          return _buildManualTimePickerFallback(selectedTime, onTimeSelected, isDark);
        }

        final dayOfWeek = selectedDate.weekday % 7;
        final dailySlots = slots.where((s) => s.dayOfWeek == dayOfWeek).toList();

        if (dailySlots.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Seleccionar Hora',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              _buildNoAvailabilityWarning(selectedDate, isDark),
              const SizedBox(height: 8),
              _buildManualTimePickerFallback(selectedTime, onTimeSelected, isDark),
            ],
          );
        }

        final List<TimeOfDay> timeSlots = [];
        for (var slot in dailySlots) {
          timeSlots.addAll(_generateSlotsForAvailability(slot));
        }

        final seen = <String>{};
        final uniqueTimeSlots = timeSlots.where((slot) {
          final key = '${slot.hour}:${slot.minute}';
          return seen.add(key);
        }).toList();

        uniqueTimeSlots.sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Horarios Disponibles',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
                ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...uniqueTimeSlots.map((timeSlot) {
                  final isSelected = selectedTime == timeSlot;
                  
                  final slotDateTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, timeSlot.hour, timeSlot.minute);
                  final isOccupied = appointments.any((app) =>
                      app.status != AppointmentStatus.rejected &&
                      app.status != AppointmentStatus.cancelled &&
                      app.scheduledAt.difference(slotDateTime).inMinutes.abs() < 30);

                  Color bg;
                  Color text;
                  BorderSide? border;

                  if (isOccupied) {
                    bg = isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02);
                    text = isDark ? Colors.white24 : Colors.black26;
                    border = BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04));
                  } else if (isSelected) {
                    bg = isDark ? Colors.white : Colors.black;
                    text = isDark ? Colors.black : Colors.white;
                  } else {
                    bg = isDark ? const Color(0xFF14171E) : const Color(0xFFF5F5F5);
                    text = isDark ? Colors.white70 : Colors.black87;
                  }

                  return InkWell(
                    onTap: isOccupied
                        ? null
                        : () => onTimeSelected(timeSlot),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(12),
                        border: border != null ? Border.all(color: border.color) : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isOccupied) ...[
                            Icon(Icons.remove_circle_outline_rounded, size: 12, color: text),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            '${timeSlot.hour.toString().padLeft(2, '0')}:${timeSlot.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: text,
                              decoration: isOccupied ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ],
        );
      },
      loading: () => const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 16), child: CircularProgressIndicator())),
      error: (_, __) => _buildManualTimePickerFallback(selectedTime, onTimeSelected, isDark),
    );
  }

  List<TimeOfDay> _generateSlotsForAvailability(Availability slot) {
    final List<TimeOfDay> slots = [];
    final startMin = slot.startTime.hour * 60 + slot.startTime.minute;
    final endMin = slot.endTime.hour * 60 + slot.endTime.minute;
    
    const step = 30;
    for (int min = startMin; min < endMin; min += step) {
      slots.add(TimeOfDay(hour: min ~/ 60, minute: min % 60));
    }
    return slots;
  }

  Widget _buildNoAvailabilityWarning(DateTime selectedDate, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C1E21) : const Color(0xFFFDE8E8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'El profesional no configuró atención para los ${DateFormat('EEEE', 'es_ES').format(selectedDate)}s.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.red[300] : Colors.red[900],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualTimePickerFallback(TimeOfDay? selectedTime, ValueChanged<TimeOfDay?> onTimeSelected, bool isDark) {
    return Container(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          final time = await _showCustomTimePicker(
            context: context,
            initialTime: selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
          );
          if (time != null) {
            onTimeSelected(time);
          }
        },
        icon: Icon(
          Icons.access_time_rounded,
          size: 18,
          color: isDark ? Colors.white70 : Colors.black87,
        ),
        label: Text(
          selectedTime == null
              ? 'Seleccionar Hora Manualmente'
              : 'Hora seleccionada: ${selectedTime!.format(context)}',
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
    );
  }
}
