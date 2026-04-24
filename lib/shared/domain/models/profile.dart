class Profile {
  final String id;
  final String? fullName;
  final String? avatarUrl;
  final String? bio;
  final String location;
  final String? phone;
  final double ratingAvg;
  final int reviewCount;
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
      'accepts_emergencies': acceptsEmergencies,
    };
  }
}
