import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zenvi/shared/domain/models/profile.dart';
import 'package:zenvi/shared/domain/models/availability.dart';

class ProfileRepository {
  final SupabaseClient _client;

  ProfileRepository(this._client);

  Future<Profile?> getProfile(String id) async {
    try {
      print('DEBUG: Obteniendo perfil para ID: $id...');
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', id)
          .maybeSingle();
      
      if (response == null) {
        print('DEBUG: Perfil no encontrado (null).');
        return null;
      }
      
      print('DEBUG: Perfil obtenido con éxito.');
      return Profile.fromJson(response);
    } catch (e) {
      print('DEBUG: Error en getProfile: $e');
      rethrow;
    }
  }

  Future<List<Availability>> getAvailability({String? profileId, String? listingId}) async {
    try {
      var query = _client.from('availability').select();
      
      if (listingId != null) {
        query = query.eq('listing_id', listingId);
      } else if (profileId != null) {
        query = query.eq('profile_id', profileId);
      }
      
      final response = await query.order('day_of_week', ascending: true);
      
      return (response as List).map((json) => Availability.fromJson(json)).toList();
    } catch (e) {
      print('DEBUG: Error en getAvailability: $e');
      return [];
    }
  }

  Future<void> updateProfile(Profile profile) async {
    await _client
        .from('profiles')
        .update(profile.toJson())
        .eq('id', profile.id);
  }

  Future<void> updateAvailability({
    required String profileId, 
    String? listingId,
    required List<Map<String, dynamic>> availabilityData,
  }) async {
    try {
      // Borrar disponibilidad actual (si es de listing, borramos esa, sino la del perfil)
      var deleteQuery = _client.from('availability').delete();
      if (listingId != null) {
        deleteQuery = deleteQuery.eq('listing_id', listingId);
      } else {
        deleteQuery = deleteQuery.eq('profile_id', profileId);
      }
      await deleteQuery;
      
      // Insertar nueva si hay datos
      if (availabilityData.isNotEmpty) {
        await _client.from('availability').insert(
          availabilityData.map((data) => {
            ...data,
            'profile_id': profileId,
            'listing_id': listingId,
          }).toList(),
        );
      }
    } catch (e) {
      print('DEBUG: Error en updateAvailability: $e');
      rethrow;
    }
  }
}

