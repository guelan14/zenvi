import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zenvi/features/messages/data/chat_repository.dart';
import 'package:zenvi/features/messages/domain/models/conversation.dart';
import 'package:zenvi/features/messages/domain/models/message.dart';
import 'package:zenvi/features/auth/domain/providers/auth_provider.dart';

final chatRepositoryProvider = Provider((ref) {
  return ChatRepository(Supabase.instance.client);
});

final currentConversationProvider = FutureProvider.family<Conversation?, String>((ref, otherUserId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  
  return ref.read(chatRepositoryProvider).getOrCreateConversation(user.id, otherUserId);
});

final messagesStreamProvider = StreamProvider.family<List<ChatMessage>, String>((ref, conversationId) {
  return ref.watch(chatRepositoryProvider).watchMessages(conversationId);
});

final userConversationsStreamProvider = StreamProvider<List<Conversation>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(chatRepositoryProvider).watchUserConversations(user.id);
});
