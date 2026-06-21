import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'auth_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  // Called when user taps a notification. Set by MainNavigationScreen.
  void Function(Map<String, dynamic> data)? onNotificationTap;

  // Channels must be created upfront so FCM background/terminated delivery works on Android 8+
  static const _mainChannel = AndroidNotificationChannel(
    'fixradar_channel',
    'FixRadar Notifications',
    description: 'Notificaciones de FixRadar',
    importance: Importance.high,
    playSound: true,
  );
  static const _alertChannel = AndroidNotificationChannel(
    'fixradar_alerts',
    'FixRadar Alerts',
    description: 'Alertas de proximidad de FixRadar',
    importance: Importance.high,
    playSound: true,
  );

  Future<void> init() async {
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _local.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          onNotificationTap?.call({'requestId': details.payload});
        }
      },
    );

    // Create channels upfront — required for FCM background delivery on Android 8+
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(_mainChannel);
      await androidPlugin?.createNotificationChannel(_alertChannel);
    }

    // Registrar listeners PRIMERO para que siempre queden activos, aunque la
    // obtención del token se demore o falle.
    _fcm.onTokenRefresh.listen((newToken) {
      AuthService().updateFcmToken(newToken);
    });

    // Foreground notifications
    FirebaseMessaging.onMessage.listen(_showLocalNotification);

    // App was in background and user tapped notification
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (message.data.isNotEmpty) onNotificationTap?.call(message.data);
    });

    // App was terminated and user tapped notification to open it.
    // En simulador iOS sin APNs esto se cuelga: protegemos con timeout.
    try {
      final initial = await _fcm
          .getInitialMessage()
          .timeout(const Duration(seconds: 3), onTimeout: () => null);
      if (initial != null && initial.data.isNotEmpty) {
        // Delay to let the widget tree build first
        Future.delayed(const Duration(milliseconds: 800), () {
          onNotificationTap?.call(initial.data);
        });
      }
    } catch (_) {}

    // Subir token al backend. En iOS getToken() requiere un token APNs que NO
    // existe en el simulador, y entonces la llamada NUNCA resuelve (no lanza,
    // simplemente cuelga). Chequeamos APNs + timeout para no bloquear nunca.
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final apns = await _fcm
            .getAPNSToken()
            .timeout(const Duration(seconds: 3), onTimeout: () => null);
        if (apns == null) return; // simulador / sin APNs: omitir subida de token
      }
      final token = await _fcm
          .getToken()
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      if (token != null) {
        await AuthService().updateFcmToken(token);
      }
    } catch (_) {}
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _mainChannel.id,
          _mainChannel.name,
          importance: _mainChannel.importance,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  /// Show a local alert notification (triggered by proximity or socket events)
  Future<void> showLocalAlert(String title, String body, {String? payload}) async {
    await _local.show(
      title.hashCode ^ body.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _alertChannel.id,
          _alertChannel.name,
          importance: _alertChannel.importance,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }
}
