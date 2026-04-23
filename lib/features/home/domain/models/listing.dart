enum ListingType { service, job }
enum WorkMode { virtual, presencial, hybrid }
enum ListingStatus { active, completed, cancelled }

class Listing {
  final String id;
  final String authorId;
  final String? categoryId;
  final String? category;
  final ListingType type;
  final WorkMode workMode;
  final String title;
  final String description;
  final double? price;
  final List<String> images;
  final String? location;
  final ListingStatus status;
  final double? lat;
  final double? lng;
  final DateTime createdAt;

  Listing({
    required this.id,
    required this.authorId,
    this.categoryId,
    this.category,
    required this.type,
    this.workMode = WorkMode.presencial,
    required this.title,
    required this.description,
    this.price,
    this.images = const [],
    this.location,
    this.lat,
    this.lng,
    this.status = ListingStatus.active,
    required this.createdAt,
  });

  factory Listing.fromJson(Map<String, dynamic> json) {
    return Listing(
      id: json['id'],
      authorId: json['author_id'],
      categoryId: json['category_id'],
      category: json['categories'] != null ? json['categories']['name'] : json['category'],
      title: json['title'],
      description: json['description'] ?? '',
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
      type: _parseListingType(json['type']),
      workMode: _parseWorkMode(json['work_mode']),
      images: List<String>.from(json['images'] ?? []),
      location: json['location'],
      lat: json['lat'] != null ? (json['lat'] as num).toDouble() : null,
      lng: json['lng'] != null ? (json['lng'] as num).toDouble() : null,
      status: _parseStatus(json['status']),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  static ListingType _parseListingType(String type) {
    return type == 'job' ? ListingType.job : ListingType.service;
  }

  static WorkMode _parseWorkMode(String? mode) {
    switch (mode) {
      case 'virtual': return WorkMode.virtual;
      case 'hybrid': return WorkMode.hybrid;
      default: return WorkMode.presencial;
    }
  }

  static ListingStatus _parseStatus(String? status) {
    switch (status) {
      case 'completed': return ListingStatus.completed;
      case 'cancelled': return ListingStatus.cancelled;
      default: return ListingStatus.active;
    }
  }
}
