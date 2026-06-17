import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/language_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/socket_service.dart';
import '../../core/services/proximity_service.dart';
import '../../core/config/routes.dart';
import '../../core/models/service_request.dart';
import '../../core/models/user_model.dart';
import '../../core/config/service_constants.dart';
import '../../core/models/alert_model.dart';
import 'widgets/category_item.dart';
import 'widgets/job_card.dart';
import 'widgets/category_badge.dart';

class DashboardScreen extends StatefulWidget {
  final Function(ServiceRequest?)? onViewMap;
  const DashboardScreen({super.key, this.onViewMap});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final LocationService _locationService = LocationService();
  String _currentUserId = '';

  // Estado de Datos
  UserModel? _user;
  List<ServiceRequest> _nearbyRequests = [];
  List<UserModel> _topTechnicians = [];
  List<ServiceRequest> _myActiveRequests = [];
  Position? _currentPosition;

  // Estado de Carga
  bool _isLoadingUser = true;
  bool _isLoadingNearby = true;
  bool _isLoadingTechs = true;
  bool _isUpdatingStatus = false;

  // Suscripciones
  StreamSubscription? _userSub;
  StreamSubscription? _nearbySub;
  StreamSubscription? _techsSub;
  StreamSubscription? _myRequestsSub;

  // Cached Streams for StreamBuilders to avoid re-fetching on build
  Stream<List<AlertModel>>? _alertsStream;

  @override
  void initState() {
    super.initState();
    print('STABLE_DASHBOARD: Starting services...');
    _initWithUser();
  }

  Future<void> _initWithUser() async {
    _currentUserId = await _authService.getCurrentUserId();
    if (!mounted) return;
    _alertsStream = _firestoreService.getUserAlerts(_currentUserId);
    _startDataListeners();
    _initLocation();
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _nearbySub?.cancel();
    _techsSub?.cancel();
    _myRequestsSub?.cancel();
    super.dispose();
  }

  void _startDataListeners() {
    // 1. Escuchar Usuario
    _userSub = _firestoreService.getUserStream(_currentUserId).listen((userData) {
      if (mounted) {
        setState(() {
          _user = userData;
          _isLoadingUser = false;
        });
      }
    });

    // 2. Escuchar Problemas Cercanos (Abiertos) - Ahora se inicia en _initLocation tras obtener posición

    // 3. Técnicos cercanos — se inicia en _startNearbyTechnicianListener tras obtener posición

    // 4. Escuchar Solicitudes Propias (Si es cliente)
    _myRequestsSub = _firestoreService.getClientRequests(_currentUserId).listen((data) {
      if (mounted) {
        setState(() => _myActiveRequests = data);
      }
    });
  }

  void _startNearbyTechnicianListener(Position pos) {
    _techsSub?.cancel();
    final double radius = (_user?.serviceRadius ?? 20.0);
    _techsSub = _firestoreService.getNearbyTechniciansStream(
      latitude: pos.latitude,
      longitude: pos.longitude,
      radius: radius < 20 ? 20 : radius,
    ).listen((data) {
      if (mounted) {
        setState(() {
          _topTechnicians = data;
          _isLoadingTechs = false;
        });
      }
    }, onError: (_) {
      if (mounted) setState(() => _isLoadingTechs = false);
    });
  }

  void _startNearbyListener(Position pos) {
    _nearbySub?.cancel();
    // Use user's service radius if available (convert miles to km if needed, 
    // but for now we'll assume km for consistency with backend)
    final double radius = (_user?.serviceRadius ?? 20.0) * 1.6; // Assuming stored in miles, convert to km

    _nearbySub = _firestoreService.getNearbyServiceRequests(
      userId: _currentUserId,
      latitude: pos.latitude,
      longitude: pos.longitude,
      radius: radius > 50 ? radius : 50.0, // Minimum 50km for safety
    ).listen((data) {
      print('STABLE_DASHBOARD: Received ${data.length} nearby requests');
      if (mounted) {
        setState(() {
          _nearbyRequests = data;
          _isLoadingNearby = false;
        });
      }
    }, onError: (e) {
      print('STABLE_DASHBOARD: Error en nearby: $e');
      if (mounted) {
        setState(() => _isLoadingNearby = false);
      }
    });
  }

  Future<void> _initLocation() async {
    try {
      final pos = await _locationService.getCurrentLocation();
      if (mounted && pos != null) {
        setState(() => _currentPosition = pos);
        _startNearbyListener(pos);
        _startNearbyTechnicianListener(pos);
      }
    } catch (e) {
      print('STABLE_DASHBOARD: Location error: $e');
    }
  }

  Widget _buildRadarIcon(bool isOnline) {
    if (isOnline) {
      return const Icon(Icons.radar, color: Color(0xFFFF8A00), size: 28);
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.radar, color: Colors.grey[400], size: 28),
        Transform.rotate(
          angle: -0.7854, // -45 degrees
          child: Container(
            width: 30,
            height: 2.5,
            decoration: BoxDecoration(
              color: Colors.grey[500],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    );
  }

  bool _isWithinWorkHours(UserModel user) {
    final workHours = user.workHours;
    if (workHours == null || workHours.isEmpty) return true;

    final now = DateTime.now();
    final isWeekend = now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
    if (isWeekend && !user.weekendAvailability) return false;

    final parts = workHours.split(' - ');
    if (parts.length != 2) return true;

    int? parseTime(String timeStr) {
      final match = RegExp(r'^(\d+):(\d+)\s*(AM|PM)$', caseSensitive: false).firstMatch(timeStr.trim());
      if (match == null) return null;
      int hours = int.parse(match.group(1)!);
      final minutes = int.parse(match.group(2)!);
      final period = match.group(3)!.toUpperCase();
      if (period == 'PM' && hours != 12) hours += 12;
      if (period == 'AM' && hours == 12) hours = 0;
      return hours * 60 + minutes;
    }

    final start = parseTime(parts[0]);
    final end = parseTime(parts[1]);
    if (start == null || end == null) return true;

    final nowMinutes = now.hour * 60 + now.minute;
    return nowMinutes >= start && nowMinutes <= end;
  }

  Future<void> _toggleOnlineStatus() async {
    final isCurrentlyOnline = _user?.isOnline ?? false;

    if (isCurrentlyOnline) {
      // Confirm going offline
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(tr('go_offline_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text(tr('go_offline_message')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('cancel'), style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[700],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(tr('go_offline_confirm'), style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    } else {
      // Going online — warn if outside configured work hours
      final user = _user;
      if (user != null && user.workHours != null && !_isWithinWorkHours(user)) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.schedule, color: Color(0xFFFF8A00)),
                const SizedBox(width: 8),
                Text(tr('outside_work_hours_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(tr('outside_work_hours_message')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(tr('cancel'), style: const TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8A00),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(tr('outside_work_hours_confirm'), style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
      }
    }

    setState(() => _isUpdatingStatus = true);
    try {
      final goingOnline = !isCurrentlyOnline;
      final updatedUser = await _firestoreService.updateOnlineStatus(isOnline: goingOnline);

      // Update local user immediately so icon refreshes without waiting for stream
      if (updatedUser != null && mounted) {
        setState(() => _user = updatedUser);
      }

      // Manage socket and radar based on online status
      final socket = SocketService();
      if (goingOnline) {
        await socket.connect();
        await ProximityService().startMonitoring(isTechnician: true);
      } else {
        await ProximityService().stopMonitoring();
        socket.disconnect();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(goingOnline ? tr('status_now_online') : tr('status_now_offline')),
            backgroundColor: goingOnline ? const Color(0xFFFF8A00) : Colors.grey[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser && _user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFFF8A00))));
    }

    final user = _user;
    if (user == null) return const Scaffold(body: Center(child: Text('Error al cargar perfil.')));

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: () async {
          await _initLocation();
          // No necesitamos reiniciar streams porque son vivos, pero forzamos un rebuild
          setState(() {});
        },
        color: const Color(0xFFFF8A00),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(user),
                const SizedBox(height: 24),
                _buildPublishButton(),
                const SizedBox(height: 32),
                _buildCategories(),
                const SizedBox(height: 32),

                // Secciones dinámicas según rol
                if (user.role == 'client') ...[
                  _buildMyRequestsSummary(),
                  const SizedBox(height: 32),
                  _buildTopTechniciansList(),
                ] else ...[
                  _buildTechnicianSpecificSection(user),
                ],
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(UserModel user) {
    final bool isTech = user.role == 'technician';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Image.asset(
              'assets/logo_centro.png',
              height: 120,
              fit: BoxFit.contain,
            ),
            Row(
              children: [
                if (user.role == 'technician')
                  _isUpdatingStatus
                    ? const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF8A00)),
                      )
                    : IconButton(
                        icon: _buildRadarIcon(user.isOnline),
                        onPressed: _toggleOnlineStatus,
                        tooltip: user.isOnline
                            ? tr('radar_tooltip_on')
                            : tr('radar_tooltip_off'),
                      ),
                _buildNotificationBell(),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              'Hola, ${user.name.split(' ')[0]} 👋', 
              style: const TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold)
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isTech ? const Color(0xFFFF8A00).withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isTech ? const Color(0xFFFF8A00).withOpacity(0.2) : Colors.blue.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isTech ? Icons.engineering : Icons.home, 
                    size: 14, 
                    color: isTech ? const Color(0xFFFF8A00) : Colors.blue
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isTech ? 'Técnico' : 'Cliente',
                    style: TextStyle(
                      fontSize: 11, 
                      fontWeight: FontWeight.bold, 
                      color: isTech ? const Color(0xFFFF8A00) : Colors.blue
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Text('¿En qué podemos ayudarte hoy?', style: TextStyle(color: Colors.grey, fontSize: 14)),
      ],
    );
  }

  Widget _buildPublishButton() {
    return ElevatedButton.icon(
      onPressed: () => Navigator.pushNamed(context, AppRoutes.publish),
      icon: const Icon(Icons.add_circle_outline, color: Colors.white),
      label: const Text('Publicar un problema'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFF8A00),
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildCategories() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Categorías populares', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: ServiceConstants.allCategories.take(4).map((cat) => 
            CategoryItem(label: cat['name'] as String, icon: cat['icon'] as IconData, color: cat['color'] as Color)
          ).toList(),
        ),
      ],
    );
  }

  Widget _buildMyRequestsSummary() {
    if (_myActiveRequests.isEmpty) return const SizedBox();

    int waiting = _myActiveRequests.where((r) => r.status == ServiceRequestStatus.open).length;
    int active = _myActiveRequests.where((r) => r.status == ServiceRequestStatus.assigned || r.status == ServiceRequestStatus.inProgress).length;

    if (waiting == 0 && active == 0) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Mis solicitudes activas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          children: [
            if (waiting > 0) _statusBadge('Esperando cotizaciones ($waiting)', Colors.orange),
            if (active > 0) ...[const SizedBox(width: 8), _statusBadge('Técnicos trabajando ($active)', Colors.blue)],
          ],
        ),
      ],
    );
  }

  Widget _buildNearbyProblemsList() {
    final user = _user;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Problemas recientes cerca de ti', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        if (_isLoadingNearby && _nearbyRequests.isEmpty)
          const Center(child: CircularProgressIndicator())
        else if (_nearbyRequests.isEmpty)
          const Text('No hay problemas reportados cerca.', style: TextStyle(color: Colors.grey))
        else
          ..._nearbyRequests.where((req) {
            // Only show open requests
            if (req.status != ServiceRequestStatus.open) return false;

            if (user?.role == 'technician') {
               // Apply skills filter
               final bool isHandyman = user!.specialties.contains('Handyman');
               if (!isHandyman && !user.specialties.contains(req.category)) return false;
               
               // Apply distance filter
               if (_currentPosition != null) {
                 double dist = Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, req.latitude, req.longitude);
                 if (dist > user.serviceRadius * 1609.34) return false;
               }
            }
            return true;
          }).take(3).map((req) {
            double distance = 0;
            if (_currentPosition != null) {
              distance = Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, req.latitude, req.longitude) / 1609.34;
            }
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(backgroundColor: Colors.grey[100], child: const Icon(Icons.location_on, color: Color(0xFFFF8A00), size: 20)),
              title: Text(req.title, style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: CategoryBadge(category: req.category, fontSize: 10),
              ),
              trailing: Text('${distance.toStringAsFixed(1)} mi', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              onTap: () async {
                final result = await Navigator.pushNamed(context, AppRoutes.requestDetail, arguments: req);
                if (result is ServiceRequest && mounted) {
                  widget.onViewMap?.call(result);
                }
              },
            );
          }),
      ],
    );
  }

  Widget _buildTopTechniciansList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(tr('technicians_nearby'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.topTechnicians),
              child: const Text('Ver todos', style: TextStyle(color: Color(0xFFFF8A00))),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingTechs && _topTechnicians.isEmpty)
          const SizedBox(height: 100, child: Center(child: LinearProgressIndicator()))
        else if (_topTechnicians.isEmpty)
          const Text('No hay técnicos activos en tu zona.', style: TextStyle(color: Colors.grey))
        else
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _topTechnicians.length,
              itemBuilder: (context, index) {
                final tech = _topTechnicians[index];
                return Container(
                  width: 210,
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundImage: tech.profileImageUrl.isNotEmpty ? NetworkImage(tech.profileImageUrl) : null,
                        child: tech.profileImageUrl.isEmpty ? const Icon(Icons.person) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(tech.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(tech.specialties.isNotEmpty ? tech.specialties.first : 'Especialista', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            Row(children: [const Icon(Icons.star, color: Colors.amber, size: 14), Text(' ${tech.rating.toStringAsFixed(1)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))]),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildTechnicianSpecificSection(UserModel user) {
    if (user.specialties.isEmpty) {
      return _buildConfigureSpecialtiesMessage();
    }

    // Filtrar trabajos por especialidad del técnico (Handyman tiene acceso total)
    final bool isHandyman = user.specialties.contains('Handyman');
    final double maxDistance = user.serviceRadius * 1609.34;
    
    final jobs = _nearbyRequests.where((r) {
      // Skill check
      if (!isHandyman && !user.specialties.contains(r.category)) return false;
      
      // Distance check
      if (_currentPosition != null) {
        double dist = Geolocator.distanceBetween(
          _currentPosition!.latitude, 
          _currentPosition!.longitude, 
          r.latitude, 
          r.longitude
        );
        if (dist > maxDistance) return false;
      }
      
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Trabajos para tu especialidad', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => widget.onViewMap?.call(null),
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Colors.grey[100]),
            child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]), child: const Text('Ver en el mapa', style: TextStyle(fontWeight: FontWeight.bold)))),
          ),
        ),
        const SizedBox(height: 20),
        if (jobs.isEmpty)
          const Text('No hay trabajos nuevos en tu área.', style: TextStyle(color: Colors.grey))
        else
          SizedBox(
            height: 180, // Compactado de 220 a 180
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: jobs.length,
              itemBuilder: (context, index) => JobCard(request: jobs[index]),
            ),
          ),
      ],
    );
  }

  Widget _buildConfigureSpecialtiesMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFF8A00).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF8A00).withOpacity(0.2)),
      ),
      child: Column(
        children: [
          const Icon(Icons.engineering_outlined, size: 48, color: Color(0xFFFF8A00)),
          const SizedBox(height: 16),
          const Text(
            'Configura tus especialidades',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Para ver trabajos disponibles, debes seleccionar al menos una especialidad en tu perfil.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.profile),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8A00),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Ir a mi perfil'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationBell() {
    return StreamBuilder<List<AlertModel>>(
      stream: _alertsStream,
      builder: (context, snapshot) {
        final alerts = snapshot.data ?? [];
        final unreadCount = alerts.where((a) => !a.isRead).length;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(
                unreadCount > 0 ? Icons.notifications_active : Icons.notifications_none, 
                size: 28,
                color: unreadCount > 0 ? const Color(0xFFFF8A00) : Colors.black87,
              ),
              onPressed: () => Navigator.pushNamed(context, AppRoutes.alerts),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    unreadCount > 9 ? '9+' : unreadCount.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
