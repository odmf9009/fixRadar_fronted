import 'dart:async';
import 'package:flutter/material.dart';
import 'home_map_screen.dart';
import 'dashboard_screen.dart';
import 'technician_clients_screen.dart';
import 'client_requests_screen.dart';
import 'client_responders_list_screen.dart';
import 'technician_quotes_screen.dart';
import 'technicians_directory_screen.dart';
import 'profile_screen.dart';
import '../../core/config/routes.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/proximity_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/sync_service.dart';
import '../../core/services/language_service.dart';
import '../../core/services/socket_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/view_mode_service.dart';
import '../../core/models/user_model.dart';
import '../../core/models/service_request.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final GlobalKey<HomeMapScreenState> _mapScreenKey = GlobalKey<HomeMapScreenState>();
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final LocationService _locationService = LocationService();
  final ConnectivityService _connectivityService = ConnectivityService();
  String _currentUserId = '';

  ConnectivityStatus _connectivityStatus = ConnectivityStatus.online;
  StreamSubscription<ConnectivityStatus>? _connectivitySubscription;
  StreamSubscription<UserModel?>? _userSubscription;

  bool _isOnline = false;
  bool _radarStarted = false;
  UserModel? _currentUser;
  Timer? _locationSyncTimer;

  // Cache screens to avoid constant recreation and redundant initState/listeners
  List<Widget>? _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initConnectivity();
    _initSocketListeners();
    _initWithUser();
    _initNotificationTapHandler();
  }

  /// La cuenta es de técnico (rol real, no cambia nunca).
  bool get _accountIsTechnician =>
      _currentUser?.role == 'technician' || _currentUser?.userType == 'technician';

  /// Mostrar la UI de técnico = cuenta técnico Y lente en modo `pro`.
  /// Un técnico en lente `client` ve exactamente la experiencia de cliente,
  /// pero sigue siendo técnico en backend (sigue recibiendo trabajos).
  bool get _showTechnicianUI =>
      _accountIsTechnician && ViewModeService.instance.mode == AppViewMode.pro;

  void _initScreens() {
    if (_currentUser == null) return;

    final bool isTechnician = _showTechnicianUI;

    _screens = isTechnician
      ? [
          DashboardScreen(onViewMap: (req) => _onTabTapped(1, focusRequest: req)),
          HomeMapScreen(
            key: _mapScreenKey,
            isOnline: _isOnline,
            onToggleOnline: _toggleOnlineStatus,
            connectivityStatus: _connectivityStatus,
          ),
          const TechnicianQuotesScreen(),
          TechnicianClientsScreen(onViewMap: (req) => _onTabTapped(1, focusRequest: req)),
          const ProfileScreen(),
        ]
      : [
          DashboardScreen(onViewMap: (req) => _onTabTapped(1, focusRequest: req)),
          TechniciansDirectoryScreen(),
          ClientRequestsScreen(onViewMap: (req) => _onTabTapped(1, focusRequest: req)),
          const ClientRespondersListScreen(),
          const ProfileScreen(),
        ];
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reconnect socket (iOS/Android kill TCP connections in background)
      SocketService().connect();
      // Avisar al backend que la app vuelve a primer plano (suprime FCM)
      SocketService().setAppState(true);
      // Refresh map data
      _mapScreenKey.currentState?.centerOnUser();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // App en segundo plano: el backend debe enviar FCM para chats/alertas.
      SocketService().setAppState(false);
    }
  }

  Future<void> _initWithUser() async {
    _currentUserId = await _authService.getCurrentUserId();
    _syncOnlineStatus();
    _listenToUser();
  }

  void _initSocketListeners() {
    SocketService().on('quote:new', (data) {
      if (mounted) {
        NotificationService().showLocalAlert(
          '¡Nueva propuesta!',
          'Un técnico ha enviado un presupuesto para tu pedido.',
        );
      }
    });

    SocketService().on('quote:accepted', (data) {
      if (mounted) {
        NotificationService().showLocalAlert(
          '¡Propuesta aceptada!',
          'Tu presupuesto ha sido aceptado por el cliente.',
        );
      }
    });

    SocketService().on('alert:new', (data) {
      if (mounted) {
        final title = data['requestTitle'] ?? 'Nueva notificación';
        final type = data['type'] ?? 'system';
        String body = 'Tienes una nueva alerta en el radar.';
        
        if (type == 'nearby') body = 'Hay un nuevo trabajo cerca de ti.';
        if (type == 'directQuote') body = 'Un cliente te ha solicitado una cotización directa.';

        NotificationService().showLocalAlert(title, body);
      }
    });
  }

  @override
  void dispose() {
    SocketService().off('quote:new');
    SocketService().off('quote:accepted');
    SocketService().off('alert:new');
    ViewModeService.instance.removeListener(_onViewModeChanged);
    WidgetsBinding.instance.removeObserver(this);
    _locationSyncTimer?.cancel();
    _connectivitySubscription?.cancel();
    _userSubscription?.cancel();
    super.dispose();
  }

  void _onViewModeChanged() {
    if (!mounted) return;
    // El lente cambió: el significado de cada pestaña cambia, así que
    // reconstruimos las pantallas y volvemos a Inicio.
    _initScreens();
    setState(() => _currentIndex = 0);
  }

  void _listenToUser() {
    if (_currentUserId.isNotEmpty) {
      _userSubscription = _firestoreService.getUserStream(_currentUserId).listen((user) {
        if (mounted) {
          final bool wasNull = _currentUser == null;
          setState(() => _currentUser = user);

          if (wasNull && user != null) {
            // Cargar el lente guardado (default = vista natural del rol) y
            // escuchar cambios para reconstruir tabs/pantallas al alternar.
            ViewModeService.instance.load(user.role).then((_) {
              if (mounted) _initScreens();
            });
            ViewModeService.instance.addListener(_onViewModeChanged);
            _initScreens();
          }

          // Start radar once, only for technicians
          if (!_radarStarted && user != null &&
              (user.role == 'technician' || user.userType == 'technician')) {
            _radarStarted = true;
            ProximityService().startMonitoring(isTechnician: true);
          }
        }
      });
    }
  }

  void _initConnectivity() {
    _connectivitySubscription = _connectivityService.statusStream.listen((status) {
      if (mounted) setState(() => _connectivityStatus = status);
    });
  }

  Future<void> _syncOnlineStatus() async {
    if (_currentUserId.isEmpty) return;
    setState(() => _isOnline = true);
    final pos = await _locationService.getCurrentLocation();
    await _firestoreService.updateUserOnlineStatus(_currentUserId, true, lat: pos?.latitude, lng: pos?.longitude);
    _startLocationSync();
  }

  void _startLocationSync() {
    _locationSyncTimer?.cancel();
    _locationSyncTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (!_isOnline || _connectivityStatus == ConnectivityStatus.offline) return;
      final pos = await _locationService.getCurrentLocation();
      if (pos != null) {
        SocketService().updateLocation(pos.latitude, pos.longitude);
      }
    });
  }

  Future<void> _toggleOnlineStatus(bool value) async {
    if (_currentUserId.isEmpty) return;
    setState(() => _isOnline = value);
    if (value) {
      final pos = await _locationService.getCurrentLocation();
      await _firestoreService.updateUserOnlineStatus(_currentUserId, true, lat: pos?.latitude, lng: pos?.longitude);
      _startLocationSync();
    } else {
      await _firestoreService.updateUserOnlineStatus(_currentUserId, false);
      _locationSyncTimer?.cancel();
    }
  }

  void _initNotificationTapHandler() {
    NotificationService().onNotificationTap = (data) async {
      final type = data['type'] as String?;
      final requestId = data['requestId'] as String?;

      // Quote received → switch to proposals tab (index 3)
      if (type == 'quote_received') {
        if (mounted) _onTabTapped(3);
        return;
      }

      // Chat message → abrir directamente el chat entre las dos partes.
      if (type == 'chat_message') {
        final quoteId = data['quoteId'] as String?;
        if (quoteId != null && quoteId.isNotEmpty) {
          // Chat asociado a una cotización/propuesta.
          try {
            final quote = await _firestoreService.getQuoteById(quoteId);
            String title = 'Chat de Cotización';
            String? otherName = quote?.technicianName;
            if (quote != null) {
              final req = await _firestoreService.getServiceRequestById(quote.requestId);
              if (req != null) title = req.title;
              // Si el usuario actual es el técnico, la otra parte es el cliente.
              if (quote.technicianId == _currentUserId) {
                otherName = req?.clientName;
              }
            }
            if (mounted) {
              Navigator.pushNamed(context, AppRoutes.chat, arguments: {
                'quoteId': quoteId,
                'title': title,
                'technicianName': otherName,
              });
            }
          } catch (_) {}
          return;
        }
        // Chat normal asociado a una solicitud.
        if (requestId != null && requestId.isNotEmpty) {
          try {
            final request = await _firestoreService.getServiceRequestById(requestId);
            if (request != null && mounted) {
              Navigator.pushNamed(context, AppRoutes.chat, arguments: request);
            }
          } catch (_) {}
        }
        return;
      }

      if (requestId == null || requestId.isEmpty) return;

      if (type == 'nearby_request') {
        try {
          final request = await _firestoreService.getServiceRequestById(requestId);
          if (request != null && mounted) {
            Navigator.pushNamed(context, AppRoutes.requestDetail, arguments: request);
          }
        } catch (_) {}
      }
    };
  }

  void _onTabTapped(int index, {ServiceRequest? focusRequest}) {
    setState(() {
      _currentIndex = index;
    });
    
    // If switching to map, trigger recenter or focus
    if (index == 1) {
      if (focusRequest != null) {
        _mapScreenKey.currentState?.focusOnRequest(focusRequest);
      } else {
        _mapScreenKey.currentState?.centerOnUser();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null || _screens == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bool isTechnician = _showTechnicianUI;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens!,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFFFF8A00),
          unselectedItemColor: Colors.grey,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          items: isTechnician
            ? const [
                BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Inicio'),
                BottomNavigationBarItem(icon: Icon(Icons.work_outline), activeIcon: Icon(Icons.work), label: 'Mapa'),
                BottomNavigationBarItem(icon: Icon(Icons.request_quote_outlined), activeIcon: Icon(Icons.request_quote), label: 'Cotizaciones'),
                BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people), label: 'Clientes'),
                BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Perfil'),
              ]
            : const [
                BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Inicio'),
                BottomNavigationBarItem(icon: Icon(Icons.engineering_outlined), activeIcon: Icon(Icons.engineering), label: 'Técnicos'),
                BottomNavigationBarItem(icon: Icon(Icons.history_outlined), activeIcon: Icon(Icons.history), label: 'Mis Pedidos'),
                BottomNavigationBarItem(icon: Icon(Icons.assignment_ind_outlined), activeIcon: Icon(Icons.assignment_ind), label: 'Propuestas'),
                BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Perfil'),
              ],
        ),
      ),
    );
  }
}
