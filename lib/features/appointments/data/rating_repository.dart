import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zenvi/features/appointments/domain/models/rating.dart';

class RatingRepository {
  final SupabaseClient _client;

  RatingRepository(this._client);

  Future<void> submitRating(Rating rating) async {
    await _client.from('user_ratings').insert(rating.toJson());
  }

  Future<List<Rating>> getRatingsForUser(String userId) async {
    final response = await _client
        .from('user_ratings')
        .select()
        .eq('rated_id', userId)
        .eq('moderation_status', 'approved')
        .order('created_at', ascending: false);

    return (response as List).map((json) => Rating.fromJson(json)).toList();
  }

  Future<Rating?> getRatingForAppointmentAndRater(String appointmentId, String raterId) async {
    final response = await _client
        .from('user_ratings')
        .select()
        .eq('appointment_id', appointmentId)
        .eq('rater_id', raterId)
        .maybeSingle();

    if (response == null) return null;
    return Rating.fromJson(response);
  }
}
