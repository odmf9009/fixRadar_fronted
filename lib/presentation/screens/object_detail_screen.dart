import 'dart:io';
import 'dart:async';
import '../../core/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import '../../core/widgets/photo_source_picker.dart';
import '../../core/models/service_request.dart';
import '../../core/models/user_model.dart';
import '../../core/models/quote_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/upload_service.dart';
import '../../core/services/language_service.dart';
import '../../core/config/routes.dart';
import '../../core/config/service_constants.dart';

class RequestDetailScreen extends StatefulWidget {
  const RequestDetailScreen({super.key});

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  final _firestoreService = FirestoreService();
  final LocationService _locationService = LocationService();
  final UploadService _uploadService = UploadService();
  final String _currentUserId = AuthService.currentUidSync;
  
  UserModel? _currentUser;
  Quote? _myQuote;
  Quote? _selectedQuote; // Quote passed from list for client to accept
  double _distance = 0.0;
  bool _isInitialLoading = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final user = await _firestoreService.getUser(_currentUserId);
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }

    final args = ModalRoute.of(context)?.settings.arguments;
    ServiceRequest? request;
    
    if (args is ServiceRequest) {
      request = args;
    } else if (args is Map) {
      request = args['request'] as ServiceRequest?;
      _selectedQuote = args['selectedQuote'] as Quote?;
    }

    if (request != null) {
      _calculateDistance(request);
      if (user?.role == 'technician') {
        final quote = await _firestoreService.getQuoteByTechnician(request.id, _currentUserId);
        if (mounted) setState(() => _myQuote = quote);
      }
    }
    
    if (mounted) setState(() => _isInitialLoading = false);
  }

  void _calculateDistance(ServiceRequest request) async {
    final pos = await _locationService.getCurrentLocation();
    if (pos != null) {
      final d = Geolocator.distanceBetween(pos.latitude, pos.longitude, request.latitude, request.longitude);
      if (mounted) setState(() => _distance = d / 1609.34);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    ServiceRequest? initialRequest;
    
    if (args is ServiceRequest) {
      initialRequest = args;
    } else if (args is Map) {
      initialRequest = args['request'] as ServiceRequest?;
    }

    if (initialRequest == null) return Scaffold(body: Center(child: Text(tr('error_order_not_found'))));

    final ServiceRequest actualInitialRequest = initialRequest!;

    return StreamBuilder<ServiceRequest?>(
      stream: _firestoreService.getServiceRequestStream(actualInitialRequest.id),
      initialData: actualInitialRequest,
      builder: (context, snapshot) {
        final ServiceRequest request = snapshot.data ?? actualInitialRequest;
        final bool isClient = request.clientId == _currentUserId;
        final bool isTechnician = _currentUser?.role == 'technician';

        return Scaffold(
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  _buildSliverAppBar(request),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(request),
                          const SizedBox(height: 24),
                          _buildDescription(request),
                          const SizedBox(height: 24),
                          if (_completionPhotos(request).isNotEmpty &&
                              (request.status == ServiceRequestStatus.finishedByTechnician ||
                                  request.status == ServiceRequestStatus.completed)) ...[
                            _buildCompletionPhoto(request),
                            const SizedBox(height: 24),
                          ],
                          if (request.status == ServiceRequestStatus.assigned || request.status == ServiceRequestStatus.inProgress || request.status == ServiceRequestStatus.finishedByTechnician) ...[
                            _buildAcceptedBudget(request),
                            const SizedBox(height: 16),
                            _buildAssignedTechnicianCard(request),
                          ],
                          if (isClient && _selectedQuote != null && request.status == ServiceRequestStatus.open)
                            _buildSelectedQuoteBanner(request),
                          const SizedBox(height: 32),
                          _buildInformationSection(),
                          const SizedBox(height: 40),
                          if (!_isInitialLoading) _buildActionButton(request, isClient, isTechnician),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_isLoading)
                Container(
                  color: Colors.black26,
                  child: const Center(child: CircularProgressIndicator(color: Color(0xFFFF8A00))),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSelectedQuoteBanner(ServiceRequest request) {
    if (_selectedQuote == null) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: _selectedQuote!.technicianPhotoUrl != null 
                  ? NetworkImage(_selectedQuote!.technicianPhotoUrl!) 
                  : null,
                child: _selectedQuote!.technicianPhotoUrl == null ? const Icon(Icons.person) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('proposal_from').replaceAll('{name}', _selectedQuote!.technicianName),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      _selectedQuote!.minPrice == _selectedQuote!.maxPrice
                          ? tr('budget_label').replaceAll('{amount}', '${_selectedQuote!.minPrice.toInt()}')
                          : tr('range_label').replaceAll('{min}', '${_selectedQuote!.minPrice.toInt()}').replaceAll('{max}', '${_selectedQuote!.maxPrice.toInt()}'),
                      style: TextStyle(color: Colors.blue[700], fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_selectedQuote!.message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _selectedQuote!.message,
              style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _confirmAcceptQuote(request, _selectedQuote!),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(tr('accept_quote'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmAcceptQuote(ServiceRequest request, Quote quote) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('confirm_assignment')),
        content: Text(tr('hire_confirm').replaceAll('{name}', quote.technicianName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('cancel'))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                await _firestoreService.acceptQuote(request.id, quote);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(tr('tech_assigned')))
                  );
                  setState(() => _selectedQuote = null);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${tr('error_label')}: $e'), backgroundColor: Colors.red)
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF8A00)),
            child: Text(tr('confirm'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(ServiceRequest request) {
    return SliverAppBar(
      expandedHeight: 350,
      pinned: true,
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.arrow_back, color: Colors.black)),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            request.imageUrls.isNotEmpty
              ? Image.network(request.imageUrls[0], fit: BoxFit.cover)
              : Container(color: Colors.grey[200], child: const Icon(Icons.image, size: 100, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ServiceRequest request) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(20)),
              child: Text(ServiceConstants.getDisplayName(request.category).toUpperCase(), style: TextStyle(color: Colors.blue[700], fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            _buildStatusBadge(request.status),
          ],
        ),
        const SizedBox(height: 16),
        Text(request.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          tr('posted_ago_distance').replaceAll('{time}', _getTimeAgo(request.createdAt)).replaceAll('{dist}', _distance.toStringAsFixed(1)),
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () {
            // How to reach the map from here? 
            // We can pop until home and then switch tab.
            // Or use a global notification/event system.
            // For now, let's use a simpler approach if possible.
            // But usually this means navigating back and telling the main screen to switch.
            Navigator.pop(context, request);
          },
          child: Row(
            children: [
              const Icon(Icons.map_outlined, size: 16, color: Color(0xFFFF8A00)),
              const SizedBox(width: 4),
              Text(
                tr('view_location_map'),
                style: TextStyle(color: const Color(0xFFFF8A00), fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(ServiceRequestStatus status) {
    Color color;
    String text;
    switch (status) {
      case ServiceRequestStatus.open:
        color = Colors.green;
        text = tr('badge_searching_tech');
        break;
      case ServiceRequestStatus.assigned:
        color = Colors.blue;
        text = tr('badge_tech_assigned');
        break;
      case ServiceRequestStatus.inProgress:
        color = Colors.orange;
        text = tr('badge_in_progress');
        break;
      case ServiceRequestStatus.finishedByTechnician:
        color = Colors.blue;
        text = tr('badge_finished_tech');
        break;
      case ServiceRequestStatus.completed:
        color = Colors.grey;
        text = tr('badge_completed');
        break;
      case ServiceRequestStatus.cancelled:
        color = Colors.red;
        text = tr('badge_cancelled');
        break;
      default:
        color = Colors.grey;
        text = tr('badge_unknown_status');
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildDescription(ServiceRequest request) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('descripcion'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Text(request.description, style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.black87)),
      ],
    );
  }

  /// Fotos que el técnico tomó al finalizar (lista nueva o foto única antigua).
  List<String> _completionPhotos(ServiceRequest request) {
    if (request.completionPhotoUrls.isNotEmpty) return request.completionPhotoUrls;
    if (request.completionPhotoUrl != null) return [request.completionPhotoUrl!];
    return [];
  }

  /// Muestra las fotos que el técnico tomó al finalizar el trabajo.
  Widget _buildCompletionPhoto(ServiceRequest request) {
    final photos = _completionPhotos(request);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFFFF8A00), size: 20),
            const SizedBox(width: 8),
            Text(photos.length > 1 ? tr('completion_photos') : tr('completion_photo'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        if (photos.length == 1)
          _completionPhotoImage(photos.first, double.infinity, 220)
        else
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _completionPhotoImage(photos[i], 200, 160),
            ),
          ),
      ],
    );
  }

  Widget _completionPhotoImage(String url, double width, double height) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        url,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: width == double.infinity ? null : width,
          height: height,
          color: Colors.grey[200],
          child: const Icon(Icons.broken_image, color: Colors.grey, size: 48),
        ),
      ),
    );
  }

  Widget _buildAcceptedBudget(ServiceRequest request) {
    String budgetText = '';
    if (request.minBudget != null && request.maxBudget != null) {
      budgetText = request.minBudget == request.maxBudget 
          ? '\$${request.minBudget!.toInt()}' 
          : '\$${request.minBudget!.toInt()} - \$${request.maxBudget!.toInt()}';
    } else if (request.budget != null) {
      budgetText = '\$${request.budget!.toInt()}';
    }

    if (budgetText.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF8A00).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF8A00).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.payments_outlined, color: Color(0xFFFF8A00)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('agreed_budget'), style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
              Text(budgetText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFF8A00))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInformationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('additional_info'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _infoTile(Icons.home_outlined, tr('residential_house')),
        _infoTile(Icons.security_outlined, tr('safe_environment')),
        _infoTile(Icons.schedule_outlined, tr('immediate_attention')),
      ],
    );
  }

  Widget _infoTile(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(text, style: TextStyle(fontSize: 15, color: Colors.grey[800])),
        ],
      ),
    );
  }

  Widget _buildActionButton(ServiceRequest request, bool isClient, bool isTechnician) {
    if (request.status == ServiceRequestStatus.completed) {
      if (isClient && request.reviewRating == null) {
        return ElevatedButton.icon(
          onPressed: () => _showReviewDialog(request),
          icon: const Icon(Icons.star_outline),
          label: Text(tr('rate_service')),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[700], minimumSize: const Size(double.infinity, 56)),
        );
      }
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Text(tr('work_finished_status'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            if (request.reviewRating != null) ...[
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => Icon(i < request.reviewRating! ? Icons.star : Icons.star_border, color: Colors.amber, size: 20))),
            ]
          ],
        ),
      );
    }

    if (request.status != ServiceRequestStatus.open && !isClient) {
      if (request.technicianId == _currentUserId) {
        if (request.status == ServiceRequestStatus.assigned) {
          return Column(
            children: [
              ElevatedButton.icon(
                onPressed: () => _firestoreService.updateRequestStatus(request.id, ServiceRequestStatus.inProgress),
                icon: const Icon(Icons.location_on_outlined),
                label: Text(tr('i_arrived')),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 56)),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.chat, arguments: request),
                icon: const Icon(Icons.chat_bubble_outline),
                label: Text(tr('job_chat')),
                style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
              ),
            ],
          );
        }

        if (request.status == ServiceRequestStatus.inProgress) {
          return ElevatedButton.icon(
            onPressed: () => _showCompletionDialog(request),
            icon: const Icon(Icons.check_circle_outline),
            label: Text(tr('finish_job')),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF8A00), minimumSize: const Size(double.infinity, 56)),
          );
        }

        if (request.status == ServiceRequestStatus.finishedByTechnician) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                Text(tr('work_finished_status'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                const SizedBox(height: 4),
                Text(tr('awaiting_client_validation'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          );
        }
      }
      return Center(child: Text(tr('job_already_assigned'), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)));
    }

    if (isClient) {
      final String techName = request.technicianName ?? tr('technician');
      
      return Column(
        children: [
          if (request.status == ServiceRequestStatus.finishedByTechnician) ...[
             ElevatedButton.icon(
              onPressed: () => _confirmAcceptCompletionInDetails(request),
              icon: const Icon(Icons.check_circle_outline),
              label: Text(tr('confirm_work_done')),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 56)),
            ),
            const SizedBox(height: 12),
            _buildAssignedTechnicianCard(request),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.chat, arguments: request),
              icon: const Icon(Icons.chat_bubble_outline),
              label: Text(tr('chat_with').replaceAll('{name}', techName)),
              style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
            ),
          ] else if (request.status == ServiceRequestStatus.assigned || request.status == ServiceRequestStatus.inProgress) ...[
            _buildAssignedTechnicianCard(request),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.chat, arguments: request),
              icon: const Icon(Icons.chat_bubble_outline),
              label: Text(tr('chat_with').replaceAll('{name}', techName)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1976D2), minimumSize: const Size(double.infinity, 56)),
            ),
            if (request.status == ServiceRequestStatus.assigned) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _showCancelAssignmentDialog(request),
                child: Text(tr('cancel_assignment_reopen'), style: const TextStyle(color: Colors.orange)),
              ),
            ],
          ] else
            ElevatedButton(
              onPressed: request.responsesCount > 0 ? () => Navigator.pushNamed(context, AppRoutes.techniciansList, arguments: request) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2), 
                disabledBackgroundColor: Colors.grey[300],
                minimumSize: const Size(double.infinity, 56)
              ),
              child: Text(request.responsesCount > 0 ? tr('view_responders').replaceAll('{n}', '${request.responsesCount}') : tr('awaiting_techs')),
            ),
          const SizedBox(height: 16),
          if (request.status == ServiceRequestStatus.open)
            TextButton(
              onPressed: () => _showCancelOrderDialog(request),
              child: Text(tr('cancel_order'), style: const TextStyle(color: Colors.red)),
            ),
        ],
      );
    } 
    
    if (isTechnician) {
      if (_myQuote != null) {
        final bool isFirstRejected = _myQuote!.status == QuoteStatus.rejected;
        final bool isFinalRejected = _myQuote!.status == QuoteStatus.final_rejected;
        final bool isAccepted = _myQuote!.status == QuoteStatus.accepted;
        final bool isCounterOffer = _myQuote!.status == QuoteStatus.counter_offer_sent;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: (isFirstRejected || isFinalRejected) ? Colors.red[50] : (isAccepted ? Colors.green[50] : Colors.blue[50]), 
            borderRadius: BorderRadius.circular(16)
          ),
          child: Column(
            children: [
              Text(
                isFinalRejected
                  ? tr('badge_final_rejection')
                  : (isFirstRejected ? tr('badge_proposal_rejected') : (isAccepted ? tr('badge_proposal_accepted') : tr('badge_already_proposed'))),
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  color: (isFirstRejected || isFinalRejected) ? Colors.red : (isAccepted ? Colors.green : Colors.blue)
                )
              ),
              const SizedBox(height: 8),
              Text(
                _myQuote!.minPrice == _myQuote!.maxPrice 
                  ? 'Tu precio: \$${_myQuote!.minPrice.toInt()}'
                  : 'Tu rango: \$${_myQuote!.minPrice.toInt()} - \$${_myQuote!.maxPrice.toInt()}', 
                style: const TextStyle(fontSize: 16)
              ),
              const SizedBox(height: 4),
              Text(
                isFinalRejected
                  ? tr('client_rejected')
                  : (isFirstRejected
                      ? tr('first_rejected')
                      : (isAccepted ? tr('you_were_selected') : (isCounterOffer ? tr('counter_sent') : tr('awaiting_client_response')))),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey)
              ),
              if (!isFirstRejected && !isFinalRejected) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.chat,
                      arguments: {
                        'quoteId': _myQuote!.id,
                        'title': request.title,
                        'technicianName': 'Cliente',
                      },
                    ),
                    icon: const Icon(Icons.chat_bubble_outline, size: 16, color: Color(0xFFFF8A00)),
                    label: Text(tr('quote_chat_title'), style: const TextStyle(color: Color(0xFFFF8A00), fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFF8A00)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
              if (isFirstRejected) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showSendQuoteDialog(request, isCounterOffer: true),
                  icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
                  label: Text(tr('send_counter'), style: const TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF8A00)),
                ),
              ],
              if (isFinalRejected) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _confirmHideRequest(request),
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                  label: Text(tr('hide_this_problem'), style: const TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                ),
              ],
            ],
          ),
        );
      }

      return ElevatedButton(
        onPressed: () => _showSendQuoteDialog(request),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF8A00)),
        child: Text(tr('send_proposal')),
      );
    }
    
    return const SizedBox();
  }

  void _showSendQuoteDialog(ServiceRequest request, {bool isCounterOffer = false}) {
    final TextEditingController quoteController = TextEditingController(text: isCounterOffer ? _myQuote?.message : '');
    final TextEditingController minPriceController = TextEditingController(text: isCounterOffer ? _myQuote?.minPrice.toInt().toString() : '');
    final TextEditingController maxPriceController = TextEditingController(text: isCounterOffer ? _myQuote?.maxPrice.toInt().toString() : '');
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isCounterOffer ? tr('send_counter') : tr('send_proposal'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minPriceController, 
                      keyboardType: TextInputType.number, 
                      decoration: InputDecoration(labelText: tr('price_min'), hintText: tr('price_hint_min'))
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: maxPriceController, 
                      keyboardType: TextInputType.number, 
                      decoration: InputDecoration(labelText: tr('price_max'), hintText: tr('price_hint_max'))
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(controller: quoteController, maxLines: 3, decoration: InputDecoration(labelText: tr('message_to_client'), hintText: tr('message_hint'))),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : () async {
                  if (minPriceController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(tr('enter_min_price'))),
                    );
                    return;
                  }
                  
                  final double min = double.tryParse(minPriceController.text) ?? 0.0;
                  final double? maxInput = double.tryParse(maxPriceController.text);
                  
                  if (maxInput != null && maxInput < min) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(tr('max_less_min')),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  final double max = maxInput ?? min;

                  setState(() => _isLoading = true);
                  setSheetState(() {});
                  
                  try {
                    if (isCounterOffer && _myQuote != null) {
                      await _firestoreService.sendCounterOffer(_myQuote!.id, min, max, quoteController.text, null);
                      // Refresh my quote locally
                      final updated = await _firestoreService.getQuoteById(_myQuote!.id);
                      if (mounted) setState(() => _myQuote = updated);
                    } else {
                      final quote = Quote(
                        id: '',
                        requestId: request.id,
                        clientId: request.clientId,
                        technicianId: _currentUserId,
                        technicianName: _currentUser?.displayName ?? tr('technician'),
                        technicianPhotoUrl: _currentUser?.profileImageUrl,
                        technicianRating: _currentUser?.rating ?? 5.0,
                        price: min,
                        minPrice: min,
                        maxPrice: max,
                        message: quoteController.text,
                        estimatedTime: null,
                        createdAt: DateTime.now(),
                      );
                      await _firestoreService.sendQuote(quote);
                      // Don't set state immediately with incomplete quote, 
                      // fetching the real one from server is safer if we want to show it.
                      // For now, at least refresh visibility
                      if (mounted) {
                        final realQuote = await _firestoreService.getQuoteByTechnician(request.id, _currentUserId);
                        setState(() => _myQuote = realQuote);
                      }
                    }
                    
                    if (context.mounted) {
                      Navigator.pop(context); // Close bottom sheet
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(tr('proposal_sent')), backgroundColor: Colors.green),
                      );
                    }
                  } catch (e) {
                    print('Error sending quote: $e');
                    String errorMsg = tr('proposal_send_error');
                    
                    if (e is DioException) {
                      final dynamic serverData = e.response?.data;
                      if (serverData is Map && serverData['error'] != null) {
                        final String serverError = serverData['error'].toString().toLowerCase();
                        if (serverError.contains('already sent')) {
                          errorMsg = tr('already_proposed_error');
                          final quote = await _firestoreService.getQuoteByTechnician(request.id, _currentUserId);
                          if (mounted) {
                            setState(() => _myQuote = quote);
                            Navigator.pop(context); // Also close if already exists
                          }
                        } else {
                          errorMsg = serverData['error'].toString();
                        }
                      }
                    } else if (e.toString().contains('already sent')) {
                      errorMsg = tr('already_proposed_error');
                      if (mounted) {
                        final quote = await _firestoreService.getQuoteByTechnician(request.id, _currentUserId);
                        setState(() => _myQuote = quote);
                        Navigator.pop(context);
                      }
                    }
                    
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
                      );
                    }
                  } finally {
                    if (mounted) {
                      setState(() => _isLoading = false);
                      setSheetState(() {});
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8A00),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(isCounterOffer ? tr('send_counter') : tr('send_proposal'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmHideRequest(ServiceRequest request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('hide_problem')),
        content: Text(tr('hide_problem_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('cancel'))),
          ElevatedButton(
            onPressed: () async {
              await _firestoreService.hideServiceRequest(_currentUserId, request.id);
              if (mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back from detail
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('problem_hidden'))));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
            child: Text(tr('hide_permanently'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showReviewDialog(ServiceRequest request) {
    double tempRating = 0;
    final TextEditingController commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(tr('rate_service'), style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tr('rate_tech_question')),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < tempRating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 32,
                      ),
                      onPressed: () => setDialogState(() => tempRating = index + 1.0),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: commentController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: tr('write_comment_optional'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('cancel'))),
              ElevatedButton(
                onPressed: tempRating == 0
                    ? null
                    : () async {
                        await _firestoreService.submitReview(
                          request.id,
                          request.technicianId!,
                          tempRating,
                          commentController.text
                        );
                        if (context.mounted) Navigator.pop(context);
                      },
                child: Text(tr('send')),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCancelAssignmentDialog(ServiceRequest request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('cancel_assignment')),
        content: Text(tr('cancel_assignment_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('no_keep'))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                await _firestoreService.cancelAssignment(request.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(tr('assignment_cancelled')))
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${tr('error_label')}: $e'), backgroundColor: Colors.red)
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text(tr('yes_cancel')),
          ),
        ],
      ),
    );
  }

  void _showCompletionDialog(ServiceRequest request) {
    final List<File> photos = [];
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> addPhotos() async {
            final picked = await PhotoSourcePicker.pick(
              dialogContext,
              remaining: 3 - photos.length,
            );
            if (picked.isNotEmpty) setDialogState(() => photos.addAll(picked));
          }

          return AlertDialog(
            title: Text(tr('finish_job')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('finish_photos_hint')),
                const SizedBox(height: 16),
                SizedBox(
                  height: 90,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (int i = 0; i < photos.length; i++)
                        Container(
                          width: 90,
                          height: 90,
                          margin: const EdgeInsets.only(right: 8),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(photos[i], width: 90, height: 90, fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () => setDialogState(() => photos.removeAt(i)),
                                  child: Container(
                                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                    padding: const EdgeInsets.all(3),
                                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (photos.length < 3)
                        GestureDetector(
                          onTap: addPhotos,
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: const Icon(Icons.add_a_photo_outlined, color: Colors.grey),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(tr('cancel'))),
              ElevatedButton(
                onPressed: photos.isEmpty
                    ? null
                    : () async {
                        Navigator.pop(dialogContext);
                        setState(() => _isLoading = true);
                        try {
                          final List<String> urls = [];
                          for (final f in photos) {
                            final String? url = await _uploadService.uploadObjectImage(f);
                            if (url != null) urls.add(url);
                          }
                          await _firestoreService.finishWorkByTechnician(request.id, null, urls);

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(tr('work_finished_photos'))),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(tr('error_finishing').replaceAll('{e}', '$e')), backgroundColor: Colors.red),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _isLoading = false);
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF8A00)),
                child: Text(tr('finish_and_send')),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmAcceptCompletionInDetails(ServiceRequest request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('confirm_work_done_q')),
        content: Text(tr('confirm_work_done_desc')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('cancel'))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                await _firestoreService.updateRequestStatus(request.id, ServiceRequestStatus.completed);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(tr('work_finished_success')))
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${tr('error_label')}: $e'), backgroundColor: Colors.red)
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text(tr('confirm'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCancelOrderDialog(ServiceRequest request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('cancel_order_q')),
        content: Text(tr('cancel_order_desc')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('no_go_back'))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              setState(() => _isLoading = true);
              try {
                await _firestoreService.cancelServiceRequest(request.id);
                if (mounted) {
                  setState(() => _isLoading = false);
                  Navigator.pop(context, true); // Go back with success
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(tr('order_cancelled_success')))
                  );
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(tr('error_cancelling').replaceAll('{e}', '$e')), backgroundColor: Colors.red)
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(tr('yes_cancel_order'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes} m';
    if (diff.inHours < 24) return '${diff.inHours} h';
    return '${diff.inDays} d';
  }

  Widget _buildAssignedTechnicianCard(ServiceRequest request) {
    if (request.technicianId == null) return const SizedBox();

    return FutureBuilder<UserModel?>(
      future: _firestoreService.getUser(request.technicianId!),
      builder: (context, snapshot) {
        final tech = snapshot.data;
        final String name = tech?.displayName ?? request.technicianName ?? tr('technician');
        final String? photo = tech?.profileImageUrl ?? request.technicianPhotoUrl;
        final String specialty = ServiceConstants.getDisplayName(tech?.specialties.isNotEmpty == true ? tech!.specialties.first : request.category);
        final double rating = tech?.rating ?? 5.0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.engineering_outlined, size: 16, color: Color(0xFFFF8A00)),
                  const SizedBox(width: 8),
                  Text(tr('tech_assigned_label'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFFF8A00))),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: photo != null && photo.isNotEmpty ? NetworkImage(photo) : null,
                    backgroundColor: Colors.grey[200],
                    child: photo == null || photo.isEmpty ? const Icon(Icons.person, color: Colors.grey) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(specialty, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.amber[50], borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amber)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
