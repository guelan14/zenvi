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
        .or('client_id.eq.$userId,provider_id.eq.$userId')
        .order('scheduled_at', ascending: true);
    
    return (response as List).map((json) => Appointment.fromJson(json)).toList();
  }

  Future<void> updateAppointmentStatus(String appointmentId, AppointmentStatus status) async {
    await _client
        .from('appointments')
        .update({'status': status.name})
        .eq('id', appointmentId);
  }

  Future<void> deleteAppointment(String appointmentId) async {
    await _client
        .from('appointments')
        .delete()
        .eq('id', appointmentId);
  }

  Future<Appointment?> getAppointmentById(String id) async {
    final response = await _client
        .from('appointments')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (response == null) return null;
    return Appointment.fromJson(response);
  }

  Future<void> confirmAppointmentCompletion(String id, {required bool isProfessional}) async {
    final appointment = await getAppointmentById(id);
    if (appointment == null) throw Exception('Appointment not found');

    final bool isClientCompleted = isProfessional ? appointment.clientConfirmedCompletion : true;
    final bool isProviderCompleted = isProfessional ? true : appointment.providerConfirmedCompletion;

    final Map<String, dynamic> updates = {
      if (isProfessional) 'provider_confirmed_completion': true,
      if (!isProfessional) 'client_confirmed_completion': true,
    };

    if (isClientCompleted && isProviderCompleted) {
      updates['status'] = AppointmentStatus.completed.name;
    }

    await _client
        .from('appointments')
        .update(updates)
        .eq('id', id);
  }
}
