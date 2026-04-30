import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zenvi/features/messages/domain/models/conversation.dart';
import 'package:zenvi/features/messages/domain/models/message.dart';

class ChatRepository {
  final SupabaseClient _client;

  ChatRepository(this._client);

  Future<Conversation> getOrCreateConversation(String currentUserId, String otherUserId) async {
    // Check if conversation exists
    final response = await _client
        .from('conversations')
        .select()
        .or('and(initiator_id.eq.$currentUserId,recipient_id.eq.$otherUserId),and(initiator_id.eq.$otherUserId,recipient_id.eq.$currentUserId)')
        .limit(1)
        .maybeSingle();

    if (response != null) {
      return Conversation.fromJson(response);
    }

    // Create new conversation
    final newConv = await _client.from('conversations').insert({
      'initiator_id': currentUserId,
      'recipient_id': otherUserId,
    }).select().single();

    return Conversation.fromJson(newConv);
  }

  Stream<List<Conversation>> watchUserConversations(String userId) async* {
    while (true) {
      try {
        final response = await _client
            .from('conversations')
            .select()
            .or('initiator_id.eq.$userId,recipient_id.eq.$userId')
            .order('last_message_at', ascending: false);
        yield (response as List).map((json) => Conversation.fromJson(json)).toList();
      } catch (e) {
        // Ignore errors in polling to avoid breaking the stream
      }
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  Stream<List<ChatMessage>> watchMessages(String conversationId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .map((list) => list.map((json) => ChatMessage.fromJson(json)).toList());
  }

  Future<void> sendMessage(String conversationId, String senderId, String content) async {
    await _client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content.trim(),
    });

    // Update last_message_at
    await _client.from('conversations').update({
      'last_message_at': DateTime.now().toIso8601String(),
    }).eq('id', conversationId);
  }
}
