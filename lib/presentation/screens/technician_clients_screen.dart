// Migrated: Firestore replaced by MongoDB+Socket.io via FirestoreService facade
import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
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
  String _currentUserId = '';
  Stream<List<Quote>>? _quotesStream;
  Stream<List<ServiceRequest>>? _historyStream;

  @override
  void initState() {
    super.initState();
    _currentUserId = AuthService.currentUidSync;
    _initStreams();
  }

  void _initStreams() {
    if (_currentUserId.isNotEmpty) {
      _quotesStream = _firestoreService.getQuotesForTechnician(_currentUserId);
      _historyStream = _firestoreService.getTechnicianHistory(_currentUserId);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId.isEmpty) {
      // In case it was empty at initState, try to get it again
      _currentUserId = AuthService.currentUidSync;
      if (_currentUserId.isNotEmpty) _initStreams();
    }

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
            onPressed: () => setState(() {
              _initStreams();
            }),
          ),
        ],
      ),
      body: _currentUserId.isEmpty 
        ? const Center(child: Text('Inicia sesión para ver tus clientes.'))
        : StreamBuilder<List<Quote>>(
            stream: _quotesStream,
            builder: (context, quotesSnapshot) {
              final List<Quote> myQuotes = quotesSnapshot.data ?? [];
              
              return StreamBuilder<List<ServiceRequest>>(
                stream: _historyStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _buildErrorState(snapshot.error.toString());
                  }

                  if (snapshot.connectionState == ConnectionState.waiting || quotesSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFFFF8A00)));
                  }

                  final allMatchingRequests = snapshot.data ?? [];
                  
                  // Filter requests based on my status
                  final activeRequests = allMatchingRequests.where((req) {
                    // 1. Jobs assigned to me
                    if (req.technicianId == _currentUserId && 
                       (req.status == ServiceRequestStatus.assigned || 
                        req.status == ServiceRequestStatus.inProgress || 
                        req.status == ServiceRequestStatus.finishedByTechnician)) {
                      return true;
                    }
                    // 2. Jobs where I have a pending quote
                    final myQuote = myQuotes.firstWhere((q) => q.requestId == req.id, orElse: () => Quote(id: '', requestId: '', clientId: '', technicianId: '', technicianName: '', technicianRating: 5, minPrice: 0, maxPrice: 0, message: '', createdAt: DateTime.now()));
                    if (req.status == ServiceRequestStatus.open && myQuote.status == QuoteStatus.pending) {
                      return true;
                    }
                    return false;
                  }).toList();

                  final historyRequests = allMatchingRequests.where((req) {
                    return !activeRequests.any((active) => active.id == req.id);
                  }).toList();

                  if (activeRequests.isEmpty && historyRequests.isEmpty) {
                    return _buildEmptyState();
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
                              _buildRequestList(activeRequests, myQuotes, _currentUserId),
                              _buildRequestList(historyRequests, myQuotes, _currentUserId),
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

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            const Text('Error al cargar clientes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: () => setState(() {}), child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
                              _buildRequestList(activeRequests, myQuotes, _currentUserId),
                              _buildRequestList(historyRequests, myQuotes, _currentUserId),
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
      if (request.lastMessageBy != null && request.lastMessageBy != currentUserId) {
        final dynamic lastRead = request.chatLastReadBy[currentUserId];
        final DateTime? lastMessageAt = request.lastMessageAt;
        
        if (lastRead == null) {
          hasUnread = true;
        } else if (lastMessageAt != null) {
          DateTime lastReadDate;
          if (lastRead is DateTime) {
            lastReadDate = lastRead;
          } else if (lastRead is String) {
             lastReadDate = DateTime.tryParse(lastRead) ?? DateTime(2000);
          } else {
            lastReadDate = DateTime(2000);
          }
          hasUnread = lastReadDate.isBefore(lastMessageAt);
        }
      }
    } catch (e) {
      print('Error calculating unread: $e');
    }

    final String? photoUrl = (request.clientPhotoUrl != null && request.clientPhotoUrl!.isNotEmpty) 
        ? request.clientPhotoUrl 
        : null;

    final String clientName = request.clientName;
    final String jobTitle = request.title;
    final String jobAddress = request.address;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                      backgroundColor: Colors.grey[100],
                      child: photoUrl == null ? const Icon(Icons.person, color: Colors.grey) : null,
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
                      CategoryBadge(category: request.category, fontSize: 10),
                      const SizedBox(height: 8),
                      Text(
                        jobTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: _buildActionRow(request, myQuote, currentUserId),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(ServiceRequest request, Quote myQuote, String currentUserId) {
    final bool isAssigned = request.technicianId == currentUserId;
    final bool isRejected = myQuote.status == QuoteStatus.rejected || myQuote.status == QuoteStatus.final_rejected;

    if (isRejected) {
      return Row(
        children: [
          const SizedBox(width: 8),
          const Text('❌ Propuesta Rechazada', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
          const Spacer(),
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.chat, arguments: request),
            icon: const Icon(Icons.history, size: 18),
            label: const Text('Ver Chat'),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
          ),
        ],
      );
    }

    return Row(
      children: [
        TextButton.icon(
          onPressed: () => Navigator.pushNamed(context, AppRoutes.requestDetail, arguments: request),
          icon: const Icon(Icons.visibility_outlined, size: 18),
          label: const Text('Ver Detalle'),
        ),
        const Spacer(),
        if (isAssigned && (request.status == ServiceRequestStatus.assigned || request.status == ServiceRequestStatus.inProgress)) ...[
          IconButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.chat, arguments: request),
            icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFFFF8A00)),
            tooltip: 'Chat con cliente',
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: () => _confirmFinishWork(request),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Finalizar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ] else if (request.status == ServiceRequestStatus.open) ...[
          TextButton.icon(
            onPressed: () => _confirmWithdrawQuote(request, currentUserId),
            icon: const Icon(Icons.close, color: Colors.red, size: 18),
            label: const Text('Retirar', style: TextStyle(color: Colors.red)),
          ),
        ],
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
