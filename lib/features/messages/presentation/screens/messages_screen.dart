import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zenvi/features/messages/domain/providers/chat_providers.dart';
import 'package:zenvi/features/auth/domain/providers/auth_provider.dart';
import 'package:zenvi/features/profile/domain/providers/profile_providers.dart';
import 'package:zenvi/features/messages/domain/models/conversation.dart';
import 'package:zenvi/shared/widgets/role_switch_button.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Mensajes',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
      ),
      body: conversationsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (conversations) {
          if (conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 64,
                    color: isDark ? Colors.white30 : Colors.black26,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No tenés mensajes aún',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cuando contactes a alguien\naparecerá acá.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
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

        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          margin: const EdgeInsets.only(bottom: 1),
          color: Theme.of(context).cardColor,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            onTap: () {
              context.push('/chat_user/$otherUserId');
            },
            leading: CircleAvatar(
              radius: 26,
              backgroundColor: isDark ? Colors.white10 : Colors.black12,
              backgroundImage: profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
              child: profile.avatarUrl == null
                  ? Text(
                      (profile.fullName ?? 'U')[0].toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    )
                  : null,
            ),
            title: Text(
              profile.fullName ?? 'Usuario',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Text(
              conversation.lastMessageAt != null ? 'Toca para ver los mensajes' : 'Conversación iniciada',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            trailing: Text(
              formattedDate,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white30 : Colors.black38,
              ),
            ),
          ),
        );
      },
    );
  }
}
