import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zenvi/core/supabase/supabase_config.dart';
import 'package:zenvi/features/home/data/listing_repository.dart';
import 'package:zenvi/features/home/domain/models/listing.dart';

final listingRepositoryProvider = Provider<ListingRepository>((ref) {
  return ListingRepository(ref.watch(supabaseClientProvider));
});

final listingsProvider = FutureProvider.family<List<Listing>, ListingType?>((ref, type) async {
  return ref.watch(listingRepositoryProvider).getListings(type: type);
});

final categoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final client = ref.watch(supabaseClientProvider);
    final response = await client.from('categories').select().order('name', ascending: true);
    return (response as List).map((json) => json as Map<String, dynamic>).toList();
  } catch (e) {
    print('DEBUG: Error cargando categorías de la DB: $e');
    // Fallback por si la base de datos no tiene categorías
    return [
      {'name': 'Limpieza y Mantenimiento', 'icon_name': 'cleaning_services'},
      {'name': 'Reformas y Construcción', 'icon_name': 'construction'},
      {'name': 'Técnica y Reparaciones', 'icon_name': 'build'},
      {'name': 'Fletes y Mudanzas', 'icon_name': 'local_shipping'},
      {'name': 'Otros', 'icon_name': 'more_horiz'},
    ];
  }
});

final listingByIdProvider = FutureProvider.family<Listing?, String>((ref, id) async {
  return ref.watch(listingRepositoryProvider).getListingById(id);
});
