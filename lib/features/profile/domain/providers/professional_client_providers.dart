import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenvi/core/supabase/supabase_config.dart';
import 'package:zenvi/features/auth/domain/providers/auth_provider.dart';
import 'package:zenvi/features/profile/data/professional_client_repository.dart';
import 'package:zenvi/features/profile/domain/models/professional_client.dart';

final professionalClientRepositoryProvider = Provider<ProfessionalClientRepository>((ref) {
  return ProfessionalClientRepository(ref.watch(supabaseClientProvider));
});

final professionalClientsProvider = FutureProvider<List<ProfessionalClient>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final repository = ref.watch(professionalClientRepositoryProvider);
  return repository.getClientsForProfessional(user.id);
});

final professionalClientByIdProvider = FutureProvider.family<ProfessionalClient?, String>((ref, id) async {
  final repository = ref.watch(professionalClientRepositoryProvider);
  return repository.getClientById(id);
});
