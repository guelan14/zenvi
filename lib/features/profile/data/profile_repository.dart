import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zenvi/shared/domain/models/profile.dart';

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

  Future<void> updateProfile(Profile profile) async {
    await _client
        .from('profiles')
        .update(profile.toJson())
        .eq('id', profile.id);
  }
}
