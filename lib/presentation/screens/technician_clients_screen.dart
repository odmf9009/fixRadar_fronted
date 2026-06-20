// Migrated: Firestore replaced by MongoDB+Socket.io via FirestoreService facade
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/auth_service.dart';
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
    _checkAuthAndInit();
  }

  void _checkAuthAndInit() {
    final uid = AuthService.currentUidSync;
    if (uid.isNotEmpty) {
      setState(() {
        _currentUserId = uid;
        _initStreams();
      });
    }
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
      final uid = AuthService.currentUidSync;
      if (uid.isNotEmpty) {
        Future.microtask(() {
          if (mounted) {
            setState(() {
              _currentUserId = uid;
              _initStreams();
            });
          }
        });
      }
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
            onPressed: () {
              _checkAuthAndInit();
              setState(() {
                _initStreams();
              });
            },
          ),
        ],
      ),
      body: _currentUserId.isEmpty 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF8A00)))
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

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFFFF8A00)));
                  }

                  final allRequests = snapshot.data ?? [];
                  
                  final activeRequests = <ServiceRequest>[];
                  final historyRequests = <ServiceRequest>[];

                  for (final req in allRequests) {
                    final String reqId = req.id.toString();
                    final myQuote = myQuotes.firstWhere(
                      (q) => q.requestId.toString() == reqId, 
                      orElse: () => Quote(id: '', requestId: reqId, clientId: '', technicianId: '', technicianName: '', technicianRating: 5, minPrice: 0, maxPrice: 0, message: '', createdAt: DateTime.now())
                    );
                    
                    bool isActive = false;

                    // A request is active if it's NOT completed and NOT cancelled,
                    // AND the technician is involved in it.
                    if (req.status != ServiceRequestStatus.completed && 
                        req.status != ServiceRequestStatus.cancelled) {
                      
                      // 1. Technician is assigned in the request object
                      if (req.technicianId?.toString() == _currentUserId) {
                        isActive = true;
                      } 
                      // 2. Technician's quote was accepted
                      else if (myQuote.status == QuoteStatus.accepted) {
                        isActive = true;
                      }
                      // 3. Technician sent a quote and request is still open
                      else if (req.status == ServiceRequestStatus.open && 
                               (myQuote.id.isNotEmpty || req.interestedTechnicians.contains(_currentUserId))) {
                        isActive = true;
                      }
                    }

                    if (isActive) {
                      activeRequests.add(req);
                    } else {
                      historyRequests.add(req);
                    }
                  }

                  // Sort active requests: assigned/inProgress first
                  activeRequests.sort((a, b) {
                    if (a.status == ServiceRequestStatus.inProgress && b.status != ServiceRequestStatus.inProgress) return -1;
                    if (a.status != ServiceRequestStatus.inProgress && b.status == ServiceRequestStatus.inProgress) return 1;
                    if (a.status == ServiceRequestStatus.assigned && b.status != ServiceRequestStatus.assigned) return -1;
                    if (a.status != ServiceRequestStatus.assigned && b.status == ServiceRequestStatus.assigned) return 1;
                    return b.updatedAt.compareTo(a.updatedAt);
                  });

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

  Widget _buildRequestList(List<ServiceRequest> requests, List<Quote> myQuotes, String currentUserId) {
    if (requests.isEmpty) {
      return const Center(child: Text('No hay elementos en esta lista.', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index];
        final String reqId = req.id.toString();
        final myQuote = myQuotes.firstWhere(
          (q) => q.requestId.toString() == reqId, 
          orElse: () => Quote(id: '', requestId: reqId, clientId: '', technicianId: '', technicianName: '', technicianRating: 5, minPrice: 0, maxPrice: 0, message: '', createdAt: DateTime.now())
        );
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

    final String? photoUrl = (request.clientPhotoUrl != null && request.clientPhotoUrl!.toString().isNotEmpty) 
        ? request.clientPhotoUrl!.toString() 
        : null;

    final String clientName = request.clientName;
    final String jobTitle = request.title;
    final String jobAddress = request.address;
    
    // Use request.budget as primary price (accepted price)
    final double acceptedPrice = request.budget ?? myQuote.price ?? myQuote.minPrice;
    
    // Acceptance date
    final DateTime? dateToShow = request.assignedAt ?? myQuote.statusUpdatedAt ?? request.updatedAt;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
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
                      Row(
                        children: [
                          CategoryBadge(category: request.category, fontSize: 10),
                          if (acceptedPrice > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '\$${acceptedPrice.toStringAsFixed(0)}',
                                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        jobTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (dateToShow != null)
                        Text(
                          'Actualizado: ${DateFormat('dd/MM/yyyy HH:mm').format(dateToShow)}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 11),
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
    final bool isAssigned = request.technicianId?.toString() == currentUserId || myQuote.status == QuoteStatus.accepted;
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
          label: const Text('Ver detalle'),
        ),
        const Spacer(),
        if (isAssigned && (request.status == ServiceRequestStatus.assigned || request.status == ServiceRequestStatus.inProgress || myQuote.status == QuoteStatus.accepted)) ...[
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
            child: const Text('Finalizar trabajo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
        content: const Text('¿Confirmas que ya terminaste este trabajo? El cliente recibirá una notificación y el pedido pasará al historial.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Aún no')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _firestoreService.finishWorkByTechnician(request.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Trabajo completado con éxito. Pasando al historial.'))
                  );
                  // Refresh streams
                  setState(() {
                    _initStreams();
                  });
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
      } else if (myQuote.status == QuoteStatus.accepted || status == ServiceRequestStatus.assigned || status == ServiceRequestStatus.inProgress) {
        badgeColor = Colors.green;
        badgeLabel = 'Trabajando';
      } else {
        switch (status) {
          case ServiceRequestStatus.open:
            badgeColor = Colors.orange;
            badgeLabel = 'Propuesta enviada';
            break;
          case ServiceRequestStatus.finishedByTechnician:
            badgeColor = Colors.blue;
            badgeLabel = 'Por validar';
            break;
          case ServiceRequestStatus.completed:
            badgeColor = Colors.grey;
            badgeLabel = 'Completado';
            break;
          case ServiceRequestStatus.cancelled:
            badgeColor = Colors.red;
            badgeLabel = 'Cancelado';
            break;
          default:
            badgeColor = Colors.grey;
            badgeLabel = status.name;
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
}
