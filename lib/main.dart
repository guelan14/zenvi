import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:zenvi/features/profile/domain/providers/profile_providers.dart';
import 'core/theme/zervi_theme.dart';
import 'core/router/app_router.dart';
import 'core/supabase/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Initialize Supabase (Catch errors if URL/Key not set)
  try {
    await SupabaseConfig.initialize();
  } catch (e) {
    debugPrint('Supabase initialization failed: $e');
  }

  runApp(
    const ProviderScope(
      child: ZerviApp(),
    ),
  );
}

class ZerviApp extends ConsumerWidget {
  const ZerviApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Zervi',
      theme: ZerviTheme.lightTheme,
      darkTheme: ZerviTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
