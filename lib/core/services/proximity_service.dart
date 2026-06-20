import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'location_service.dart';
import 'firestore_service.dart';
import 'notification_service.dart';
import '../models/service_request.dart';
import '../models/user_model.dart';
import '../models/alert_model.dart';

class ProximityService {
  static final ProximityService _instance = ProximityService._internal();
  factory ProximityService() => _instance;
  ProximityService._internal();

  final LocationService _locationService = LocationService();
  final FirestoreService _firestoreService = FirestoreService();
  final NotificationService _notificationService = NotificationService();

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<List<ServiceRequest>>? _requestsSubscription;
  StreamSubscription<UserModel?>? _userSubscription;
  StreamSubscription<List<AlertModel>>? _alertsSubscription;
  
  List<ServiceRequest> _availableRequests = [];
  UserModel? _currentUser;
  
  final Set<String> _notifiedRequestIds = {};
  final Set<String> _notifiedAlertIds = {};

  bool _isMonitoring = false;

  /// Starts monitoring. Only subscribes to foreground location stream for technicians.
  Future<void> startMonitoring({bool isTechnician = false}) async {
    if (_isMonitoring) return;
    _isMonitoring = true;
    await _loadNotifiedIDs();

    final String uid = AuthService.currentUidSync;
    if (uid.isNotEmpty) {
      _userSubscription = _firestoreService.getUserStream(uid).listen((user) {
        _currentUser = user;
        _runImmediateCheck();
      });

      // Listen for alerts (quotes, assignments, etc.)
      _alertsSubscription = _firestoreService.getUserAlerts(uid).listen((alerts) {
        _handleNewAlerts(alerts);
      });
    }

    // Only technicians need real-time nearby request tracking and foreground GPS
    if (isTechnician) {
      _requestsSubscription = _firestoreService.getNearbyServiceRequests(userId: uid.isNotEmpty ? uid : null).listen((requests) {
        _availableRequests = requests.where((r) => r.status == ServiceRequestStatus.open).toList();
        Future.delayed(const Duration(seconds: 1), () => _runImmediateCheck());
        _cleanupStaleNotifiedIDs(requests);
      });

      // Foreground location stream keeps radar alive in background.
      // Check permissions before opening the stream to avoid a Samsung/Android
      // race condition where the OS briefly reports "denied" on cold start even
      // when the user already granted location access.
      final hasPermission = await _locationService.checkAndRequestPermissions();
      if (hasPermission) {
        _positionSubscription = _locationService.technicianLocationStream.listen((position) {
          _checkProximity(position);
        });
      } else {
        print('[Proximity] Location permission not granted — skipping GPS stream');
      }
    }
  }

  /// Stops all monitoring (called when technician goes offline or app signs out).
  Future<void> stopMonitoring() async {
    _isMonitoring = false;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    await _requestsSubscription?.cancel();
    _requestsSubscription = null;
    await _userSubscription?.cancel();
    _userSubscription = null;
    await _alertsSubscription?.cancel();
    _alertsSubscription = null;
    _availableRequests = [];
    _currentUser = null;
  }

  Future<void> _runImmediateCheck() async {
    try {
      final position = await _locationService.getCurrentLocation();
      if (position != null) {
        _checkProximity(position);
      }
    } catch (e) {
      print('ProximityService: Error en check inmediato: $e');
    }
  }

  void _cleanupStaleNotifiedIDs(List<ServiceRequest> activeRequests) async {
    final activeIds = activeRequests.map((r) => r.id).toSet();
    _notifiedRequestIds.retainWhere((id) => activeIds.contains(id));
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('notified_request_ids', _notifiedRequestIds.toList());
  }

  Future<void> _loadNotifiedIDs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> savedIds = prefs.getStringList('notified_request_ids') ?? [];
      _notifiedRequestIds.addAll(savedIds);
    } catch (e) {
      print('Error cargando IDs de notificaciones: $e');
    }
  }

  Future<void> _persistNotifiedID(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _notifiedRequestIds.add(id);
      await prefs.setStringList('notified_request_ids', _notifiedRequestIds.toList());
    } catch (e) {
      print('Error persistiendo ID de notificación: $e');
    }
  }

  void _handleNewAlerts(List<AlertModel> alerts) {
    if (alerts.isEmpty) return;

    // We only care about alerts created in the last minute to avoid spamming on start
    final now = DateTime.now();
    
    for (var alert in alerts) {
      if (_notifiedAlertIds.contains(alert.id)) continue;
      
      // Mark as notified immediately to avoid loops
      _notifiedAlertIds.add(alert.id);

      // Skip old alerts
      if (now.difference(alert.createdAt).inMinutes > 2) continue;

      if (alert.type == AlertType.quoteReceived) {
        _notificationService.showLocalAlert(
          '💼 Nueva cotización recibida',
          alert.requestTitle,
          payload: alert.requestId,
        );
      } else if (alert.type == AlertType.directQuote) {
        _notificationService.showLocalAlert(
          '📋 Solicitud directa',
          'Un cliente quiere contratar tus servicios para: ${alert.requestTitle}',
          payload: alert.requestId,
        );
      } else if (alert.type == AlertType.system && alert.requestTitle == 'Nueva propuesta recibida') {
        _notificationService.showLocalAlert(
          '🛠️ Propuesta de técnico',
          alert.address, 
          payload: alert.requestId,
        );
      } else if (alert.type == AlertType.system && alert.requestTitle == 'Propuesta rechazada') {
        _notificationService.showLocalAlert(
          '❌ Propuesta Rechazada',
          alert.address,
          payload: alert.requestId,
        );
      } else if (alert.type == AlertType.system && alert.requestTitle == 'Rechazo definitivo') {
        _notificationService.showLocalAlert(
          '🚫 Rechazo Definitivo',
          alert.address,
          payload: alert.requestId,
        );
      } else if (alert.type == AlertType.system && alert.requestTitle == 'Propuesta aceptada') {
        _notificationService.showLocalAlert(
          '🎉 ¡Propuesta Aceptada!',
          alert.address,
          payload: alert.requestId,
        );
      } else if (alert.type == AlertType.system && alert.requestTitle == 'Asignación cancelada') {
        _notificationService.showLocalAlert(
          '⚠️ Asignación Cancelada',
          alert.address,
          payload: alert.requestId,
        );
      } else if (alert.type == AlertType.system && alert.requestTitle == 'Pedido cancelado por el cliente') {
        _notificationService.showLocalAlert(
          '🚫 Pedido Cancelado',
          alert.address,
          payload: alert.requestId,
        );
      }
    }
  }

  Future<void> _checkProximity(Position userPosition) async {
    final prefs = await SharedPreferences.getInstance();
    final bool nearbyEnabled = prefs.getBool('notify_nearby') ?? true;
    
    if (!nearbyEnabled) return;

    if (_currentUser?.notificationsEnabled == false) return;

    final double alertDistanceMiles = _currentUser?.serviceRadius ?? prefs.getDouble('alert_distance') ?? 5.0;
    final double thresholdInMeters = alertDistanceMiles * 1609.34;

    for (var request in _availableRequests) {
      if (request.clientId == _currentUser?.id) continue;

      if (_currentUser?.role == 'technician') {
        final bool isHandyman = _currentUser!.specialties.contains('Handyman');
        if (!isHandyman && (_currentUser!.specialties.isEmpty || !_currentUser!.specialties.contains(request.category))) {
          continue; 
        }
      }

      double distance = Geolocator.distanceBetween(
        userPosition.latitude,
        userPosition.longitude,
        request.latitude,
        request.longitude,
      );

      if (distance <= thresholdInMeters) {
        if (!_notifiedRequestIds.contains(request.id)) {
          _persistNotifiedID(request.id);
          _sendAlert(request, distance);
        }
      }
    }
  }

  void _sendAlert(ServiceRequest request, double distance) {
    double miles = distance / 1609.34;
    String distText = miles < 0.1 
        ? 'muy cerca de ti' 
        : 'a solo ${miles.toStringAsFixed(2)} millas';
        
    _notificationService.showLocalAlert(
      '🛠️ ¡Nueva avería detectada!',
      'Alguien necesita ayuda con "${request.category}" $distText. ¡Acepta el trabajo ahora! 🏃‍♂️💨',
      payload: request.id,
    );

    if (_currentUser?.id != null) {
      final alert = AlertModel(
        id: '',
        requestId: request.id,
        requestTitle: request.title,
        requestImageUrl: request.imageUrls.isNotEmpty ? request.imageUrls[0] : '',
        address: request.address,
        distance: distance,
        createdAt: DateTime.now(),
        type: AlertType.nearby,
      );
      _firestoreService.saveUserAlert(_currentUser!.id, alert);
    }
  }
}
