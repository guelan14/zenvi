import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zenvi/features/appointments/domain/models/appointment.dart';

class AppointmentRepository {
  final SupabaseClient _client;

  AppointmentRepository(this._client);

  Future<void> createAppointment(Appointment appointment) async {
    await _client.from('appointments').insert(appointment.toJson());
  }

  Future<List<Appointment>> getAppointmentsForUser(String userId) async {
    final response = await _client
        .from('appointments')
        .select()
        .or('customer_id.eq.$userId,professional_id.eq.$userId')
        .order('start_time', ascending: true);
    
    return (response as List).map((json) => Appointment.fromJson(json)).toList();
  }
}
