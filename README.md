# FixRadar — Frontend (Flutter)

App móvil de FixRadar. Flutter + Firebase (Auth, Messaging, Storage) y consumo de
la API del backend mediante Dio.

## Arranque

```bash
flutter pub get
flutter run
```

## Autenticación

- **Correo + contraseña:** el flujo cifra la contraseña con la clave pública RSA
  que expone el backend (`GET /api/auth/public-key`) antes de enviarla.
- **Google:** se obtiene el ID token de Firebase y se sincroniza con el backend
  vía `POST /api/auth/sync`.

El servicio de auth vive en `lib/core/services/auth_service.dart`
(`_syncGoogleWithBackend`, login/registro).

> ⚠️ No llames a endpoints autenticados (p. ej. `PUT /api/auth/fcm-token`) antes de
> tener sesión: el interceptor de Dio debe adjuntar `Authorization: Bearer <token>`.
> Sin token el backend responde `401 { "error": "Missing authorization token" }`.
> El FCM token debe enviarse **después** de un login exitoso.

## Manejo de errores de autenticación (códigos)

El backend devuelve en cada error de auth un **`code`** estable además del
`message`. La forma de la respuesta es:

```json
{ "code": "02", "error": "<mensaje es>", "message": "<mensaje es>" }
```

El frontend **debe leer `code`** y mostrar el texto en el idioma del usuario,
usando `03` (error genérico) como fallback cuando `code` sea nulo o desconocido.

| code | Caso | Texto sugerido (es) | Texto sugerido (en) |
|------|------|---------------------|---------------------|
| `01` | Contraseña/credenciales incorrectas | Contraseña incorrecta | Incorrect password |
| `02` | Email ya registrado con contraseña (intento Google) | Este correo ya está registrado con contraseña. Inicia sesión con tu contraseña. | This email is already registered with a password. Sign in with your password. |
| `03` | Error de login genérico | Error de inicio de sesión. Contacta con soporte. | Login error. Please contact support. |
| `04` | Faltan campos obligatorios | Completa todos los campos. | Please fill in all fields. |
| `05` | Email inválido | Email inválido. | Invalid email. |
| `06` | Email ya registrado | Este email ya está registrado. Inicia sesión. | This email is already registered. Sign in. |
| `07` | Código de verificación expirado | Código expirado. Solicita uno nuevo. | Code expired. Request a new one. |
| `08` | Código de verificación incorrecto | Código incorrecto. | Incorrect code. |
| `09` | Error al procesar la contraseña | Error al procesar la contraseña. | Error processing password. |

### Implementación actual

- **`lib/core/utils/auth_error_mapper.dart`** — `AuthErrorMapper.message(error)` es
  la fuente única de mensajes de error de auth. Resuelve, en orden:
  1. `code` nuevo del backend → texto es/en.
  2. Mensaje legacy mapeable (p. ej. `"Email already exists"` → código `02`),
     para seguir mostrando el texto correcto **aunque el backend en producción
     todavía no esté actualizado**.
  3. Mensaje del backend tal cual.
  4. Error de conexión / genérico.
  Siempre devuelve un mensaje no vacío.
- El idioma sale de `LanguageService().currentLanguage` (`es` / `en`).
- `login_screen.dart` usa `_parseError(e) => AuthErrorMapper.message(e)` y muestra
  el resultado en un `SnackBar`.

> ⚠️ **Importante:** el login con Google (`AuthService.signInWithGoogle` /
> `_syncGoogleWithBackend`) **propaga** los errores del backend (antes devolvía
> `null` en silencio y no se mostraba nada). La sincronización del splash
> (`syncCurrentUser`) **sí** los atrapa y devuelve `null` para no romper el arranque.
> Al añadir nuevos flujos de auth, mantén esta regla: interactivo propaga, splash silencia.

### Ejemplo de mapeo

```dart
const authErrorMessages = {
  '01': {'es': 'Contraseña incorrecta', 'en': 'Incorrect password'},
  '02': {
    'es': 'Este correo ya está registrado con contraseña. Inicia sesión con tu contraseña.',
    'en': 'This email is already registered with a password. Sign in with your password.'
  },
  '03': {'es': 'Error de inicio de sesión. Contacta con soporte.',
         'en': 'Login error. Please contact support.'},
  '04': {'es': 'Completa todos los campos.', 'en': 'Please fill in all fields.'},
  '05': {'es': 'Email inválido.', 'en': 'Invalid email.'},
  '06': {'es': 'Este email ya está registrado. Inicia sesión.',
         'en': 'This email is already registered. Sign in.'},
  '07': {'es': 'Código expirado. Solicita uno nuevo.', 'en': 'Code expired. Request a new one.'},
  '08': {'es': 'Código incorrecto.', 'en': 'Incorrect code.'},
  '09': {'es': 'Error al procesar la contraseña.', 'en': 'Error processing password.'},
};

String messageForError(Object? code, String lang) {
  final entry = authErrorMessages[code?.toString()] ?? authErrorMessages['03']!;
  return entry[lang] ?? entry['es']!;
}

// Con Dio:
// final code = e.response?.data['code'];
// final msg = messageForError(code, currentLang);
```

> El nomenclador completo y su origen están en el backend:
> `fixRadar_backend/src/utils/errorCodes.js` y su README.

## Recursos de Flutter

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Documentación online](https://docs.flutter.dev/)
