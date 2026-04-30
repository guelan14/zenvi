class Conversation {
  final String id;
  final String? serviceRequestId;
  final String initiatorId;
  final String recipientId;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;

  Conversation({
    required this.id,
    this.serviceRequestId,
    required this.initiatorId,
    required this.recipientId,
    this.lastMessageAt,
    this.createdAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'],
      serviceRequestId: json['service_request_id'],
      initiatorId: json['initiator_id'],
      recipientId: json['recipient_id'],
      lastMessageAt: json['last_message_at'] != null ? DateTime.parse(json['last_message_at']) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }
}
