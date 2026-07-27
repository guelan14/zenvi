class Profile {
  final String id;
  final String? fullName;
  final String? avatarUrl;
  final String? bio;
  final String location;
  final String? phone;
  final double ratingAvg;
  final int reviewCount;
  final double ratingAvgPro;
  final int reviewCountPro;
  final double ratingAvgClient;
  final int reviewCountClient;
  final bool acceptsEmergencies;
  final DateTime createdAt;

  Profile({
    required this.id,
    this.fullName,
    this.avatarUrl,
    this.bio,
    this.location = 'Posadas, Misiones',
    this.phone,
    this.ratingAvg = 0,
    this.reviewCount = 0,
    this.ratingAvgPro = 0,
    this.reviewCountPro = 0,
    this.ratingAvgClient = 0,
    this.reviewCountClient = 0,
    this.acceptsEmergencies = false,
    required this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'],
      fullName: json['full_name'],
      avatarUrl: json['avatar_url'],
      bio: json['bio'],
      location: json['location'] ?? 'Posadas, Misiones',
      phone: json['phone'],
      ratingAvg: (json['rating_avg'] as num? ?? 0).toDouble(),
      reviewCount: json['review_count'] ?? 0,
      ratingAvgPro: (json['rating_avg_pro'] as num? ?? 0).toDouble(),
      reviewCountPro: json['review_count_pro'] ?? 0,
      ratingAvgClient: (json['rating_avg_client'] as num? ?? 0).toDouble(),
      reviewCountClient: json['review_count_client'] ?? 0,
      acceptsEmergencies: json['accepts_emergencies'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'bio': bio,
      'location': location,
      'phone': phone,
      'rating_avg_pro': ratingAvgPro,
      'review_count_pro': reviewCountPro,
      'rating_avg_client': ratingAvgClient,
      'review_count_client': reviewCountClient,
      'accepts_emergencies': acceptsEmergencies,
    };
  }
}
