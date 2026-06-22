import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lente de vista de la app. NO es el rol de la cuenta: es solo cómo el usuario
/// quiere usar la app en este momento.
///
/// - `pro`: el técnico ve su panel de trabajo (radar, mapa de averías, clientes…).
/// - `client`: el mismo técnico actúa como cliente (publicar problema, mis pedidos…).
///
/// El rol en backend (`role: 'technician'`) NUNCA cambia, así que el técnico
/// sigue recibiendo notificaciones de trabajos aunque esté en lente `client`,
/// y las respuestas a sus propias solicitudes le llegan por su `userId`.
enum AppViewMode { pro, client }

class ViewModeService extends ChangeNotifier {
  ViewModeService._();
  static final ViewModeService instance = ViewModeService._();

  static const String _prefsKey = 'app_view_mode';

  AppViewMode _mode = AppViewMode.pro;
  AppViewMode get mode => _mode;

  bool get isClientLens => _mode == AppViewMode.client;
  bool get isProLens => _mode == AppViewMode.pro;

  /// Carga el lente guardado. Si no hay ninguno, usa la vista natural del rol:
  /// técnico → `pro`, cliente → `client`.
  Future<void> load(String accountRole) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved == 'client') {
      _mode = AppViewMode.client;
    } else if (saved == 'pro') {
      _mode = AppViewMode.pro;
    } else {
      _mode = accountRole == 'technician' ? AppViewMode.pro : AppViewMode.client;
    }
    notifyListeners();
  }

  Future<void> setMode(AppViewMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode == AppViewMode.client ? 'client' : 'pro');
  }

  Future<void> toggle() async {
    await setMode(_mode == AppViewMode.pro ? AppViewMode.client : AppViewMode.pro);
  }

  /// Reinicia el lente (p. ej. al cerrar sesión) para que el próximo usuario
  /// arranque con la vista natural de su rol.
  Future<void> reset() async {
    _mode = AppViewMode.pro;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
