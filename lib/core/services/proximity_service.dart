import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'location_service.dart';
import 'firestore_service.dart';
import 'notification_service.dart';
import 'language_service.dart';
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
  String _monitoringUid = '';

  // Punto desde el que se pidió la última "ventana" de trabajos candidatos al
  // backend. Si el técnico se aleja demasiado de este punto, la renovamos.
  Position? _requestsOrigin;
  static const double _requestsRefreshDistanceMeters = 8000;

  final Set<String> _notifiedRequestIds = {};
  final Set<String> _notifiedAlertIds = {};

  // requestId de cualquier alerta tipo "nearby" ya recibida (creada por el
  // backend al publicarse el pedido, o por este mismo servicio antes). Evita
  // notificar dos veces el mismo trabajo: una al crearse, otra al acercarnos.
  final Set<String> _alertedRequestIds = {};

  bool _isMonitoring = false;

  /// Starts monitoring. Only subscribes to foreground location stream for technicians.
  Future<void> startMonitoring({bool isTechnician = false}) async {
    if (_isMonitoring) return;
    _isMonitoring = true;
    await _loadNotifiedIDs();

    final String uid = AuthService.currentUidSync;
    _monitoringUid = uid;
    if (uid.isNotEmpty) {
      _userSubscription = _firestoreService.getUserStream(uid).listen((user) {
        _currentUser = user;
        _runImmediateCheck();
      });

      // Listen for alerts (quotes, assignments, etc.)
      _alertsSubscription = _firestoreService.getUserAlerts(uid).listen((alerts) {
        _handleNewAlerts(alerts);
        _trackBackendNearbyAlerts(alerts);
      });
    }

    // Only technicians need real-time nearby request tracking and foreground GPS
    if (isTechnician) {
      // El radar solo corre mientras la app está ABIERTA (sin foreground service).
      // Cuando la app pasa a segundo plano, el stream se detiene; los trabajos
      // nuevos de su categoría y radio le llegan por notificación push (FCM)
      // enviada desde el backend. Esto evita el permiso de foreground service.
      // Check permissions before opening the stream to avoid a Samsung/Android
      // race condition where the OS briefly reports "denied" on cold start even
      // when the user already granted location access.
      final hasPermission = await _locationService.checkAndRequestPermissions();
      if (hasPermission) {
        // La búsqueda de "trabajos cercanos" en el backend necesita una
        // posición real desde dónde buscar (no una lista vacía por defecto).
        final initialPosition = await _locationService.getCurrentLocation();
        if (initialPosition != null) {
          _startNearbyRequestsStream(initialPosition);
        }

        _positionSubscription = _locationService.locationStream.listen((position) {
          _checkProximity(position);

          // El técnico se movió lejos del punto donde pedimos la ventana de
          // candidatos: la renovamos para cubrir trabajos que antes quedaban
          // fuera de rango y ahora podrían estar cerca.
          final bool needsRefresh = _requestsOrigin == null ||
              Geolocator.distanceBetween(
                _requestsOrigin!.latitude,
                _requestsOrigin!.longitude,
                position.latitude,
                position.longitude,
              ) > _requestsRefreshDistanceMeters;
          if (needsRefresh) {
            _startNearbyRequestsStream(position);
          }
        });
      } else {
        print('[Proximity] Location permission not granted — skipping GPS stream');
      }
    }
  }

  void _startNearbyRequestsStream(Position position) {
    _requestsSubscription?.cancel();
    _requestsOrigin = position;

    // Ventana generosa alrededor del punto de arranque (mínimo 100km, o 1.5x
    // el radio configurado si es mayor); el filtro fino por el radio real del
    // técnico lo hace _checkProximity con la posición GPS actual en cada tick.
    final double configuredRadiusMeters = (_currentUser?.serviceRadius ?? 20.0) * 1609.34 * 1.5;
    final double windowRadiusMeters = configuredRadiusMeters > 100000 ? configuredRadiusMeters : 100000;

    _requestsSubscription = _firestoreService.getNearbyServiceRequests(
      latitude: position.latitude,
      longitude: position.longitude,
      radius: windowRadiusMeters,
      userId: _monitoringUid.isNotEmpty ? _monitoringUid : null,
    ).listen((requests) {
      _availableRequests = requests.where((r) => r.status == ServiceRequestStatus.open).toList();
      Future.delayed(const Duration(seconds: 1), () => _runImmediateCheck());
      _cleanupStaleNotifiedIDs(requests);
    });
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
    _requestsOrigin = null;
    _alertedRequestIds.clear();
    _monitoringUid = '';
  }

  void _trackBackendNearbyAlerts(List<AlertModel> alerts) {
    for (final alert in alerts) {
      if (alert.type == AlertType.nearby) {
        _alertedRequestIds.add(alert.requestId);
      }
    }
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
          tr('notif_new_quote_recv'),
          alert.requestTitle,
          payload: alert.requestId,
        );
      } else if (alert.type == AlertType.directQuote) {
        _notificationService.showLocalAlert(
          tr('notif_direct_request'),
          tr('notif_direct_request_body').replaceAll('{title}', alert.requestTitle),
          payload: alert.requestId,
        );
      } else if (alert.type == AlertType.system && alert.requestTitle == 'Nueva propuesta recibida') {
        _notificationService.showLocalAlert(
          tr('notif_tech_proposal'),
          alert.address,
          payload: alert.requestId,
        );
      } else if (alert.type == AlertType.system && alert.requestTitle == 'Propuesta rechazada') {
        _notificationService.showLocalAlert(
          tr('notif_proposal_rejected'),
          alert.address,
          payload: alert.requestId,
        );
      } else if (alert.type == AlertType.system && alert.requestTitle == 'Rechazo definitivo') {
        _notificationService.showLocalAlert(
          tr('notif_final_rejection'),
          alert.address,
          payload: alert.requestId,
        );
      } else if (alert.type == AlertType.system && alert.requestTitle == 'Propuesta aceptada') {
        _notificationService.showLocalAlert(
          tr('notif_proposal_accepted'),
          alert.address,
          payload: alert.requestId,
        );
      } else if (alert.type == AlertType.system && alert.requestTitle == 'Asignación cancelada') {
        _notificationService.showLocalAlert(
          tr('notif_assignment_cancelled'),
          alert.address,
          payload: alert.requestId,
        );
      } else if (alert.type == AlertType.system && alert.requestTitle == 'Pedido cancelado por el cliente') {
        _notificationService.showLocalAlert(
          tr('notif_order_cancelled'),
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
        // No duplicar: el backend ya pudo haber alertado este mismo pedido
        // al momento de crearse (si el técnico ya estaba en rango entonces).
        if (!_notifiedRequestIds.contains(request.id) && !_alertedRequestIds.contains(request.id)) {
          _persistNotifiedID(request.id);
          _alertedRequestIds.add(request.id);
          _sendAlert(request, distance);
        }
      }
    }
  }

  void _sendAlert(ServiceRequest request, double distance) {
    double miles = distance / 1609.34;
    String distText = miles < 0.1
        ? tr('very_close_to_you')
        : tr('only_x_miles').replaceAll('{mi}', miles.toStringAsFixed(2));

    _notificationService.showLocalAlert(
      tr('notif_new_issue'),
      tr('notif_new_issue_body').replaceAll('{category}', request.category).replaceAll('{dist}', distText),
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
