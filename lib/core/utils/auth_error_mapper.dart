import 'package:dio/dio.dart';
import '../services/language_service.dart';

/// Convierte un error de autenticación en un mensaje legible para el usuario,
/// en el idioma actual (es / en).
///
/// El backend devuelve un `code` estable en cada error de auth
/// (ver `fixRadar_backend/src/utils/errorCodes.js`). Aquí se traduce ese código.
/// Si el backend aún no envía `code` (versión vieja desplegada), se intenta
/// mapear el mensaje legacy y, en último caso, se muestra el texto del servidor
/// o un mensaje genérico. **Siempre** devuelve un mensaje no vacío.
class AuthErrorMapper {
  // Códigos del nomenclador del backend → texto por idioma.
  static const Map<String, Map<String, String>> _byCode = {
    '01': {'es': 'Contraseña incorrecta', 'en': 'Incorrect password'},
    '02': {
      'es': 'Este correo ya está registrado con contraseña. Inicia sesión con tu contraseña.',
      'en': 'This email is already registered with a password. Sign in with your password.',
    },
    '03': {
      'es': 'Error de inicio de sesión. Contacta con soporte.',
      'en': 'Login error. Please contact support.',
    },
    '04': {'es': 'Completa todos los campos.', 'en': 'Please fill in all fields.'},
    '05': {'es': 'Email inválido.', 'en': 'Invalid email.'},
    '06': {
      'es': 'Este email ya está registrado. Inicia sesión.',
      'en': 'This email is already registered. Sign in.',
    },
    '07': {
      'es': 'Código expirado. Solicita uno nuevo.',
      'en': 'Code expired. Request a new one.',
    },
    '08': {'es': 'Código incorrecto.', 'en': 'Incorrect code.'},
    '09': {
      'es': 'Error al procesar la contraseña.',
      'en': 'Error processing password.',
    },
  };

  // Mensajes legacy del backend (sin `code`) → código equivalente.
  // Permite mostrar el texto correcto aunque el servidor no esté actualizado.
  static const Map<String, String> _legacyToCode = {
    'Email already exists': '02',
  };

  static const Map<String, String> _connection = {
    'es': 'Error de conexión. Revisa tu internet e inténtalo de nuevo.',
    'en': 'Connection error. Check your internet and try again.',
  };

  /// Texto localizado para [error]. Nunca devuelve cadena vacía.
  static String message(Object? error) {
    final lang = LanguageService().currentLanguage;

    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        // 1) Código nuevo del nomenclador.
        final code = data['code']?.toString();
        if (code != null && _byCode.containsKey(code)) {
          return _localized(code, lang);
        }
        // 2) Mensaje legacy mapeable a un código conocido.
        final legacy = (data['error'] ?? data['message'])?.toString();
        if (legacy != null && _legacyToCode.containsKey(legacy)) {
          return _localized(_legacyToCode[legacy]!, lang);
        }
        // 3) Mensaje del backend tal cual (suele venir en español).
        if (legacy != null && legacy.trim().isNotEmpty) return legacy;
      }
      // 4) Sin respuesta legible (timeout, sin conexión, etc.).
      return _connection[lang] ?? _connection['es']!;
    }

    // 5) Cualquier otro error → genérico (03).
    return _localized('03', lang);
  }

  static String _localized(String code, String lang) {
    final entry = _byCode[code] ?? _byCode['03']!;
    return entry[lang] ?? entry['es']!;
  }
}
