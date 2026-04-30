class ChatMessage {
  final String id;
  final String conversationId;
  final String? senderId;
  final String content;
  final DateTime? createdAt;

  ChatMessage({
    required this.id,
    required this.conversationId,
    this.senderId,
    required this.content,
    this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      conversationId: json['conversation_id'],
      senderId: json['sender_id'],
      content: json['content'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }
}
