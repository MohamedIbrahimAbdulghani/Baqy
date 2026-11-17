import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/app_colors.dart';
import 'core/routing/app_router.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[ENV] Warning: Failed to load .env file: $e');
    }
  }

  // Initialize local notifications service (permissions requested on first reminder)
  try {
    await NotificationService.instance.initialize();
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[NOTIFICATION] Failed to initialize NotificationService: $e');
    }
  }

  // Pre-load saved theme synchronously so initial build has zero delay/flicker
  try {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('app_theme_mode');
    AppColors.isDark = (savedTheme == 'dark');
  } catch (_) {}

  runApp(
    const ProviderScope(
      child: BaqyApp(),
    ),
  );
}

class BaqyApp extends ConsumerWidget {
  const BaqyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'BAQY',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: appRouter,
    );
  }
}
