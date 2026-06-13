import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/models/user_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/language_service.dart';
import '../../core/config/routes.dart';
import '../profile/public_profile_screen.dart';

import '../../core/config/service_constants.dart';

class TechniciansDirectoryScreen extends StatefulWidget {
  const TechniciansDirectoryScreen({super.key});

  @override
  State<TechniciansDirectoryScreen> createState() => _TechniciansDirectoryScreenState();
}

class _TechniciansDirectoryScreenState extends State<TechniciansDirectoryScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final LocationService _locationService = LocationService();
  Position? _currentPosition;
  String _selectedCategory = 'Todos';
  String _searchQuery = '';
  String _sortBy = 'distance'; // 'distance', 'rating', 'completedJobs'
  bool _onlyVerified = false;
  bool _onlyAvailable = false;

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Todos', 'icon': Icons.all_inclusive},
    ...ServiceConstants.allCategories,
  ];

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    final pos = await _locationService.getCurrentLocation();
    if (mounted) {
      setState(() {
        _currentPosition = pos;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Directorio de Técnicos', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border, color: Color(0xFFFF8A00)),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.favoriteTechnicians),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildCategoryFilter(),
          _buildFilterChips(),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: _firestoreService.getTechnicians(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFFF8A00)));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState();
                }

                List<UserModel> techs = snapshot.data!;

                // 1. Filter by Search Query
                if (_searchQuery.isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  techs = techs.where((t) => 
                    t.name.toLowerCase().contains(q) || 
                    (t.companyName?.toLowerCase().contains(q) ?? false) ||
                    t.specialties.any((s) => s.toLowerCase().contains(q))
                  ).toList();
                }

                // 2. Filter by Category
                if (_selectedCategory != 'Todos') {
                  techs = techs.where((t) => t.specialties.contains(_selectedCategory)).toList();
                }

                // 3. Filter by Status/Verification
                if (_onlyVerified) techs = techs.where((t) => t.idVerified).toList();
                if (_onlyAvailable) techs = techs.where((t) => t.presenceStatus == 'online').toList();

                // 4. Map to list with distance for sorting
                final List<Map<String, dynamic>> techsWithData = techs.map((t) {
                  double distance = 0;
                  if (_currentPosition != null && t.latitude != null && t.longitude != null) {
                    distance = Geolocator.distanceBetween(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                      t.latitude!,
                      t.longitude!,
                    );
                  }
                  return {'user': t, 'distance': distance};
                }).toList();

                // 5. Sorting
                techsWithData.sort((a, b) {
                  final techA = a['user'] as UserModel;
                  final techB = b['user'] as UserModel;

                  if (_sortBy == 'distance') {
                    return (a['distance'] as double).compareTo(b['distance'] as double);
                  } else if (_sortBy == 'rating') {
                    return techB.rating.compareTo(techA.rating);
                  } else if (_sortBy == 'completedJobs') {
                    return techB.completedJobsCount.compareTo(techA.completedJobsCount);
                  }
                  return 0;
                });

                if (techsWithData.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: techsWithData.length,
                  itemBuilder: (context, index) {
                    final item = techsWithData[index];
                    return _buildTechnicianCard(item['user'], item['distance']);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          onChanged: (val) => setState(() => _searchQuery = val),
          decoration: const InputDecoration(
            hintText: 'Buscar por nombre, especialidad...',
            prefixIcon: Icon(Icons.search, color: Colors.grey),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat['name'];
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat['name']),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              width: 70,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFFF8A00) : Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(cat['icon'], color: isSelected ? Colors.white : Colors.grey[600], size: 20),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    cat['name'],
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? const Color(0xFFFF8A00) : Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          _buildFilterChip('Cercanos', _sortBy == 'distance', () => setState(() => _sortBy = 'distance')),
          const SizedBox(width: 8),
          _buildFilterChip('Mejor Valorados', _sortBy == 'rating', () => setState(() => _sortBy = 'rating')),
          const SizedBox(width: 8),
          _buildFilterChip('Más Trabajos', _sortBy == 'completedJobs', () => setState(() => _sortBy = 'completedJobs')),
          const SizedBox(width: 8),
          _buildFilterChip('Verificados', _onlyVerified, () => setState(() => _onlyVerified = !_onlyVerified)),
          const SizedBox(width: 8),
          _buildFilterChip('Disponibles', _onlyAvailable, () => setState(() => _onlyAvailable = !_onlyAvailable)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black87)),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFFFF8A00),
      checkmarkColor: Colors.white,
      backgroundColor: Colors.grey[100],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('No se encontraron técnicos', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildTechnicianCard(UserModel tech, double distance) {
    final distMiles = distance / 1609.34;
    final isOnline = tech.presenceStatus == 'online';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, AppRoutes.publicProfile, arguments: tech.id),
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 35,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: tech.profileImageUrl.isNotEmpty ? NetworkImage(tech.profileImageUrl) : null,
                        child: tech.profileImageUrl.isEmpty ? const Icon(Icons.person, size: 35, color: Colors.grey) : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: isOnline ? Colors.green : (tech.presenceStatus == 'busy' ? Colors.orange : Colors.grey),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                tech.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (tech.idVerified) const Icon(Icons.verified, color: Colors.blue, size: 18),
                          ],
                        ),
                        if (tech.companyName != null && tech.companyName!.isNotEmpty)
                          Text(tech.companyName!, style: TextStyle(color: Colors.grey[700], fontSize: 12, fontStyle: FontStyle.italic)),
                        const SizedBox(height: 4),
                        Text(
                          tech.specialties.isNotEmpty ? tech.specialties.join(', ') : 'Técnico General',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              tech.rating.toStringAsFixed(1),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(${tech.reviewsCount} reseñas)',
                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                            ),
                            const Spacer(),
                            Text(
                              isOnline ? 'Disponible' : (tech.presenceStatus == 'busy' ? 'Ocupado' : 'Fuera de línea'),
                              style: TextStyle(
                                color: isOnline ? Colors.green : (tech.presenceStatus == 'busy' ? Colors.orange : Colors.grey),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSmallStat(Icons.location_on_outlined, '${distMiles.toStringAsFixed(1)} mi'),
                  _buildSmallStat(Icons.check_circle_outline, '${tech.completedJobsCount} trabajos'),
                  _buildSmallStat(Icons.timer_outlined, tech.avgResponseTime ?? 'N/A'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallStat(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }
}
