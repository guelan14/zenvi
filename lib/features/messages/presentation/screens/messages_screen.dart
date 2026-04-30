import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zenvi/features/messages/domain/providers/chat_providers.dart';
import 'package:zenvi/features/auth/domain/providers/auth_provider.dart';
import 'package:zenvi/features/profile/domain/providers/profile_providers.dart';
import 'package:zenvi/features/messages/domain/models/conversation.dart';
import 'package:intl/intl.dart';

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mensajes')),
        body: const Center(child: Text('Iniciá sesión para ver tus mensajes')),
      );
    }

    final conversationsAsync = ref.watch(userConversationsStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text('Mensajes', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: conversationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.black)),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (conversations) {
          if (conversations.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline_rounded, size: 64, color: Colors.black26),
                  SizedBox(height: 16),
                  Text(
                    'No tenés mensajes aún',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Cuando contactes a alguien\naparecerá acá.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black45),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final conv = conversations[index];
              return _ConversationTile(conversation: conv, currentUserId: user.id);
            },
          );
        },
      ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  final Conversation conversation;
  final String currentUserId;

  const _ConversationTile({required this.conversation, required this.currentUserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final otherUserId = conversation.initiatorId == currentUserId ? conversation.recipientId : conversation.initiatorId;
    final otherProfileAsync = ref.watch(profileProvider(otherUserId));

    return otherProfileAsync.when(
      loading: () => const ListTile(title: Text('Cargando...')),
      error: (_, __) => const ListTile(title: Text('Error al cargar perfil')),
      data: (profile) {
        if (profile == null) return const SizedBox.shrink();

        String formattedDate = '';
        if (conversation.lastMessageAt != null) {
          final now = DateTime.now();
          final diff = now.difference(conversation.lastMessageAt!);
          if (diff.inDays == 0 && now.day == conversation.lastMessageAt!.day) {
            formattedDate = DateFormat('HH:mm').format(conversation.lastMessageAt!);
          } else {
            formattedDate = DateFormat('dd/MM/yyyy').format(conversation.lastMessageAt!);
          }
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 1),
          color: Colors.white,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            onTap: () {
              // We need to navigate to ChatScreen. However, ChatScreen currently requires a Listing object!
              // For now, since ChatScreen requires a Listing, we might have an issue.
              // Wait, the user accesses chat through listing. So we can't easily jump to ChatScreen without a listing.
              // Let's create a simplified route or pass a dummy listing, or refactor ChatScreen to accept `String otherUserId` instead of Listing!
              context.push('/chat_user/$otherUserId');
            },
            leading: CircleAvatar(
              radius: 26,
              backgroundColor: Colors.black12,
              backgroundImage: profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
              child: profile.avatarUrl == null
                  ? Text((profile.fullName ?? 'U')[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87))
                  : null,
            ),
            title: Text(
              profile.fullName ?? 'Usuario',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            subtitle: Text(
              conversation.lastMessageAt != null ? 'Toca para ver los mensajes' : 'Conversación iniciada',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black54),
            ),
            trailing: Text(
              formattedDate,
              style: const TextStyle(fontSize: 12, color: Colors.black38),
            ),
          ),
        );
      },
    );
  }
}

