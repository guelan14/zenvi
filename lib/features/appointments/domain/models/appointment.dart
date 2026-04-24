enum AppointmentStatus { pending, accepted, rejected, completed, cancelled }

class Appointment {
  final String id;
  final String listingId;
  final String customerId;
  final String professionalId;
  final DateTime startTime;
  final DateTime endTime;
  final AppointmentStatus status;
  final DateTime createdAt;

  Appointment({
    required this.id,
    required this.listingId,
    required this.customerId,
    required this.professionalId,
    required this.startTime,
    required this.endTime,
    this.status = AppointmentStatus.pending,
    required this.createdAt,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'],
      listingId: json['listing_id'],
      customerId: json['customer_id'],
      professionalId: json['professional_id'],
      startTime: DateTime.parse(json['start_time']),
      endTime: DateTime.parse(json['end_time']),
      status: _parseStatus(json['status']),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'listing_id': listingId,
      'customer_id': customerId,
      'professional_id': professionalId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'status': status.name,
    };
  }

  static AppointmentStatus _parseStatus(String? status) {
    switch (status) {
      case 'accepted': return AppointmentStatus.accepted;
      case 'rejected': return AppointmentStatus.rejected;
      case 'completed': return AppointmentStatus.completed;
      case 'cancelled': return AppointmentStatus.cancelled;
      default: return AppointmentStatus.pending;
    }
  }
}
