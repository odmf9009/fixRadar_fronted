import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'core/config/routes.dart';
import 'core/services/api_service.dart';
import 'core/services/language_service.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/localization/app_translations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  ApiService().init();
  await NotificationService().init();
  runApp(const FixRadarApp());
}

class FixRadarApp extends StatelessWidget {
  const FixRadarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LanguageService(),
      child: const _AppContent(),
    );
  }
}

class _AppContent extends StatelessWidget {
  const _AppContent();

  @override
  Widget build(BuildContext context) {
    final languageService = context.watch<LanguageService>();
    AppTranslations.setLocale(languageService.locale);

    return MaterialApp(
      title: 'FixRadar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.routes,
    );
  }
}
