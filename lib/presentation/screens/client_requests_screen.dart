import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/service_request.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/config/routes.dart';

class ClientRequestsScreen extends StatefulWidget {
  final Function(ServiceRequest)? onViewMap;
  const ClientRequestsScreen({super.key, this.onViewMap});

  @override
  State<ClientRequestsScreen> createState() => _ClientRequestsScreenState();
}

class _ClientRequestsScreenState extends State<ClientRequestsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final String _currentUserId = AuthService.currentUidSync;
  Stream<List<ServiceRequest>>? _requestsStream;

  @override
  void initState() {
    super.initState();
    _requestsStream = _firestoreService.getClientRequests(_currentUserId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Mis Pedidos', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<List<ServiceRequest>>(
        stream: _requestsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFF8A00)));
          }

          final allRequests = snapshot.data ?? [];
          
          // Filter out cancelled and completed from THIS specific view
          final requests = allRequests.where((r) => 
            r.status != ServiceRequestStatus.cancelled && 
            r.status != ServiceRequestStatus.completed
          ).toList();

          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text('Aún no has publicado pedidos', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.publish),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF8A00)),
                    child: const Text('Publicar primer pedido', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return _buildRequestCard(request);
            },
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(ServiceRequest request) {
    final bool hasUnread = request.lastMessageBy != null && 
                          request.lastMessageBy != _currentUserId &&
                          (request.chatLastReadBy[_currentUserId] == null ||
                           (request.lastMessageAt != null && 
                            (request.chatLastReadBy[_currentUserId] as dynamic).toDate().isBefore(request.lastMessageAt!)));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.pushNamed(context, AppRoutes.requestDetail, arguments: request);
          if (result == true && mounted) {
            // Force a refresh if something was changed in the detail screen (like cancellation)
            setState(() {
              _requestsStream = _firestoreService.getClientRequests(_currentUserId);
            });
          } else if (result is ServiceRequest && mounted) {
            widget.onViewMap?.call(result);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _statusChip(request.status),
                      const SizedBox(width: 8),
                      if (request.status == ServiceRequestStatus.completed || request.status == ServiceRequestStatus.cancelled)
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          onPressed: () => _showDeleteConfirmation(request),
                        ),
                    ],
                  ),
                  Text(
                    DateFormat('dd MMM').format(request.createdAt),
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          request.description,
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (request.thumbnailUrls.isNotEmpty || request.imageUrls.isNotEmpty)
                    Container(
                      width: 60,
                      height: 60,
                      margin: const EdgeInsets.only(left: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: NetworkImage(request.thumbnailUrls.isNotEmpty ? request.thumbnailUrls[0] : request.imageUrls[0]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (request.status == ServiceRequestStatus.finishedByTechnician)
                _buildFinishedActions(request)
              else
                Row(
                  children: [
                    if (request.technicianId != null) ...[
                      const Icon(Icons.engineering_outlined, size: 16, color: Colors.green),
                      const SizedBox(width: 4),
                      const Text(
                        'Técnico trabajando',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ] else if (request.responsesCount > 0) ...[
                    const Icon(Icons.people_outline, size: 16, color: Color(0xFFFF8A00)),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => Navigator.pushNamed(context, AppRoutes.techniciansList, arguments: request),
                      child: Text(
                        '${request.responsesCount} técnicos interesados',
                        style: const TextStyle(color: Color(0xFFFF8A00), fontWeight: FontWeight.bold, fontSize: 13, decoration: TextDecoration.underline),
                      ),
                    ),
                  ] else ...[
                    const Icon(Icons.timer_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    const Text('Buscando técnicos...', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                  const Spacer(),
                  if (request.status == ServiceRequestStatus.assigned || request.status == ServiceRequestStatus.inProgress)
                    Stack(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pushNamed(context, AppRoutes.chat, arguments: request),
                          icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFFFF8A00)),
                        ),
                        if (hasUnread)
                          Positioned(
                            right: 10,
                            top: 10,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(color: Color(0xFFFF8A00), shape: BoxShape.circle),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinishedActions(ServiceRequest request) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'El técnico marcó el trabajo como finalizado.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.chat, arguments: request),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.blue),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Chat', style: TextStyle(color: Colors.blue, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _confirmAcceptCompletion(request),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: const Text('Confirmar', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmAcceptCompletion(ServiceRequest request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Confirmar finalización?'),
        content: const Text('Al confirmar, el pedido se cerrará definitivamente y podrás calificar al técnico.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Revisar más')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _firestoreService.updateRequestStatus(request.id, ServiceRequestStatus.completed);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('¡Trabajo completado con éxito! Por favor, califica al técnico.'))
                  );
                  // Optionally navigate to details to trigger review dialog
                  Navigator.pushNamed(context, AppRoutes.requestDetail, arguments: request);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Sí, confirmar', style: TextStyle(color: Colors.white)),
          ),
        ],
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

  Widget _statusChip(ServiceRequestStatus status) {
    Color color;
    String label;
    switch (status) {
      case ServiceRequestStatus.open:
        color = Colors.orange;
        label = 'Abierto';
        break;
      case ServiceRequestStatus.assigned:
        color = Colors.blue;
        label = 'Asignado';
        break;
      case ServiceRequestStatus.inProgress:
        color = Colors.indigo;
        label = 'En curso';
        break;
      case ServiceRequestStatus.finishedByTechnician:
        color = Colors.blue;
        label = 'Por validar';
        break;
      case ServiceRequestStatus.completed:
        color = Colors.green;
        label = 'Completado';
        break;
      case ServiceRequestStatus.cancelled:
        color = Colors.red;
        label = 'Cancelado';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
