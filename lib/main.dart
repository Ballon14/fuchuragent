import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/providers/app_providers.dart';
import 'core/constants/app_constants.dart';
import 'features/notifications/services/local_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Indonesian locale formatting
  try {
    await initializeDateFormatting('id_ID', null);
  } catch (e) {
    debugPrint('Failed to initialize Indonesian date formatting: $e');
  }

  // Initialize Firebase with auto-generated platform options
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  // Initialize Local & Background Notifications for Android & Windows
  try {
    await LocalNotificationService().initialize();
  } catch (e) {
    debugPrint('Failed to initialize local notifications: $e');
  }

  // Initialize Persistent Preferences (Theme Mode, local settings)
  SharedPreferences? sharedPreferences;
  try {
    sharedPreferences = await SharedPreferences.getInstance();
  } catch (e) {
    debugPrint('Failed to initialize SharedPreferences: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        if (sharedPreferences != null)
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const FuchurAgentApp(),
    ),
  );
}

class FuchurAgentApp extends ConsumerWidget {
  const FuchurAgentApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
