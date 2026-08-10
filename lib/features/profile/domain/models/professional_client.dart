class ProfessionalClient {
  final String id;
  final String professionalId;
  final String? clientProfileId;
  final String fullName;
  final String? email;
  final String? phone;
  final String? notes;
  final DateTime createdAt;

  ProfessionalClient({
    required this.id,
    required this.professionalId,
    this.clientProfileId,
    required this.fullName,
    this.email,
    this.phone,
    this.notes,
    required this.createdAt,
  });

  factory ProfessionalClient.fromJson(Map<String, dynamic> json) {
    return ProfessionalClient(
      id: json['id'],
      professionalId: json['professional_id'],
      clientProfileId: json['client_profile_id'],
      fullName: json['full_name'],
      email: json['email'],
      phone: json['phone'],
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'professional_id': professionalId,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'notes': notes,
    };
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    if (clientProfileId != null) {
      map['client_profile_id'] = clientProfileId;
    }
    return map;
  }

  ProfessionalClient copyWith({
    String? id,
    String? professionalId,
    String? clientProfileId,
    String? fullName,
    String? email,
    String? phone,
    String? notes,
    DateTime? createdAt,
  }) {
    return ProfessionalClient(
      id: id ?? this.id,
      professionalId: professionalId ?? this.professionalId,
      clientProfileId: clientProfileId ?? this.clientProfileId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
