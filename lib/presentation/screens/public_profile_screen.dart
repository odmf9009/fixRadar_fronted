import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/user_model.dart';
import '../../core/models/portfolio_item.dart';
import '../../core/models/review_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/config/routes.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;
  const PublicProfileScreen({super.key, required this.userId});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final Color primaryColor = const Color(0xFFFF8A00);
  final Color darkColor = const Color(0xFF121212);

  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<UserModel?>(
      stream: _firestoreService.getUserStream(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFFF8A00))));
        }

        final user = snapshot.data;
        if (user == null) {
          return const Scaffold(body: Center(child: Text('Usuario no encontrado')));
        }

        return StreamBuilder<UserModel?>(
          stream: _firestoreService.getUserStream(currentUserId),
          builder: (context, currentUserSnapshot) {
            final currentUser = currentUserSnapshot.data;
            final bool isFavorite = currentUser?.favorites.contains(user.id) ?? false;

            return Scaffold(
              backgroundColor: Colors.grey[50],
              body: CustomScrollView(
                slivers: [
                  _buildAppBar(user, isFavorite, currentUserId),
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildMainInfo(user),
                        _buildStats(user),
                        _buildSection('Especialidades', _buildSpecialties(user)),
                        _buildSection('Acerca del Técnico', _buildAbout(user)),
                        _buildSection('Insignias y Verificaciones', _buildVerifications(user)),
                        _buildSection('Información Comercial', _buildBusinessInfo(user)),
                        _buildSection('Área de Servicio', _buildServiceArea(user)),
                        _buildSection('Portafolio de Trabajos', _buildPortfolio(user)),
                        _buildSection('Opiniones de Clientes', _buildReviews(user)),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ),
              bottomSheet: _buildBottomActions(user),
            );
          }
        );
      },
    );
  }

  Widget _buildAppBar(UserModel user, bool isFavorite, String currentUserId) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: darkColor,
      leading: IconButton(
        icon: const CircleAvatar(
          backgroundColor: Colors.black26,
          child: Icon(Icons.arrow_back, color: Colors.white),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: CircleAvatar(
            backgroundColor: Colors.black26,
            child: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border, 
              color: isFavorite ? Colors.red : Colors.white
            ),
          ),
          onPressed: () => _toggleFavorite(currentUserId, user.id, isFavorite),
        ),
        IconButton(
          icon: const CircleAvatar(
            backgroundColor: Colors.black26,
            child: Icon(Icons.share, color: Colors.white),
          ),
          onPressed: () => Share.share('Mira el perfil de ${user.name} en FixRadar: tecnico/${user.id}'),
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (user.profileImageUrl.isNotEmpty)
              Image.network(user.profileImageUrl, fit: BoxFit.cover)
            else
              Container(color: darkColor, child: const Icon(Icons.person, size: 80, color: Colors.white24)),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainInfo(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        if (user.role == 'technician')
                          const Icon(Icons.verified, color: Colors.blue, size: 20),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.specialties.isNotEmpty ? user.specialties.first : 'Especialista General',
                      style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (user.companyName != null && user.companyName!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(user.companyName!, style: TextStyle(color: Colors.grey[600])),
                      ),
                  ],
                ),
              ),
              _buildStatusChip(user),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.history, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text('${user.yearsOfExperience} años de experiencia', style: TextStyle(color: Colors.grey[600])),
              const SizedBox(width: 16),
              Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(user.city.isNotEmpty ? user.city : 'Sin ciudad', style: TextStyle(color: Colors.grey[600])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(UserModel user) {
    Color color;
    String label;
    IconData icon;

    if (user.isOnline) {
      if (user.presenceStatus == 'busy') {
        color = Colors.orange;
        label = 'Ocupado';
        icon = Icons.access_time;
      } else {
        color = Colors.green;
        label = 'Disponible';
        icon = Icons.check_circle;
      }
    } else {
      color = Colors.grey;
      label = 'Fuera de línea';
      icon = Icons.offline_bolt;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildStats(UserModel user) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 20),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            _statCard('Calificación', '${user.rating.toStringAsFixed(1)} ⭐', 'Promedio'),
            _statCard('Reseñas', '${user.reviewsCount}', 'Opiniones'),
            _statCard('Trabajos', '${user.completedJobsCount}', 'Completados'),
            _statCard('Respuesta', user.avgResponseTime ?? 'Rápida', 'Tiempo prom.'),
            _statCard('Satisfacción', '${user.satisfactionPercentage.toInt()}%', 'Clientes felices'),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, String subtitle) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _buildAbout(UserModel user) {
    return Text(
      user.bio.isNotEmpty ? user.bio : 'Este técnico aún no ha agregado una descripción profesional.',
      style: TextStyle(color: Colors.grey[700], height: 1.5),
    );
  }

  Widget _buildSpecialties(UserModel user) {
    if (user.specialties.isEmpty) {
      return const Text('Sin especialidades registradas.', style: TextStyle(color: Colors.grey));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: user.specialties.map((spec) => Chip(
        label: Text(spec),
        backgroundColor: primaryColor.withOpacity(0.1),
        side: BorderSide(color: primaryColor.withOpacity(0.2)),
        labelStyle: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 12),
      )).toList(),
    );
  }

  Widget _buildVerifications(UserModel user) {
    return Column(
      children: [
        // Verifications
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _verifItem(Icons.badge, 'ID', user.idVerified),
            _verifItem(Icons.phone_android, 'Teléfono', user.phoneVerified),
            _verifItem(Icons.email, 'Email', user.emailVerified),
            _verifItem(Icons.description, 'Licencia', user.licenseVerified),
            _verifItem(Icons.security, 'Seguro', user.insuranceVerified),
          ],
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        // Badges
        const Text('Insignias de Reputación', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            if (user.rating >= 4.8) _reputationBadge(Icons.star, 'Top Técnico', Colors.amber),
            _reputationBadge(Icons.speed, 'Respuesta Rápida', Colors.blue),
            if (user.idVerified) _reputationBadge(Icons.verified_user, 'Verificado', Colors.green),
            if (user.completedJobsCount > 100) _reputationBadge(Icons.workspace_premium, '100+ Trabajos', Colors.purple),
          ],
        ),
      ],
    );
  }

  Widget _verifItem(IconData icon, String label, bool isVerified) {
    return Column(
      children: [
        Icon(icon, color: isVerified ? Colors.green : Colors.grey[300], size: 28),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: isVerified ? Colors.black87 : Colors.grey)),
        if (isVerified)
          const Icon(Icons.check_circle, size: 10, color: Colors.green),
      ],
    );
  }

  Widget _reputationBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildBusinessInfo(UserModel user) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 2.5,
      children: [
        _bizItem(Icons.request_quote_outlined, 'Presupuesto Gratis', user.freeQuote ? 'SÍ' : 'Consultar'),
        _bizItem(Icons.emergency_outlined, 'Emergencias 24/7', user.emergencyService ? 'SÍ' : 'NO'),
        _bizItem(Icons.schedule, 'Horario', user.workHours ?? 'No especificado'),
        _bizItem(Icons.event_available, 'Fines de semana', user.weekendAvailability ? 'Disponible' : 'Cerrado'),
      ],
    );
  }

  Widget _bizItem(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: primaryColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceArea(UserModel user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.location_city, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text('${user.city.isNotEmpty ? user.city : 'Área'} - Radio de ${user.serviceRadius.toInt()} km'),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.grey[200],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: user.latitude != null 
              ? GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(user.latitude!, user.longitude!),
                    zoom: 11,
                  ),
                  circles: {
                    Circle(
                      circleId: const CircleId('service_area'),
                      center: LatLng(user.latitude!, user.longitude!),
                      radius: user.serviceRadius * 1000,
                      fillColor: primaryColor.withOpacity(0.2),
                      strokeColor: primaryColor,
                      strokeWidth: 2,
                    ),
                  },
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                )
              : const Center(child: Text('Ubicación no disponible')),
          ),
        ),
      ],
    );
  }

  Widget _buildPortfolio(UserModel user) {
    return StreamBuilder<List<PortfolioItem>>(
      stream: _firestoreService.getPortfolio(user.id),
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const Text('No hay trabajos en el portafolio todavía.', style: TextStyle(color: Colors.grey));
        }
        return SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return GestureDetector(
                onTap: () => _showPortfolioDetail(item),
                child: Container(
                  width: 250,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white,
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: item.thumbnailUrls.isNotEmpty 
                          ? Image.network(item.thumbnailUrls.first, height: 120, width: double.infinity, fit: BoxFit.cover)
                          : (item.imageUrls.isNotEmpty 
                              ? Image.network(item.imageUrls.first, height: 120, width: double.infinity, fit: BoxFit.cover)
                              : Container(height: 120, color: Colors.grey[300], child: const Icon(Icons.image))),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(item.category, style: TextStyle(color: primaryColor, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildReviews(UserModel user) {
    return StreamBuilder<List<ReviewModel>>(
      stream: _firestoreService.getTechnicianReviews(user.id),
      builder: (context, snapshot) {
        final reviews = snapshot.data ?? [];
        if (reviews.isEmpty) {
          return const Text('Aún no tiene opiniones de clientes.', style: TextStyle(color: Colors.grey));
        }
        return Column(
          children: reviews.take(5).map((rev) => Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: rev.clientPhotoUrl != null ? NetworkImage(rev.clientPhotoUrl!) : null,
                      child: rev.clientPhotoUrl == null ? const Icon(Icons.person, size: 18) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(rev.clientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(DateFormat('dd MMM yyyy').format(rev.createdAt), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                    ),
                    Row(
                      children: List.generate(5, (index) => Icon(
                        Icons.star, 
                        size: 14, 
                        color: index < rev.rating ? Colors.amber : Colors.grey[300]
                      )),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(rev.comment, style: TextStyle(color: Colors.grey[800], fontSize: 13, height: 1.4)),
              ],
            ),
          )).toList(),
        );
      },
    );
  }

  Widget _buildBottomActions(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            _circleAction(Icons.phone, Colors.green, () => _launchURL('tel:${user.phoneNumber ?? ""}')),
            const SizedBox(width: 12),
            _circleAction(Icons.chat_bubble_outline, primaryColor, () {
              // Usually needs a request context, but we can open a generic chat or handle via route
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Iniciando chat directo...')));
            }),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.publish, arguments: user.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Solicitar Cotización', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleAction(IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          child: Icon(icon, color: color),
        ),
      ),
    );
  }

  void _showPortfolioDetail(PortfolioItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              Text(item.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(item.category, style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text(item.description, style: const TextStyle(fontSize: 16, height: 1.5)),
              const SizedBox(height: 24),
              const Text('Galería de fotos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              // High-res images gallery
              ...item.imageUrls.map((url) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(url, fit: BoxFit.cover),
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  void _toggleFavorite(String currentUserId, String techId, bool isFavorite) async {
    try {
      await _firestoreService.toggleFavoriteTechnician(currentUserId, techId, isFavorite);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFavorite ? 'Eliminado de favoritos' : 'Guardado en favoritos'),
            duration: const Duration(seconds: 2),
            action: SnackBarAction(label: 'Cerrar', onPressed: () {}, textColor: Colors.white),
          ),
        );
      }
    } catch (e) {
      print('Error toggleFavorite: $e');
    }
  }
}
