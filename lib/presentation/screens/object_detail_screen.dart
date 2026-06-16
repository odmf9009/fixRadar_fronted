import 'dart:io';
import 'dart:async';
import '../../core/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../core/models/service_request.dart';
import '../../core/models/user_model.dart';
import '../../core/models/quote_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/upload_service.dart';
import '../../core/services/language_service.dart';
import '../../core/config/routes.dart';

class RequestDetailScreen extends StatefulWidget {
  const RequestDetailScreen({super.key});

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  final _firestoreService = FirestoreService();
  final LocationService _locationService = LocationService();
  final UploadService _uploadService = UploadService();
  final ImagePicker _picker = ImagePicker();
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

    if (initialRequest == null) return const Scaffold(body: Center(child: Text('Error: No se encontró el pedido')));

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
                          if (request.status == ServiceRequestStatus.assigned || request.status == ServiceRequestStatus.inProgress)
                            _buildAcceptedBudget(request),
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
                      'Propuesta de ${_selectedQuote!.technicianName}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      _selectedQuote!.minPrice == _selectedQuote!.maxPrice
                          ? 'Presupuesto: \$${_selectedQuote!.minPrice.toInt()}'
                          : 'Rango: \$${_selectedQuote!.minPrice.toInt()} - \$${_selectedQuote!.maxPrice.toInt()}',
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
            child: const Text('Aceptar esta cotización', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmAcceptQuote(ServiceRequest request, Quote quote) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Asignación'),
        content: Text('¿Deseas contratar a ${quote.technicianName} para este trabajo?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                await _firestoreService.acceptQuote(request.id, quote);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Técnico asignado correctamente.'))
                  );
                  setState(() => _selectedQuote = null);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF8A00)),
            child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
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
              child: Text(request.category.toUpperCase(), style: TextStyle(color: Colors.blue[700], fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            _buildStatusBadge(request.status),
          ],
        ),
        const SizedBox(height: 16),
        Text(request.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          'Publicado hace ${_getTimeAgo(request.createdAt)} • a ${_distance.toStringAsFixed(1)} millas de ti',
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
                'Ver ubicación en el mapa',
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
        text = 'BUSCANDO TÉCNICO';
        break;
      case ServiceRequestStatus.assigned:
        color = Colors.blue;
        text = 'TÉCNICO ASIGNADO';
        break;
      case ServiceRequestStatus.inProgress:
        color = Colors.orange;
        text = 'EN CURSO';
        break;
      case ServiceRequestStatus.finishedByTechnician:
        color = Colors.blue;
        text = 'FINALIZADO (TÉCNICO)';
        break;
      case ServiceRequestStatus.completed:
        color = Colors.grey;
        text = 'COMPLETADO';
        break;
      case ServiceRequestStatus.cancelled:
        color = Colors.red;
        text = 'CANCELADO';
        break;
      default:
        color = Colors.grey;
        text = 'ESTADO DESCONOCIDO';
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
        const Text('Descripción', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Text(request.description, style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.black87)),
      ],
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
              const Text('Presupuesto acordado', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
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
        const Text('Información adicional', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _infoTile(Icons.home_outlined, 'Casa residencial'),
        _infoTile(Icons.security_outlined, 'Entorno seguro'),
        _infoTile(Icons.schedule_outlined, 'Atención inmediata preferida'),
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
          label: const Text('Calificar Servicio'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[700], minimumSize: const Size(double.infinity, 56)),
        );
      }
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            const Text('Trabajo Finalizado', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
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
                label: const Text('Ya estoy en el lugar'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 56)),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.chat, arguments: request),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Chat de Trabajo'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
              ),
            ],
          );
        }

        if (request.status == ServiceRequestStatus.inProgress) {
          return ElevatedButton.icon(
            onPressed: () => _showCompletionDialog(request),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Finalizar Trabajo'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF8A00), minimumSize: const Size(double.infinity, 56)),
          );
        }

        if (request.status == ServiceRequestStatus.finishedByTechnician) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(16)),
            child: const Column(
              children: [
                Text('Trabajo Finalizado', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                SizedBox(height: 4),
                Text('Esperando validación del cliente...', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          );
        }
      }
      return const Center(child: Text('Este trabajo ya ha sido asignado.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)));
    }

    if (isClient) {
      return Column(
        children: [
          if (request.status == ServiceRequestStatus.finishedByTechnician) ...[
             ElevatedButton.icon(
              onPressed: () => _confirmAcceptCompletionInDetails(request),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Confirmar Trabajo Terminado'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 56)),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.chat, arguments: request),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Chat con el Técnico'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
            ),
          ] else if (request.status == ServiceRequestStatus.assigned || request.status == ServiceRequestStatus.inProgress) ...[
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.chat, arguments: request),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Chat con el Técnico'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1976D2), minimumSize: const Size(double.infinity, 56)),
            ),
            if (request.status == ServiceRequestStatus.assigned) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _showCancelAssignmentDialog(request),
                child: const Text('Cancelar asignación y volver a abrir', style: TextStyle(color: Colors.orange)),
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
              child: Text(request.responsesCount > 0 ? 'Ver técnicos que respondieron (${request.responsesCount})' : 'Esperando técnicos...'),
            ),
          const SizedBox(height: 16),
          if (request.status == ServiceRequestStatus.open)
            TextButton(
              onPressed: () => _showCancelOrderDialog(request),
              child: const Text('Cancelar pedido', style: TextStyle(color: Colors.red)),
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
                  ? '❌ Rechazo Definitivo' 
                  : (isFirstRejected ? '❌ Propuesta Rechazada' : (isAccepted ? '✅ Propuesta Aceptada' : 'Ya enviaste una propuesta')), 
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
                  ? 'El cliente rechazó definitivamente tu propuesta.' 
                  : (isFirstRejected 
                      ? 'Esta propuesta fue rechazada. Tienes una oportunidad de contraoferta.' 
                      : (isAccepted ? '¡Felicidades! Fuiste seleccionado.' : (isCounterOffer ? 'Contraoferta enviada. Esperando respuesta...' : 'Esperando respuesta del cliente...'))), 
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey)
              ),
              if (isFirstRejected) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showSendQuoteDialog(request, isCounterOffer: true),
                  icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
                  label: const Text('Enviar Contraoferta', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF8A00)),
                ),
              ],
              if (isFinalRejected) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _confirmHideRequest(request),
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                  label: const Text('Ocultar este problema', style: TextStyle(color: Colors.red)),
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
        child: const Text('Enviar Propuesta'),
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
              Text(isCounterOffer ? 'Enviar contraoferta' : 'Enviar propuesta', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minPriceController, 
                      keyboardType: TextInputType.number, 
                      decoration: const InputDecoration(labelText: 'Precio Mín (\$)', hintText: 'Ej: 100')
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: maxPriceController, 
                      keyboardType: TextInputType.number, 
                      decoration: const InputDecoration(labelText: 'Precio Máx (\$)', hintText: 'Ej: 200')
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(controller: quoteController, maxLines: 3, decoration: const InputDecoration(labelText: 'Mensaje para el cliente', hintText: 'Hola, puedo ayudarte con tu problema...')),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : () async {
                  if (minPriceController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Por favor, ingresa al menos el precio mínimo.')),
                    );
                    return;
                  }
                  
                  final double min = double.tryParse(minPriceController.text) ?? 0.0;
                  final double? maxInput = double.tryParse(maxPriceController.text);
                  
                  if (maxInput != null && maxInput < min) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('El precio máximo no puede ser menor al precio mínimo.'),
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
                        technicianName: _currentUser?.displayName ?? 'Técnico',
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
                      if (mounted) setState(() => _myQuote = quote);
                    }
                    
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    print('Error sending quote: $e');
                    String errorMsg = 'Error al enviar la propuesta. Inténtalo de nuevo.';
                    
                    if (e is DioException) {
                      final dynamic serverData = e.response?.data;
                      if (serverData is Map && serverData['error'] != null) {
                        final String serverError = serverData['error'].toString().toLowerCase();
                        if (serverError.contains('already sent')) {
                          errorMsg = 'Ya has enviado una propuesta para este pedido.';
                          final quote = await _firestoreService.getQuoteByTechnician(request.id, _currentUserId);
                          if (mounted) setState(() => _myQuote = quote);
                        } else {
                          errorMsg = serverData['error'].toString();
                        }
                      }
                    } else if (e.toString().contains('already sent')) {
                      errorMsg = 'Ya has enviado una propuesta para este pedido.';
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
                  : Text(isCounterOffer ? 'Enviar contraoferta' : 'Enviar propuesta', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
        title: const Text('Ocultar problema'),
        content: const Text('¿Seguro que deseas ocultar este problema? No volverás a verlo en ninguna parte de la aplicación.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              await _firestoreService.hideServiceRequest(_currentUserId, request.id);
              if (mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back from detail
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Problema ocultado.')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
            child: const Text('Ocultar definitivamente', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showReviewDialog(ServiceRequest request) {
    double tempRating = 5;
    final TextEditingController commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Calificar Servicio', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('¿Cómo calificarías el trabajo del técnico?'),
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
                  decoration: const InputDecoration(
                    hintText: 'Escribe un comentario (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () async {
                  await _firestoreService.submitReview(
                    request.id, 
                    request.technicianId!, 
                    tempRating, 
                    commentController.text
                  );
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Enviar'),
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
        title: const Text('Cancelar Asignación'),
        content: const Text('¿Estás seguro de que deseas cancelar la asignación de este técnico? El pedido volverá a estar abierto para recibir nuevas propuestas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('No, mantener')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              await _firestoreService.cancelAssignment(request.id);
              setState(() => _isLoading = false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
  }

  void _showCompletionDialog(ServiceRequest request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalizar Trabajo'),
        content: const Text('Para completar el servicio, debes tomar una foto del resultado final.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final XFile? pickedFile = await _picker.pickImage(source: ImageSource.camera, imageQuality: 50);
              if (pickedFile != null) {
                setState(() => _isLoading = true);
                final url = await _uploadService.uploadObjectImage(File(pickedFile.path));
                await _firestoreService.completeService(request.id, url);
                setState(() => _isLoading = false);
              }
            },
            child: const Text('Tomar Foto y Finalizar'),
          ),
        ],
      ),
    );
  }

  void _confirmAcceptCompletionInDetails(ServiceRequest request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Confirmar trabajo terminado?'),
        content: const Text('Al confirmar, se cerrará el pedido y podrás calificar al técnico.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                await _firestoreService.updateRequestStatus(request.id, ServiceRequestStatus.completed);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('¡Trabajo finalizado con éxito!'))
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCancelOrderDialog(ServiceRequest request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cancelar este pedido?'),
        content: const Text('Se eliminarán todas las propuestas recibidas y los técnicos serán notificados de la cancelación.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('No, volver')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              setState(() => _isLoading = true);
              await _firestoreService.updateRequestStatus(request.id, ServiceRequestStatus.cancelled);
              if (mounted) {
                setState(() => _isLoading = false);
                Navigator.pop(context); // Go back from detail screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pedido cancelado correctamente'))
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sí, cancelar pedido', style: TextStyle(color: Colors.white)),
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
}
