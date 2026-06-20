import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/services/auth_service.dart';
import 'package:geocoding/geocoding.dart';
import '../../core/models/service_request.dart';
import '../../core/models/alert_model.dart';
import '../../core/models/user_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/language_service.dart';
import '../../core/config/routes.dart';
import 'widgets/category_badge.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final LocationService _locationService = LocationService();
  Position? _currentPosition;
  String _currentCity = '...';

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    final pos = await _locationService.getCurrentLocation();
    if (pos != null && mounted) {
      setState(() => _currentPosition = pos);
      try {
        List<Placemark> p = await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (p.isNotEmpty) setState(() => _currentCity = p[0].locality ?? tr('tu_area'));
      } catch (e) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageService(),
      builder: (context, _) {
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              title: Text(tr('comunidad_alertas'), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              backgroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
                  onPressed: () => _showClearAllConfirm(context),
                  tooltip: 'Limpiar todo el historial',
                ),
              ],
              bottom: TabBar(
                labelColor: const Color(0xFFFF8A00),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFFFF8A00),
                tabs: [
                  Tab(text: tr('radar'), icon: const Icon(Icons.radar)),
                  Tab(text: tr('novedades'), icon: const Icon(Icons.new_releases_outlined)),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _RadarTab(currentUserId: AuthService.currentUidSync),
                _NovedadesTab(currentPosition: _currentPosition, city: _currentCity),
              ],
            ),
          ),
        );
      }
    );
  }

  void _showClearAllConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Limpiar historial?'),
        content: const Text('Se eliminarán permanentemente todas tus notificaciones guardadas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () async {
                  final uid = AuthService.currentUidSync;
                  if (uid.isNotEmpty) {
                    try {
                      await FirestoreService().clearAllUserAlerts(uid);
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Historial limpiado.')));
                        // Force a refresh of the active stream if needed
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error al limpiar: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Eliminar Todo', style: TextStyle(color: Colors.white)),
              ),
        ],
      ),
    );
  }
}

class _RadarTab extends StatefulWidget {
  final String currentUserId;
  const _RadarTab({required this.currentUserId});
  @override
  State<_RadarTab> createState() => _RadarTabState();
}

class _RadarTabState extends State<_RadarTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final FirestoreService _fs = FirestoreService();
  UserModel? _currentUser;
  Stream<List<AlertModel>>? _alertsStream;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _alertsStream = _fs.getUserAlerts(widget.currentUserId);
  }

  void _loadUser() async {
    final user = await _fs.getUser(widget.currentUserId);
    if (mounted) setState(() => _currentUser = user);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_currentUser == null) return const Center(child: CircularProgressIndicator());

    return StreamBuilder<List<AlertModel>>(
      stream: _alertsStream,
      builder: (context, alertsSnapshot) {
        if (alertsSnapshot.hasError) {
          return Center(child: Text('Error: ${alertsSnapshot.error}'));
        }
        
        // If we have data, we show it. Even if it's empty.
        // We only show loading if we have NO data AND we are actually waiting.
        if (!alertsSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final alerts = alertsSnapshot.data!;
        
        if (alerts.isEmpty) {
          return _buildEmpty(tr('no_hay_alertas'), Icons.radar, tr('no_hay_alertas_desc'));
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _alertsStream = _fs.getUserAlerts(widget.currentUserId);
            });
          },
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: alerts.length,
            separatorBuilder: (context, i) => const Divider(height: 1, indent: 76),
            itemBuilder: (context, i) => _buildAlertItem(context, alerts[i]),
          ),
        );
      },
    );
  }

  Widget _buildAlertItem(BuildContext context, AlertModel alert) {
    return InkWell(
      onTap: () async {
        _fs.markAlertAsRead(widget.currentUserId, alert.id);
        final req = await _fs.getServiceRequestById(alert.requestId);
        if (req != null && mounted) Navigator.pushNamed(context, AppRoutes.requestDetail, arguments: req);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: alert.requestImageUrl.isNotEmpty 
                    ? Image.network(
                        alert.requestImageUrl, 
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                        ),
                      )
                    : const Icon(Icons.image, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(alert.requestTitle, style: TextStyle(fontWeight: alert.isRead ? FontWeight.normal : FontWeight.bold, fontSize: 16)),
                  Text(tr('a_millas').replaceFirst('{d}', (alert.distance / 1609.34).toStringAsFixed(2)), style: const TextStyle(color: Color(0xFFFF8A00), fontSize: 13, fontWeight: FontWeight.w500)),
                  Text(_getTimeAgo(alert.createdAt), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            if (!alert.isRead) const Icon(Icons.circle, size: 8, color: Color(0xFFFF8A00)),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}

class _NovedadesTab extends StatefulWidget {
  final Position? currentPosition;
  final String city;
  const _NovedadesTab({this.currentPosition, required this.city});
  @override
  State<_NovedadesTab> createState() => _NovedadesTabState();
}

class _NovedadesTabState extends State<_NovedadesTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final FirestoreService _fs = FirestoreService();
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  void _loadUser() async {
    final String uid = AuthService.currentUidSync;
    if (uid.isNotEmpty) {
      final user = await _fs.getUser(uid);
      if (mounted) setState(() => _currentUser = user);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_currentUser == null) return const Center(child: CircularProgressIndicator());

    return StreamBuilder<List<ServiceRequest>>(
      stream: _fs.getNearbyServiceRequests(userId: AuthService.currentUidSync),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var allReqs = snapshot.data!;
        final now = DateTime.now();

        var reqs = allReqs.where((o) => now.difference(o.createdAt).inHours < 48).toList();

        // Specialty filter for technicians (Handyman has total access)
        if (_currentUser?.role == 'technician') {
          if (_currentUser!.specialties.isEmpty) {
            reqs = [];
          } else if (!_currentUser!.specialties.contains('Handyman')) {
            reqs = reqs.where((o) => _currentUser!.specialties.contains(o.category)).toList();
          }
        }

        if (widget.currentPosition != null) {
          reqs = reqs.where((o) => Geolocator.distanceBetween(
            widget.currentPosition!.latitude, 
            widget.currentPosition!.longitude, 
            o.latitude, 
            o.longitude
          ) <= 80467).toList();
        }

        if (reqs.isEmpty) return _buildEmpty(tr('sin_novedades'), Icons.new_releases, tr('sin_novedades_desc'));

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: reqs.length,
          separatorBuilder: (context, i) => const Divider(height: 1, indent: 76),
          itemBuilder: (context, i) => _buildRequestItem(context, reqs[i]),
        );
      },
    );
  }

  Widget _buildRequestItem(BuildContext context, ServiceRequest req) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, AppRoutes.requestDetail, arguments: req),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: req.imageUrls.isNotEmpty 
                    ? Image.network(
                        req.imageUrls[0], 
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                        ),
                      )
                    : const Icon(Icons.image, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(req.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  CategoryBadge(category: req.category, fontSize: 10),
                  const SizedBox(height: 4),
                  Text(_getTimeAgo(req.createdAt), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(tr('nuevo'), style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}

Widget _buildEmpty(String t, IconData i, String s) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(i, size: 80, color: Colors.grey[200]),
          const SizedBox(height: 24),
          Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 12),
          Text(s, style: const TextStyle(color: Colors.grey, fontSize: 14), textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

String _getTimeAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return tr('hace_un_momento');
  if (diff.inMinutes < 60) return tr('hace_m').replaceFirst('{m}', diff.inMinutes.toString());
  if (diff.inHours < 24) return tr('hace_h').replaceFirst('{h}', diff.inHours.toString());
  return tr('hace_d').replaceFirst('{d}', diff.inDays.toString());
}
