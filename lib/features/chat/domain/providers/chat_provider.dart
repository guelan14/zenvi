import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_config.dart';

// Placeholder for message model
class Message {
  final String id;
  final String content;
  final String senderId;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.content,
    required this.senderId,
    required this.createdAt,
  });

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'],
      content: map['content'],
      senderId: map['sender_id'],
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
      .order('created_at')
      .map((data) => data.map((json) => Message.fromMap(json)).toList());
});
