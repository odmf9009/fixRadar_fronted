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
  UserModel? _currentUser;
  Timer? _locationSyncTimer;

  @override
  void initState() {
    super.didChangeAppLifecycleState(AppLifecycleState.resumed); // Dummy to avoid unused import if needed
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initConnectivity();
    _initSocketListeners();
    _initWithUser();
  }

  Future<void> _initWithUser() async {
    _currentUserId = await _authService.getCurrentUserId();
    _startRadar();
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
    WidgetsBinding.instance.removeObserver(this);
    _locationSyncTimer?.cancel();
    _connectivitySubscription?.cancel();
    _userSubscription?.cancel();
    super.dispose();
  }

  void _listenToUser() {
    if (_currentUserId.isNotEmpty) {
      _userSubscription = _firestoreService.getUserStream(_currentUserId).listen((user) {
        if (mounted) {
          setState(() => _currentUser = user);
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
    _locationSyncTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
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

  void _startRadar() {
    ProximityService().startMonitoring();
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
    if (_currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bool isTechnician = _currentUser?.role == 'technician';

    final List<Widget> screens = isTechnician 
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

    final List<BottomNavigationBarItem> navItems = isTechnician
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
        ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
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
          items: navItems,
        ),
      ),
    );
  }
}
