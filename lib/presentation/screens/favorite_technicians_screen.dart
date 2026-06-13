import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/models/user_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/location_service.dart';
import '../../core/config/routes.dart';

class FavoriteTechniciansScreen extends StatefulWidget {
  const FavoriteTechniciansScreen({super.key});

  @override
  State<FavoriteTechniciansScreen> createState() => _FavoriteTechniciansScreenState();
}

class _FavoriteTechniciansScreenState extends State<FavoriteTechniciansScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final LocationService _locationService = LocationService();
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    final pos = await _locationService.getCurrentLocation();
    if (mounted) setState(() => _currentPosition = pos);
  }

  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Mis Favoritos', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: currentUserId.isEmpty
          ? const Center(child: Text('Inicia sesión para ver tus favoritos'))
          : StreamBuilder<UserModel?>(
              stream: _firestoreService.getUserStream(currentUserId),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final favorites = userSnapshot.data?.favorites ?? [];
                if (favorites.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.favorite_border, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const Text('No tienes técnicos en favoritos', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return StreamBuilder<List<UserModel>>(
                  stream: _firestoreService.getTechnicians(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    
                    final favTechs = snapshot.data!.where((t) => favorites.contains(t.id)).toList();

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: favTechs.length,
                      itemBuilder: (context, index) {
                        final tech = favTechs[index];
                        double distance = 0;
                        if (_currentPosition != null && tech.latitude != null) {
                          distance = Geolocator.distanceBetween(
                            _currentPosition!.latitude, _currentPosition!.longitude,
                            tech.latitude!, tech.longitude!
                          ) / 1609.34;
                        }
                        return _buildFavCard(tech, distance);
                      },
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildFavCard(UserModel tech, double distance) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: ListTile(
        onTap: () => Navigator.pushNamed(context, AppRoutes.publicProfile, arguments: tech.id),
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          radius: 28,
          backgroundImage: tech.profileImageUrl.isNotEmpty ? NetworkImage(tech.profileImageUrl) : null,
          child: tech.profileImageUrl.isEmpty ? const Icon(Icons.person) : null,
        ),
        title: Row(
          children: [
            Text(tech.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 4),
            if (tech.idVerified) const Icon(Icons.verified, color: Colors.blue, size: 14),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tech.specialties.first, style: const TextStyle(color: Color(0xFFFF8A00), fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 14),
                Text(' ${tech.rating.toStringAsFixed(1)} ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text('(${tech.reviewsCount})', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(width: 8),
                Text('${distance.toStringAsFixed(1)} mi', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }
}
