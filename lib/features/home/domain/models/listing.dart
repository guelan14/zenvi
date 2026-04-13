enum ListingType { service, job }

class Listing {
  final String id;
  final String title;
  final String description;
  final String authorName;
  final double price;
  final ListingType type;
  final String? imageUrl;
  final DateTime createdAt;

  Listing({
    required this.id,
    required this.title,
    required this.description,
    required this.authorName,
    required this.price,
    required this.type,
    this.imageUrl,
    required this.createdAt,
  });

  factory Listing.fromJson(Map<String, dynamic> json) {
    return Listing(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      authorName: json['author_name'],
      price: (json['price'] as num).toDouble(),
      type: json['type'] == 'service' ? ListingType.service : ListingType.job,
      imageUrl: json['image_url'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
