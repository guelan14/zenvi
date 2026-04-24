import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenvi/core/supabase/supabase_config.dart';
import 'package:zenvi/features/auth/domain/providers/auth_provider.dart';
import 'package:zenvi/features/profile/data/profile_repository.dart';
import 'package:zenvi/shared/domain/models/profile.dart';
import 'package:zenvi/features/home/domain/models/listing.dart';
import 'package:zenvi/features/home/domain/providers/home_providers.dart';
import 'package:zenvi/shared/domain/models/availability.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});

final profileProvider = FutureProvider.family<Profile?, String>((ref, id) async {
  final realId = id == 'me' ? ref.watch(currentUserProvider)?.id : id;
  if (realId == null) return null;
  return ref.watch(profileRepositoryProvider).getProfile(realId);
});

/// Provider genérico para obtener disponibilidad, ya sea por ID de perfil o de servicio.
final availabilityProvider = FutureProvider.family<List<Availability>, String>((ref, id) async {
  // Si el ID tiene formato de UUID de listing, buscamos por listing. 
  // Si es 'me' o un perfil, buscamos por perfil.
  // Por simplicidad, el repositorio ya maneja la lógica si le pasamos listingId o profileId.
  
  // Si es 'me', resolvemos el ID del usuario actual
  final targetId = id == 'me' ? ref.watch(currentUserProvider)?.id : id;
  if (targetId == null) return [];

  // Primero intentamos buscar por listingId (porque ahora la disponibilidad es por servicio)
  final resultsByListing = await ref.watch(profileRepositoryProvider).getAvailability(listingId: targetId);
  if (resultsByListing.isNotEmpty) return resultsByListing;

  // Si no hay nada por listing, buscamos por perfil (compatibilidad hacia atrás)
  return ref.watch(profileRepositoryProvider).getAvailability(profileId: targetId);
});

final profileListingsProvider = FutureProvider.family<List<Listing>, String>((ref, id) async {
  final realId = id == 'me' ? ref.watch(currentUserProvider)?.id : id;
  if (realId == null) return [];
  return ref.watch(listingRepositoryProvider).getListings(authorId: realId);
});
