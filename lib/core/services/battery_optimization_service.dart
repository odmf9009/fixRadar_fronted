import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'language_service.dart';

/// Pide al técnico, con un diálogo propio primero y luego el diálogo nativo
/// de Android, que excluya a FixRadar de la optimización de batería. Sin
/// esto, fabricantes como Samsung/Xiaomi pueden bloquear la entrega de push
/// de trabajos nuevos cuando la app está cerrada. Solo aplica a Android; en
/// iOS no existe este concepto.
class BatteryOptimizationService {
  static const _dismissedKey = 'battery_opt_prompt_dismissed';

  static Future<void> checkAndPromptIfNeeded(BuildContext context) async {
    if (!Platform.isAndroid) return;

    final status = await Permission.ignoreBatteryOptimizations.status;
    if (status.isGranted) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_dismissedKey) == true) return;

    if (!context.mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('battery_opt_title')),
        content: Text(tr('battery_opt_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('battery_opt_later')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('battery_opt_allow')),
          ),
        ],
      ),
    );

    if (accepted == true) {
      await Permission.ignoreBatteryOptimizations.request();
    }
    await prefs.setBool(_dismissedKey, true);
  }
}
