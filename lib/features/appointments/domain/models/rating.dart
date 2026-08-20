class Rating {
  final String id;
  final String appointmentId;
  final String ratedId;
  final String raterId;
  final int rating;
  final String? comment;
  final List<String> images;
  final String moderationStatus;
  final DateTime createdAt;

  Rating({
    required this.id,
    required this.appointmentId,
    required this.ratedId,
    required this.raterId,
    required this.rating,
    this.comment,
    this.images = const [],
    this.moderationStatus = 'approved',
    required this.createdAt,
  });

  factory Rating.fromJson(Map<String, dynamic> json) {
    return Rating(
      id: json['id'],
      appointmentId: json['appointment_id'],
      ratedId: json['rated_id'],
      raterId: json['rater_id'],
      rating: json['rating'] as int,
      comment: json['comment'],
      images: List<String>.from(json['images'] ?? []),
      moderationStatus: json['moderation_status'] ?? 'approved',
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'appointment_id': appointmentId,
      'rated_id': ratedId,
      'rater_id': raterId,
      'rating': rating,
      'comment': comment,
      'images': images,
      'moderation_status': moderationStatus,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
