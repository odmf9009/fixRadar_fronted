import 'package:firebase_messaging/firebase_messaging.dart';
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

  Future<void> init() async {
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    // Upload token to backend (simulators don't have APNS token, skip gracefully)
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await AuthService().updateFcmToken(token);
      }
    } catch (_) {}

    _fcm.onTokenRefresh.listen((newToken) {
      AuthService().updateFcmToken(newToken);
    });

    // Foreground notifications
    FirebaseMessaging.onMessage.listen(_showLocalNotification);

    // App was in background and user tapped notification
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (message.data.isNotEmpty) onNotificationTap?.call(message.data);
    });

    // App was terminated and user tapped notification to open it
    final initial = await _fcm.getInitialMessage();
    if (initial != null && initial.data.isNotEmpty) {
      // Delay to let the widget tree build first
      Future.delayed(const Duration(milliseconds: 800), () {
        onNotificationTap?.call(initial.data);
      });
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const channel = AndroidNotificationChannel(
      'fixradar_channel',
      'FixRadar Notifications',
      importance: Importance.high,
    );

    await _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          importance: channel.importance,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  /// Show a local alert notification (triggered by proximity or socket events)
  Future<void> showLocalAlert(String title, String body, {String? payload}) async {
    const channel = AndroidNotificationChannel(
      'fixradar_alerts',
      'FixRadar Alerts',
      importance: Importance.high,
    );

    await _local.show(
      title.hashCode ^ body.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          importance: channel.importance,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}
