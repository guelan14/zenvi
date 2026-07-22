import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenvi/core/supabase/supabase_config.dart';
import 'package:zenvi/features/appointments/data/appointment_repository.dart';
import 'package:zenvi/features/appointments/domain/models/appointment.dart';
import 'package:zenvi/features/auth/domain/providers/auth_provider.dart';

final appointmentRepositoryProvider = Provider<AppointmentRepository>((ref) {
  return AppointmentRepository(ref.watch(supabaseClientProvider));
});

final userAppointmentsProvider = FutureProvider<List<Appointment>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  
  final repository = ref.watch(appointmentRepositoryProvider);
  return repository.getAppointmentsForUser(user.id);
});

final appointmentByIdProvider = FutureProvider.family<Appointment?, String>((ref, id) async {
  final repository = ref.watch(appointmentRepositoryProvider);
  return repository.getAppointmentById(id);
});
