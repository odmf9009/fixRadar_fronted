// Migrated: Firestore replaced by MongoDB+Socket.io via FirestoreService facade
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../core/models/service_request.dart';
import '../../core/models/quote_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/language_service.dart';
import '../../core/config/routes.dart';
import 'widgets/category_badge.dart';

class TechnicianClientsScreen extends StatefulWidget {
  final Function(ServiceRequest)? onViewMap;
  const TechnicianClientsScreen({super.key, this.onViewMap});

  @override
  State<TechnicianClientsScreen> createState() => _TechnicianClientsScreenState();
}

class _TechnicianClientsScreenState extends State<TechnicianClientsScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    
    print('BUILD_CLIENTS_SCREEN: TechUID: "$currentUserId"');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Mis Clientes', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: currentUserId.isEmpty 
        ? const Center(child: Text('Inicia sesión para ver tus clientes.'))
        : StreamBuilder<List<Quote>>(
            stream: _firestoreService.getQuotesForTechnician(currentUserId),
            builder: (context, quotesSnapshot) {
              final List<Quote> myQuotes = quotesSnapshot.data ?? [];
              
              return StreamBuilder<List<ServiceRequest>>(
                stream: _firestoreService.getTechnicianHistory(currentUserId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    print('CLIENTS_STREAM_ERROR: ${snapshot.error}');
                    return LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                                  const SizedBox(height: 16),
                                  const Text('Error al cargar clientes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                  const SizedBox(height: 8),
                                  Text(snapshot.error.toString(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                                  const SizedBox(height: 24),
                                  ElevatedButton(onPressed: () => setState(() {}), child: const Text('Reintentar')),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting || quotesSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Color(0xFFFF8A00)),
                          SizedBox(height: 16),
                          Text('Cargando clientes...', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }

                  final allMatchingRequests = snapshot.data ?? [];
                  
                  // Filter requests based on my quote status
                  // Active: accepted OR (open AND pending)
                  final activeRequests = allMatchingRequests.where((req) {
                    final myQuote = myQuotes.firstWhere((q) => q.requestId == req.id, orElse: () => Quote(id: '', requestId: '', clientId: '', technicianId: '', technicianName: '', technicianRating: 5, minPrice: 0, maxPrice: 0, message: '', createdAt: DateTime.now()));
                    
                    if (req.technicianId == currentUserId) return true; // Assigned to me
                    if (req.status == ServiceRequestStatus.open && myQuote.status == QuoteStatus.pending) return true;
                    
                    return false;
                  }).toList();

                  // History/Rejected: rejected OR cancelled OR completed (and not in active)
                  final historyRequests = allMatchingRequests.where((req) {
                    final myQuote = myQuotes.firstWhere((q) => q.requestId == req.id, orElse: () => Quote(id: '', requestId: '', clientId: '', technicianId: '', technicianName: '', technicianRating: 5, minPrice: 0, maxPrice: 0, message: '', createdAt: DateTime.now()));
                    
                    if (myQuote.status == QuoteStatus.rejected) return true;
                    if (req.status == ServiceRequestStatus.completed || req.status == ServiceRequestStatus.cancelled) return true;
                    
                    return false;
                  }).where((req) => !activeRequests.any((active) => active.id == req.id)).toList();

                  if (activeRequests.isEmpty && historyRequests.isEmpty) {
                    return LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.assignment_ind_outlined, size: 80, color: Colors.grey[300]),
                                  const SizedBox(height: 24),
                                  const Text(
                                    'No tienes trabajos actualmente.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  return DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        const TabBar(
                          labelColor: Color(0xFFFF8A00),
                          unselectedLabelColor: Colors.grey,
                          indicatorColor: Color(0xFFFF8A00),
                          tabs: [
                            Tab(text: 'Activos'),
                            Tab(text: 'Historial'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildRequestList(activeRequests, myQuotes, currentUserId),
                              _buildRequestList(historyRequests, myQuotes, currentUserId),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
    );
  }

  Widget _buildRequestList(List<ServiceRequest> requests, List<Quote> myQuotes, String currentUserId) {
    if (requests.isEmpty) {
      return const Center(child: Text('No hay elementos en esta lista.', style: TextStyle(color: Colors.grey)));
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: requests.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final req = requests[index];
        final myQuote = myQuotes.firstWhere((q) => q.requestId == req.id, orElse: () => Quote(id: '', requestId: '', clientId: '', technicianId: '', technicianName: '', technicianRating: 5, minPrice: 0, maxPrice: 0, message: '', createdAt: DateTime.now()));
        return _buildClientCard(req, myQuote, currentUserId);
      },
    );
  }

  Widget _buildClientCard(ServiceRequest request, Quote myQuote, String currentUserId) {
    bool hasUnread = false;
    try {
      final String uid = currentUserId;
      if (request.lastMessageBy != null && request.lastMessageBy != uid) {
        final dynamic lastRead = request.chatLastReadBy[uid];
        final DateTime? lastMessageAt = request.lastMessageAt;
        
        if (lastRead == null) {
          hasUnread = true;
        } else if (lastMessageAt != null) {
          DateTime lastReadDate;
          if (lastRead is Timestamp) {
            lastReadDate = lastRead.toDate();
          } else if (lastRead is DateTime) {
            lastReadDate = lastRead;
          } else {
            lastReadDate = DateTime(2000);
          }
          hasUnread = lastReadDate.isBefore(lastMessageAt);
        }
      }
    } catch (e) {
      print('Error calculating unread: $e');
    }

    // Safely get photo URL
    final String? clientPhoto = request.clientPhotoUrl;
    final String? photoUrl = (clientPhoto != null && clientPhoto.trim().isNotEmpty) 
        ? clientPhoto 
        : null;

    final String clientName = request.clientName ?? 'Cliente sin nombre';
    final String jobTitle = request.title ?? 'Sin título';
    final String jobAddress = request.address ?? 'Dirección no disponible';
    final ServiceRequestStatus? jobStatus = request.status;

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () async {
          try {
             final result = await Navigator.pushNamed(context, AppRoutes.chat, arguments: request);
             if (result is ServiceRequest && mounted) {
               widget.onViewMap?.call(result);
             }
          } catch (e) {
            print('NAVIGATION_ERROR: $e');
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: photoUrl != null 
                            ? Image.network(
                                photoUrl, 
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, color: Colors.grey),
                              )
                            : const Icon(Icons.person, color: Colors.grey),
                        ),
                      ),
                      if (hasUnread)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF8A00),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                clientName,
                                style: TextStyle(
                                  fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _statusBadge(request, myQuote),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            CategoryBadge(category: request.category, fontSize: 10),
                          ],
                        ),
                        if (myQuote.status == QuoteStatus.rejected) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Rechazada el: ${myQuote.statusUpdatedAt != null ? DateFormat('dd/MM/yyyy HH:mm').format(myQuote.statusUpdatedAt!) : _formatTime(myQuote.createdAt)}',
                            style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          jobTitle,
                          style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                jobAddress,
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (request.assignedAt != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Asignado el: ${DateFormat('dd/MM/yyyy HH:mm').format(request.assignedAt ?? DateTime.now())}',
                            style: const TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          request.lastMessageBy == currentUserId 
                            ? 'Tú: ${request.lastMessageText ?? 'Mensaje'}' 
                            : request.lastMessageText ?? 'Mensaje...', 
                          style: TextStyle(
                            color: hasUnread ? Colors.black87 : Colors.grey,
                            fontSize: 13,
                            fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildActionRow(request, myQuote, currentUserId),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionRow(ServiceRequest request, Quote myQuote, String currentUserId) {
    final String? assignedTechId = request.technicianId;
    final ServiceRequestStatus? status = request.status;

    // If my quote was rejected, I can only see the chat (history), but no more actions
    if (myQuote.status == QuoteStatus.rejected) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Text('❌ Propuesta Rechazada', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.chat, arguments: request),
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 24),
            tooltip: 'Ver historial de chat',
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Botón de Chat (Icono)
        IconButton(
          onPressed: () => Navigator.pushNamed(context, AppRoutes.chat, arguments: request),
          icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFFFF8A00), size: 24),
          tooltip: 'Chatear con cliente',
        ),
        const SizedBox(width: 8),

        // 1. Si está asignado a mí -> Botón Finalizar (Icono)
        if (assignedTechId == currentUserId && 
           (status == ServiceRequestStatus.assigned || status == ServiceRequestStatus.inProgress))
          IconButton(
            onPressed: () => _confirmFinishWork(request),
            icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 28),
            tooltip: 'Marcar como terminado',
          ),

        // 2. Si está pendiente -> Botón Retirar (Icono)
        if (status == ServiceRequestStatus.open)
          IconButton(
            onPressed: () => _confirmWithdrawQuote(request, currentUserId),
            icon: const Icon(Icons.highlight_off, color: Colors.red, size: 28),
            tooltip: 'Retirar propuesta',
          ),
      ],
    );
  }

  void _confirmFinishWork(ServiceRequest request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Finalizar trabajo?'),
        content: const Text('¿Confirmas que ya terminaste este trabajo? El cliente recibirá una notificación para validar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Aún no')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _firestoreService.finishWorkByTechnician(request.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Trabajo marcado como finalizado. Esperando validación del cliente.'))
                  );
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
            child: const Text('Sí, finalizar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmWithdrawQuote(ServiceRequest request, String currentUserId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirar propuesta'),
        content: const Text('¿Seguro que deseas retirar tu propuesta? No aparecerás más en la lista de interesados para este trabajo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _firestoreService.withdrawQuote(request.id, currentUserId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Propuesta retirada con éxito.'))
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Retirar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(ServiceRequest request, Quote myQuote) {
    Color badgeColor = Colors.grey;
    String badgeLabel = 'Desconocido';

    try {
      final ServiceRequestStatus status = request.status;
      
      if (myQuote.status == QuoteStatus.rejected) {
        badgeColor = Colors.red;
        badgeLabel = 'Rechazada';
      } else {
        switch (status) {
          case ServiceRequestStatus.open:
            badgeColor = Colors.orange;
            badgeLabel = 'Pendiente';
            break;
          case ServiceRequestStatus.assigned:
          case ServiceRequestStatus.inProgress:
            badgeColor = Colors.green;
            badgeLabel = 'Asignado';
            break;
          case ServiceRequestStatus.finishedByTechnician:
            badgeColor = Colors.blue;
            badgeLabel = 'Finalizado (Técnico)';
            break;
          case ServiceRequestStatus.completed:
            badgeColor = Colors.grey;
            badgeLabel = 'Completado';
            break;
          case ServiceRequestStatus.cancelled:
            badgeColor = Colors.red;
            badgeLabel = 'Cancelado';
            break;
        }
      }
    } catch (e) {
      print('Error in statusBadge: $e');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeColor.withOpacity(0.2)),
      ),
      child: Text(
        badgeLabel,
        style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      return DateFormat('HH:mm').format(date);
    }
    return DateFormat('dd/MM').format(date);
  }
}
