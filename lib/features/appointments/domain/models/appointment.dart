enum AppointmentStatus { pending, proposed, accepted, rejected, completed, cancelled }

class Appointment {
  final String id;
  final String listingId;
  final String? customerId;
  final String? customClientId;
  final String professionalId;
  final DateTime scheduledAt;
  final String? notes;
  final AppointmentStatus status;
  final double? price;
  final bool? createdByProvider;
  final bool clientConfirmedCompletion;
  final bool providerConfirmedCompletion;
  final DateTime createdAt;

  Appointment({
    required this.id,
    required this.listingId,
    this.customerId,
    this.customClientId,
    required this.professionalId,
    required this.scheduledAt,
    this.notes,
    this.status = AppointmentStatus.pending,
    this.price,
    this.createdByProvider = false,
    this.clientConfirmedCompletion = false,
    this.providerConfirmedCompletion = false,
    required this.createdAt,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    double? parsedPrice = json['price'] != null ? (json['price'] as num).toDouble() : null;
    String? parsedNotes = json['notes'];

    if (parsedPrice == null && parsedNotes != null && parsedNotes.startsWith('[PRICE:')) {
      final endIndex = parsedNotes.indexOf(']');
      if (endIndex != -1) {
        final priceStr = parsedNotes.substring(7, endIndex);
        parsedPrice = double.tryParse(priceStr);
        parsedNotes = parsedNotes.substring(endIndex + 1);
        if (parsedNotes.isEmpty) {
          parsedNotes = null;
        }
      }
    }

    return Appointment(
      id: json['id'],
      listingId: json['listing_id'] ?? '',
      customerId: json['client_id'],
      customClientId: json['custom_client_id'],
      professionalId: json['provider_id'] ?? '',
      scheduledAt: DateTime.parse(json['scheduled_at']),
      notes: parsedNotes,
      status: _parseStatus(json['status']),
      price: parsedPrice,
      createdByProvider: json['created_by_provider'] ?? false,
      clientConfirmedCompletion: json['client_confirmed_completion'] ?? false,
      providerConfirmedCompletion: json['provider_confirmed_completion'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    String? serializedNotes = notes;
    if (price != null && price! > 0) {
      serializedNotes = '[PRICE:${price!.toStringAsFixed(0)}]${notes ?? ''}';
    }

    final Map<String, dynamic> data = {
      'id': id,
      'listing_id': listingId,
      'provider_id': professionalId,
      'scheduled_at': scheduledAt.toIso8601String(),
      'notes': serializedNotes,
      'status': status.name,
      'created_by_provider': createdByProvider,
      'client_confirmed_completion': clientConfirmedCompletion,
      'provider_confirmed_completion': providerConfirmedCompletion,
    };
    if (customerId != null) {
      data['client_id'] = customerId;
    }
    if (customClientId != null) {
      data['custom_client_id'] = customClientId;
    }
    return data;
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
