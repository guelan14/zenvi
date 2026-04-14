import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenvi/core/supabase/supabase_config.dart';

// Model for message
class Message {
  final String id;
  final String conversationId;
  final String content;
  final String senderId;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.conversationId,
    required this.content,
    required this.senderId,
    required this.createdAt,
  });

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'],
      conversationId: map['conversation_id'],
      content: map['content'],
      senderId: map['sender_id'] ?? '',
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}

final chatMessagesProvider = StreamProvider.family<List<Message>, String>((ref, conversationId) {
  final supabase = ref.watch(supabaseClientProvider);
  
  return supabase
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('conversation_id', conversationId)
      .order('created_at', ascending: true)
      .map((data) => data.map((json) => Message.fromMap(json)).toList());
});
