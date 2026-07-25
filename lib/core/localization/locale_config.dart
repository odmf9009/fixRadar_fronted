/// Registro central de idiomas soportados por la app.
///
/// Para agregar un idioma nuevo:
///   1. Crea `assets/i18n/{code}.json` con las mismas claves que `en.json`.
///   2. Agrega una entrada a [AppLocales.supported] con ese código.
/// Nada más requiere cambios: el selector de idioma, la carga de traducciones,
/// el formateo de fechas y el idioma usado por la IA lo toman de esta lista.
class LocaleInfo {
  /// Código ISO 639-1 (ej. 'es', 'en'). Debe coincidir con el nombre del
  /// archivo `assets/i18n/{code}.json` y con el locale registrado en `intl`.
  final String code;

  /// Nombre del idioma en su propio idioma (ej. 'Español').
  final String nativeName;

  /// Nombre del idioma en inglés (ej. 'Spanish'). Se usa como subtítulo en
  /// el selector y para instruir a la IA en qué idioma responder.
  final String englishName;

  /// Emoji de bandera mostrado en el selector de idioma.
  final String flag;

  const LocaleInfo({
    required this.code,
    required this.nativeName,
    required this.englishName,
    required this.flag,
  });
}

class AppLocales {
  AppLocales._();

  /// Idioma de respaldo: se usa si falta una clave en el idioma activo,
  /// o si el idioma guardado ya no está soportado.
  static const String fallback = 'en';

  static const List<LocaleInfo> supported = [
    LocaleInfo(code: 'es', nativeName: 'Español', englishName: 'Spanish', flag: '🇪🇸'),
    LocaleInfo(code: 'en', nativeName: 'English', englishName: 'English', flag: '🇺🇸'),
  ];

  static LocaleInfo byCode(String code) {
    return supported.firstWhere(
      (l) => l.code == code,
      orElse: () => supported.firstWhere((l) => l.code == fallback),
    );
  }
}
