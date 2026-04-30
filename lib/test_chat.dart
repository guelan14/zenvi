import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';

Future<void> main() async {
  await dotenv.load(fileName: ".env");

  final supabase = SupabaseClient(
    dotenv.env['SUPABASE_URL']!,
    dotenv.env['SUPABASE_ANON_KEY']!,
  );

  print('Testing chat conversation query...');
  
  // Create a fake UUID for testing
  final u1 = '11111111-1111-1111-1111-111111111111';
  final u2 = '22222222-2222-2222-2222-222222222222';

  try {
    final response = await supabase
        .from('conversations')
        .select()
        .or('and(initiator_id.eq.$u1,recipient_id.eq.$u2),and(initiator_id.eq.$u2,recipient_id.eq.$u1)')
        .limit(1)
        .maybeSingle();
    print('Query success! Response: $response');
  } catch (e) {
    print('Query failed! Error: $e');
  }
  
  exit(0);
}
