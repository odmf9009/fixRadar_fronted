import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../core/models/service_request.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/language_service.dart';
import '../../core/services/view_mode_service.dart';
import '../../core/config/routes.dart';

// Identificadores estables de las pestañas (independientes del idioma/lente).
enum _PostFilter { active, middle, finished }

class MyPostsScreen extends StatefulWidget {
  const MyPostsScreen({super.key});

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  _PostFilter _activeFilter = _PostFilter.active;
  final String _currentUserId = AuthService.currentUidSync;

  /// Vista profesional ("Trabajar") = "Mis trabajos". Si no, vista de cliente
  /// ("Necesito ayuda" o cuenta cliente) = "Mis pedidos".
  bool get _isProView => ViewModeService.instance.isProLens;

  /// ¿El pedido cuenta como "activo" (asignado y en curso, no terminado)?
  bool _isActive(ServiceRequest p) =>
      p.status == ServiceRequestStatus.assigned ||
      p.status == ServiceRequestStatus.inProgress ||
      p.status == ServiceRequestStatus.finishedByTechnician;

  List<ServiceRequest> _filter(List<ServiceRequest> all) {
    if (_isProView) {
      // Mis trabajos (técnico):
      switch (_activeFilter) {
        case _PostFilter.active:
          // Activos: el cliente aprobó mi propuesta (asignado a mí) y aún no se ha terminado.
          return all.where((p) => p.technicianId == _currentUserId && _isActive(p)).toList();
        case _PostFilter.middle: // Pendientes
          // Pendientes: envié propuesta pero el cliente aún no la ha aprobado (sigue abierto).
          // El historial del técnico solo trae pedidos donde tengo cotización/interés,
          // así que un pedido 'open' aquí = mi propuesta está pendiente de aprobación.
          return all.where((p) => p.status == ServiceRequestStatus.open).toList();
        case _PostFilter.finished:
          // Finalizadas: las que ya se completaron y fueron mías.
          return all.where((p) => p.status == ServiceRequestStatus.completed && p.technicianId == _currentUserId).toList();
      }
    } else {
      // Mis pedidos (cliente):
      switch (_activeFilter) {
        case _PostFilter.active:
          return all.where(_isActive).toList();
        case _PostFilter.middle: // Pendientes
          // Me enviaron cotización(es) y no he aprobado ninguna: sigue abierto.
          return all.where((p) => p.status == ServiceRequestStatus.open).toList();
        case _PostFilter.finished:
          return all.where((p) => p.status == ServiceRequestStatus.completed).toList();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([LanguageService(), ViewModeService.instance]),
      builder: (context, _) {
        final bool pro = _isProView;
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              pro ? tr('my_jobs') : tr('my_orders'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFF121212),
            elevation: 0,
            centerTitle: true,
          ),
          body: Column(
            children: [
              // Filter Tabs
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    _buildFilterTab(_PostFilter.active, tr('tab_active')),
                    const SizedBox(width: 10),
                    // Tab central: Pendientes (propuesta enviada sin aprobar) en ambos lentes.
                    _buildFilterTab(_PostFilter.middle, tr('tab_pending')),
                    const SizedBox(width: 10),
                    _buildFilterTab(_PostFilter.finished, tr('tab_finished')),
                  ],
                ),
              ),

              // Posts List
              Expanded(
                child: StreamBuilder<List<ServiceRequest>>(
                  stream: pro
                      ? _firestoreService.getTechnicianHistory(_currentUserId)
                      : _firestoreService.getClientRequests(_currentUserId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF8A00)));
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    final filteredPosts = _filter(snapshot.data ?? []);

                    if (filteredPosts.isEmpty) {
                      return Center(
                        child: Text(
                          tr('no_items_category'),
                          style: const TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: filteredPosts.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
                      itemBuilder: (context, index) {
                        final post = filteredPosts[index];
                        return _buildPostItem(post);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterTab(_PostFilter filter, String label) {
    final isSelected = _activeFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF8A00) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF8A00) : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildPostItem(ServiceRequest post) {
    Color statusColor;
    String statusText;
    
    switch (post.status) {
      case ServiceRequestStatus.open:
        statusColor = const Color(0xFF4CAF50);
        statusText = 'Buscando técnico';
        break;
      case ServiceRequestStatus.assigned:
        statusColor = const Color(0xFF2196F3);
        statusText = 'Técnico asignado';
        break;
      case ServiceRequestStatus.inProgress:
        statusColor = Colors.orange;
        statusText = 'En reparación';
        break;
      case ServiceRequestStatus.finishedByTechnician:
        statusColor = Colors.blue;
        statusText = 'Por validar';
        break;
      case ServiceRequestStatus.completed:
        statusColor = Colors.grey;
        statusText = 'Finalizado';
        break;
      case ServiceRequestStatus.cancelled:
        statusColor = Colors.red;
        statusText = 'Cancelado';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Estado desconocido';
        break;
    }

    return InkWell(
      onTap: () => Navigator.pushNamed(context, AppRoutes.requestDetail, arguments: post),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Image
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: post.thumbnailUrls.isNotEmpty
                    ? Image.network(post.thumbnailUrls[0], fit: BoxFit.cover)
                    : (post.imageUrls.isNotEmpty 
                        ? Image.network(post.imageUrls[0], fit: BoxFit.cover)
                        : const Icon(Icons.image, color: Colors.grey)),
              ),
            ),
            const SizedBox(width: 16),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Categoría: ${post.category}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            // Delete Option
            if (post.status == ServiceRequestStatus.completed || post.status == ServiceRequestStatus.cancelled)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _showDeleteConfirmation(post),
              ),

            // Arrow
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(ServiceRequest request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar pedido', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('¿Estás seguro de que deseas eliminar "${request.title}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _firestoreService.deleteServiceRequest(request.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pedido eliminado correctamente')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
