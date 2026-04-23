import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zenvi/features/home/domain/models/listing.dart';

class ListingRepository {
  final SupabaseClient _client;

  ListingRepository(this._client);

  Future<List<Listing>> getListings({
    ListingType? type,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // Pedimos los listings y "unimos" con la tabla categories para traer el nombre
      dynamic query = _client.from('listings').select('*, categories(name)');

      if (type != null) {
        query = query.eq('type', type.name);
      }

      query = query
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final response = await query;
      print('DEBUG: Consulta completada. Registros encontrados: ${(response as List).length}');
      
      return (response as List).map((json) => Listing.fromJson(json)).toList();
    } catch (e) {
      print('DEBUG: Error en getListings: $e');
      rethrow;
    }
  }

  Future<void> createListing(Map<String, dynamic> data) async {
    await _client.from('listings').insert(data);
  }
}
