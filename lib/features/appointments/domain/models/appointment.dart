enum AppointmentStatus { pending, proposed, accepted, rejected, completed, cancelled }

class Appointment {
  final String id;
  final String listingId;
  final String customerId;
  final String professionalId;
  final DateTime scheduledAt;
  final String? notes;
  final AppointmentStatus status;
  final double? price;
  final bool? createdByProvider;
  final DateTime createdAt;

  Appointment({
    required this.id,
    required this.listingId,
    required this.customerId,
    required this.professionalId,
    required this.scheduledAt,
    this.notes,
    this.status = AppointmentStatus.pending,
    this.price,
    this.createdByProvider = false,
    required this.createdAt,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'],
      listingId: json['listing_id'],
      customerId: json['client_id'],
      professionalId: json['provider_id'],
      scheduledAt: DateTime.parse(json['scheduled_at']),
      notes: json['notes'],
      status: _parseStatus(json['status']),
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
      createdByProvider: json['created_by_provider'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'listing_id': listingId,
      'client_id': customerId,
      'provider_id': professionalId,
      'scheduled_at': scheduledAt.toIso8601String(),
      'notes': notes,
      'status': status.name,
      'price': price,
      'created_by_provider': createdByProvider,
    };
  }

  static AppointmentStatus _parseStatus(String? status) {
    switch (status) {
      case 'proposed': return AppointmentStatus.proposed;
      case 'accepted': return AppointmentStatus.accepted;
      case 'rejected': return AppointmentStatus.rejected;
      case 'completed': return AppointmentStatus.completed;
      case 'cancelled': return AppointmentStatus.cancelled;
      default: return AppointmentStatus.pending;
    }
  }
}
