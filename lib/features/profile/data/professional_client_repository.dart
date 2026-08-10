import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zenvi/features/profile/domain/models/professional_client.dart';

class ProfessionalClientRepository {
  final SupabaseClient _client;

  ProfessionalClientRepository(this._client);

  Future<List<ProfessionalClient>> getClientsForProfessional(String professionalId) async {
    final response = await _client
        .from('professional_clients')
        .select()
        .eq('professional_id', professionalId)
        .order('full_name', ascending: true);

    return (response as List)
        .map((json) => ProfessionalClient.fromJson(json))
        .toList();
  }

  Future<ProfessionalClient> createClient(ProfessionalClient client) async {
    final response = await _client
        .from('professional_clients')
        .insert(client.toJson())
        .select()
        .single();
    
    return ProfessionalClient.fromJson(response);
  }

  Future<void> updateClient(ProfessionalClient client) async {
    await _client
        .from('professional_clients')
        .update(client.toJson())
        .eq('id', client.id);
  }

  Future<void> deleteClient(String id) async {
    await _client
        .from('professional_clients')
        .delete()
        .eq('id', id);
  }

  Future<ProfessionalClient?> getClientById(String id) async {
    final response = await _client
        .from('professional_clients')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return ProfessionalClient.fromJson(response);
  }

  /// Registers the custom client email in auth.users by calling our custom Postgres RPC function,
  /// and automatically triggers the handle_new_user link trigger.
  Future<String?> inviteClient(String email, String fullName) async {
    try {
      final String? invitedUserId = await _client.rpc(
        'create_invited_user_in_auth',
        params: {
          'client_email': email,
          'client_name': fullName,
        },
      );
      return invitedUserId;
    } catch (e) {
      // Re-throw or return null
      return null;
    }
  }
}
