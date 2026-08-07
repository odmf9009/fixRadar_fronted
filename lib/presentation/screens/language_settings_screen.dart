import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/language_service.dart';
import '../../core/services/user_service.dart';

class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  final LanguageService _languageService = LanguageService();
  final UserService _userService = UserService();
  final FirestoreService _firestoreService = FirestoreService();

  Future<void> _selectLanguage(String code) async {
    // Guardamos primero en el backend y DESPUÉS aplicamos el cambio local.
    // El cambio local dispara un rebuild completo de la app (vía ValueKey en
    // main.dart) que vuelve a sincronizar el usuario desde el backend (splash
    // y MainNavigationScreen); si el backend todavía tuviera el idioma viejo
    // en ese momento, esa resincronización pisaría el cambio recién hecho.
    try {
      await _userService.updateMe({'language': code});
      // Para técnicos, ProximityService mantiene una suscripción permanente
      // al stream del usuario (singleton, nunca se cancela entre rebuilds),
      // así que el stream cacheado en FirestoreService nunca se cierra y
      // sigue sirviendo el valor viejo (hasta 60s desactualizado) al
      // remontar la app. Forzamos un refresh inmediato de esa caché para
      // que el remount reciba ya el idioma nuevo.
      final uid = AuthService.currentUidSync;
      if (uid.isNotEmpty) {
        await _firestoreService.refreshUserStream(uid);
      }
    } catch (_) {}
    await _languageService.setLanguage(code);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _languageService,
      builder: (context, _) {
        final currentLang = _languageService.currentLanguage;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              tr('idioma'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFF121212),
            elevation: 0,
            centerTitle: true,
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                for (final locale in _languageService.supportedLocales)
                  _buildLanguageOption(
                    locale.nativeName,
                    locale.englishName,
                    locale.code,
                    locale.flag,
                    currentLang == locale.code,
                  ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    tr('language_auto_adjust_notice'),
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(String title, String subtitle, String code, String flag, bool isSelected) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: Text(flag, style: const TextStyle(fontSize: 24)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
      trailing: isSelected 
          ? const Icon(Icons.check_circle, color: Color(0xFFFF8A00))
          : null,
      onTap: () => _selectLanguage(code),
    );
  }
}
