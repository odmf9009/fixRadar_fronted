import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../core/models/service_request.dart';
import '../../core/services/firestore_service.dart';
import '../../core/config/routes.dart';

class MyPostsScreen extends StatefulWidget {
  const MyPostsScreen({super.key});

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String _activeFilter = 'Activas';
  final String _currentUserId = AuthService.currentUidSync;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mis pedidos',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                _buildFilterTab('Activas'),
                const SizedBox(width: 10),
                _buildFilterTab('Historial'),
                const SizedBox(width: 10),
                _buildFilterTab('Finalizadas'),
              ],
            ),
          ),
          
          // Posts List
          Expanded(
            child: StreamBuilder<List<ServiceRequest>>(
              stream: _firestoreService.getClientRequests(_currentUserId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFFF8A00)));
                }
                
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final allPosts = snapshot.data ?? [];
                
                // Filter logic
                final filteredPosts = allPosts.where((post) {
                  if (_activeFilter == 'Activas') return post.status != ServiceRequestStatus.completed && post.status != ServiceRequestStatus.cancelled;
                  if (_activeFilter == 'Finalizadas') return post.status == ServiceRequestStatus.completed;
                  return true; // Historial shows all
                }).toList();

                if (filteredPosts.isEmpty) {
                  return const Center(
                    child: Text(
                      'No tienes pedidos en esta categoría',
                      style: TextStyle(color: Colors.grey),
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
  }

  Widget _buildFilterTab(String label) {
    final isSelected = _activeFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = label),
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
