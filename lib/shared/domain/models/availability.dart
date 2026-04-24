import 'package:flutter/material.dart';

class Availability {
  final String id;
  final String profileId;
  final String? listingId;
  final int dayOfWeek; // 0-6 (Sunday-Saturday)
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  Availability({
    required this.id,
    required this.profileId,
    this.listingId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });

  factory Availability.fromJson(Map<String, dynamic> json) {
    return Availability(
      id: json['id'],
      profileId: json['profile_id'],
      listingId: json['listing_id'],
      dayOfWeek: json['day_of_week'],
      startTime: _parseTime(json['start_time']),
      endTime: _parseTime(json['end_time']),
    );
  }

  static TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  static String formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
