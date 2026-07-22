import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zenvi/features/home/domain/models/listing.dart';

class ListingRepository {
  final SupabaseClient _client;

  ListingRepository(this._client);

  Future<List<Listing>> getListings({
    ListingType? type,
    String? authorId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // Pedimos los listings y "unimos" con la tabla categories para traer el nombre
      dynamic query = _client.from('listings').select('*, categories(name)');

      if (type != null) {
        query = query.eq('type', type.name);
      }

      if (authorId != null) {
        query = query.eq('author_id', authorId);
      }

      query = query
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final response = await query;

      return (response as List).map((json) => Listing.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<Listing> createListing(Map<String, dynamic> data) async {
    final response = await _client.from('listings').insert(data).select().single();
    return Listing.fromJson(response);
  }

  Future<Listing> updateListing(String id, Map<String, dynamic> data) async {
    final response = await _client.from('listings').update(data).eq('id', id).select().single();
    return Listing.fromJson(response);
  }

  Future<Listing?> getListingById(String id) async {
    final response = await _client
        .from('listings')
        .select('*, categories(name)')
        .eq('id', id)
        .maybeSingle();
    if (response == null) return null;
    return Listing.fromJson(response);
  }
}
