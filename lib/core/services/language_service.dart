import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import '../localization/locale_config.dart';

/// Motor de traducciones. Las claves viven en `assets/i18n/{code}.json`,
/// uno por idioma soportado (ver [AppLocales.supported]). Agregar un idioma
/// no requiere tocar esta clase: solo el archivo JSON + una entrada en
/// [AppLocales.supported].
class LanguageService extends ChangeNotifier {
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  LanguageService._internal();

  String _currentLanguage = AppLocales.fallback;
  String get currentLanguage => _currentLanguage;

  /// Idiomas realmente cargados (con su JSON leído con éxito).
  List<LocaleInfo> get supportedLocales =>
      AppLocales.supported.where((l) => _translations.containsKey(l.code)).toList();

  final Map<String, Map<String, String>> _translations = {};
  bool _loaded = false;

  Future<void> init() async {
    await _loadAllLocales();

    final prefs = await SharedPreferences.getInstance();
    // Idioma por defecto: inglés. Se sobreescribe con la preferencia guardada
    // del usuario (sincronizada desde su perfil en backend) al iniciar sesión.
    final saved = prefs.getString('app_language');
    _currentLanguage = (saved != null && _translations.containsKey(saved))
        ? saved
        : AppLocales.fallback;
    notifyListeners();
  }

  Future<void> _loadAllLocales() async {
    if (_loaded) return;
    for (final locale in AppLocales.supported) {
      try {
        final raw = await rootBundle.loadString('assets/i18n/${locale.code}.json');
        final Map<String, dynamic> decoded = jsonDecode(raw) as Map<String, dynamic>;
        _translations[locale.code] = decoded.map((k, v) => MapEntry(k, v.toString()));
      } catch (e) {
        debugPrint('LanguageService: no se pudo cargar assets/i18n/${locale.code}.json — $e');
      }
    }
    _loaded = true;
  }

  Future<void> setLanguage(String langCode) async {
    if (!_translations.containsKey(langCode)) return;
    _currentLanguage = langCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', langCode);
    notifyListeners();
  }

  /// Busca [key] en el idioma activo; si falta, cae al idioma de respaldo
  /// ([AppLocales.fallback]); si tampoco existe ahí, devuelve la clave cruda
  /// (nunca deja un texto vacío en pantalla).
  String translate(String key) {
    final value = _translations[_currentLanguage]?[key];
    if (value != null) return value;

    final fallbackValue = _translations[AppLocales.fallback]?[key];
    if (fallbackValue != null) {
      if (kDebugMode) {
        debugPrint('LanguageService: falta "$key" en "$_currentLanguage", usando "${AppLocales.fallback}".');
      }
      return fallbackValue;
    }

    if (kDebugMode) {
      debugPrint('LanguageService: falta "$key" en todos los idiomas cargados.');
    }
    return key;
  }
}

/// Atajo global para traducir. Sin cambios de firma para no tocar los ~1000
/// puntos de uso existentes (tr('clave')) al migrar la fuente de datos.
String tr(String key) => LanguageService().translate(key);
