import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/location_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/directions_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/language_service.dart';
import '../../core/models/service_request.dart';
import '../../core/models/user_model.dart';
import '../../core/models/filter_model.dart';
import '../../core/config/routes.dart';
import 'filters_screen.dart';
import 'widgets/job_card.dart';

class HomeMapScreen extends StatefulWidget {
  final bool isOnline;
  final Function(bool) onToggleOnline;
  final ConnectivityStatus connectivityStatus;
  final ServiceRequest? initialRequest; // Optional request to focus on

  const HomeMapScreen({
    super.key,
    required this.isOnline,
    required this.onToggleOnline,
    required this.connectivityStatus,
    this.initialRequest,
  });

  @override
  State<HomeMapScreen> createState() => HomeMapScreenState();
}

class HomeMapScreenState extends State<HomeMapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final LocationService _locationService = LocationService();
  final FirestoreService _firestoreService = FirestoreService();
  final DirectionsService _directionsService = DirectionsService();
  final NotificationService _notificationService = NotificationService();
  final TextEditingController _searchController = TextEditingController();
  
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<List<UserModel>>? _techniciansSubscription;
  StreamSubscription<UserModel?>? _userSubscription;
  Position? _currentPosition;
  UserModel? _currentUser;
  
  List<ServiceRequest> _allRequests = [];
  List<ServiceRequest> _nearbyRequests = [];
  List<UserModel> _activeTechnicians = [];
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  
  bool _isInitialLoading = true;
  bool _isLocating = true;
  FilterModel _currentFilters = FilterModel(
    distance: 20.0,
    category: 'Todos', 
    status: 'open',
    searchQuery: '',
  );

  final Map<String, BitmapDescriptor> _markerIconCache = {};

  @override
  void initState() {
    super.initState();
    _initLocation();
    _listenToUserData();
    _listenToTechnicians();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _techniciansSubscription?.cancel();
    _userSubscription?.cancel();
    super.dispose();
  }

  void _listenToUserData() {
    final String uid = AuthService.currentUidSync;
    if (uid.isNotEmpty) {
      _userSubscription = _firestoreService.getUserStream(uid).listen((user) {
        if (mounted) {
          setState(() {
            _currentUser = user;
            if (user != null) {
              _currentFilters = _currentFilters.copyWith(distance: user.serviceRadius);
            }
          });
          _filterAndRefreshMap();
        }
      });
    }
  }

  void _listenToTechnicians() {
    _techniciansSubscription = _firestoreService.getActiveHunters().listen((users) {
      if (mounted) {
        final String uid = AuthService.currentUidSync;
        _activeTechnicians = users.where((u) => u.id != uid && u.role == 'technician').toList();
        _filterAndRefreshMap();
      }
    });
  }

  void _listenToRequests(Position pos) {
    _firestoreService.getNearbyServiceRequests(
      userId: AuthService.currentUidSync,
      latitude: pos.latitude,
      longitude: pos.longitude,
      radius: (_currentUser?.serviceRadius ?? 20.0) * 1.6,
    ).listen((requests) {
      if (mounted) {
        _allRequests = requests;
        _isInitialLoading = false;
        _filterAndRefreshMap();
      }
    });
  }

  void _filterAndRefreshMap() {
    final double? refLat = _currentPosition?.latitude;
    final double? refLng = _currentPosition?.longitude;

    if (refLat == null || refLng == null) return;

    final double maxDistance = _currentFilters.distance * 1609.34;
    final String query = _currentFilters.searchQuery.toLowerCase();

    final filtered = _allRequests.where((req) {
      double dist = Geolocator.distanceBetween(refLat, refLng, req.latitude, req.longitude);
      if (dist > maxDistance) return false;
      if (_currentFilters.category != 'Todos' && req.category != _currentFilters.category) return false;
      if (query.isNotEmpty && !req.title.toLowerCase().contains(query)) return false;
      
      // Specialist Filter (Handyman has total access)
      if (_currentUser?.role == 'technician') {
        if (_currentUser!.specialties.isEmpty) return false;
        final bool isHandyman = _currentUser!.specialties.contains('Handyman');
        if (!isHandyman && !_currentUser!.specialties.contains(req.category)) {
          return false;
        }
      }

      // Comentamos temporalmente el filtro de posts propios para pruebas
      // if (req.clientId == _currentUser?.id) return false;

      return true;
    }).toList();

    final Set<Marker> newMarkers = {};

    // Job Markers
    for (var req in filtered) {
      final String? imageUrl = req.imageUrls.isNotEmpty ? req.imageUrls[0] : null;
      BitmapDescriptor icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      
      if (imageUrl != null) {
        if (_markerIconCache.containsKey(imageUrl)) {
          icon = _markerIconCache[imageUrl]!;
        } else {
          _loadCustomMarkerIcon(imageUrl);
        }
      }

      newMarkers.add(Marker(
        markerId: MarkerId(req.id),
        position: LatLng(req.latitude, req.longitude),
        icon: icon,
        onTap: () => Navigator.pushNamed(context, AppRoutes.requestDetail, arguments: req),
      ));
    }

    // Tech Markers
    for (var tech in _activeTechnicians) {
      if (tech.latitude != null && tech.longitude != null) {
        newMarkers.add(Marker(
          markerId: MarkerId('tech_${tech.id}'),
          position: LatLng(tech.latitude!, tech.longitude!),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(title: tech.displayName),
        ));
      }
    }

    if (mounted) {
      setState(() {
        _nearbyRequests = filtered;
        _markers = newMarkers;
      });
    }
  }

  Future<void> _initLocation() async {
    setState(() => _isLocating = true);
    final hasPermission = await _locationService.checkAndRequestPermissions();
    if (hasPermission) {
      final pos = await _locationService.getCurrentLocation();
      if (pos != null) {
        setState(() {
          _currentPosition = pos;
          _isLocating = false;
        });
        _listenToRequests(pos);
        _centerMapOnUser();
        _filterAndRefreshMap();
      } else {
        setState(() => _isLocating = false);
      }
      
      _positionSubscription = _locationService.locationStream.listen((pos) {
        if (mounted) {
          setState(() => _currentPosition = pos);
          _filterAndRefreshMap();
        }
      });
    } else {
      setState(() => _isLocating = false);
    }
  }

  void _openFilters() async {
    final result = await Navigator.push<FilterModel>(
      context,
      MaterialPageRoute(
        builder: (context) => FiltersScreen(
          initialFilters: _currentFilters,
          specialties: _currentUser?.specialties ?? [],
          resultsCount: _nearbyRequests.length,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() => _currentFilters = result);
      _filterAndRefreshMap();
      
      // Save radius to profile if user is technician
      if (_currentUser?.role == 'technician') {
        await _firestoreService.updateUserRadius(_currentUser!.id, result.distance);
      }
    }
  }

  Future<void> centerOnUser() async {
    if (_currentPosition == null) {
      await _initLocation();
    }
    await _centerMapOnUser();
  }

  Future<void> focusOnRequest(ServiceRequest request) async {
    if (_currentPosition == null) {
      await _initLocation();
    }
    _fitBoundsWithRequest(request);
  }

  Future<void> _centerMapOnUser() async {
    final controller = await _controller.future;
    if (_currentPosition != null) {
      if (widget.initialRequest != null) {
        _fitBoundsWithRequest(widget.initialRequest!);
      } else {
        controller.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            16, // Zoomed in for better visibility as requested
          ),
        );
      }
    }
  }

  void _fitBoundsWithRequest(ServiceRequest request) async {
    final controller = await _controller.future;
    if (_currentPosition == null) return;

    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(
        _currentPosition!.latitude < request.latitude ? _currentPosition!.latitude : request.latitude,
        _currentPosition!.longitude < request.longitude ? _currentPosition!.longitude : request.longitude,
      ),
      northeast: LatLng(
        _currentPosition!.latitude > request.latitude ? _currentPosition!.latitude : request.latitude,
        _currentPosition!.longitude > request.longitude ? _currentPosition!.longitude : request.longitude,
      ),
    );

    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition != null 
                  ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                  : const LatLng(25.7617, -80.1918), 
              zoom: 14
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: _markers,
            polylines: _polylines,
            onMapCreated: (c) {
              _controller.complete(c);
              if (_currentPosition != null) _centerMapOnUser();
            },
            padding: const EdgeInsets.only(bottom: 280),
          ),
          
          if (_isLocating)
            Container(
              color: Colors.white.withOpacity(0.7),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFFFF8A00)),
                    SizedBox(height: 16),
                    Text('Obteniendo tu ubicación...', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF8A00))),
                  ],
                ),
              ),
            ),
          
          // Search Bar
          Positioned(
            top: 60,
            left: 20,
            right: 20,
            child: _buildSearchBar(),
          ),

          // Bottom List
          _buildBottomPanel(),

          // Location Button
          Positioned(
            bottom: 300, // Increased from 280
            right: 20,
            child: FloatingActionButton(
              heroTag: 'location_btn',
              onPressed: () => centerOnUser(),
              backgroundColor: Colors.white,
              elevation: 4,
              mini: true,
              child: const Icon(Icons.my_location, color: Color(0xFFFF8A00)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: TextField(
        controller: _searchController,
        decoration: const InputDecoration(
          hintText: 'Buscar trabajos...',
          prefixIcon: Icon(Icons.search, color: Color(0xFFFF8A00)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 15),
        ),
        onChanged: (val) {
          setState(() => _currentFilters = _currentFilters.copyWith(searchQuery: val));
          _filterAndRefreshMap();
        },
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 280, // Increased further to avoid JobCard overflow (was 260)
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Trabajos cercanos (${_nearbyRequests.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.tune, color: Color(0xFFFF8A00)),
                    onPressed: _openFilters,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _currentUser?.role == 'technician' && (_currentUser?.specialties.isEmpty ?? true)
                ? _buildMissingSpecialtiesMessage()
                : _nearbyRequests.isEmpty
                  ? const Center(child: Text('No hay trabajos en esta zona.'))
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _nearbyRequests.length,
                      itemBuilder: (context, index) => JobCard(request: _nearbyRequests[index]),
                    ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildMissingSpecialtiesMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Configura tus especialidades en tu perfil para ver trabajos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.profile),
              child: const Text('Ir a mi perfil', style: TextStyle(color: Color(0xFFFF8A00), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadCustomMarkerIcon(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      final Uint8List bytes = response.bodyBytes;
      
      final ui.Codec codec = await ui.instantiateImageCodec(bytes, targetWidth: 100, targetHeight: 100);
      final ui.FrameInfo fi = await codec.getNextFrame();
      final ui.Image image = fi.image;

      final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(pictureRecorder);
      final Paint paint = Paint()..isAntiAlias = true;
      const double radius = 50.0;
      const double size = 110.0;

      paint.color = const Color(0xFFFF8A00);
      canvas.drawCircle(const Offset(size / 2, size / 2), radius + 4, paint);
      
      paint.color = Colors.white;
      canvas.drawCircle(const Offset(size / 2, size / 2), radius, paint);

      final Path path = Path()..addOval(Rect.fromLTWH((size - radius * 2) / 2, (size - radius * 2) / 2, radius * 2, radius * 2));
      canvas.clipPath(path);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH((size - radius * 2) / 2, (size - radius * 2) / 2, radius * 2, radius * 2),
        paint,
      );

      final ui.Image finalImage = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
      final ByteData? byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List markerBytes = byteData!.buffer.asUint8List();

      final icon = BitmapDescriptor.fromBytes(markerBytes);
      _markerIconCache[url] = icon;
      
      if (mounted) {
        _filterAndRefreshMap();
      }
    } catch (e) {
      print('Error creating custom marker: $e');
    }
  }
}
