import 'package:flutter/material.dart';
import '../../core/models/quote_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/language_service.dart';
import '../../core/config/routes.dart';

class ClientRespondersListScreen extends StatefulWidget {
  const ClientRespondersListScreen({super.key});

  @override
  State<ClientRespondersListScreen> createState() => _ClientRespondersListScreenState();
}

class _ClientRespondersListScreenState extends State<ClientRespondersListScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final String _currentUserId = AuthService.currentUidSync;
  Stream<List<Quote>>? _quotesStream;

  @override
  void initState() {
    super.initState();
    _quotesStream = _firestoreService.getQuotesForClient(_currentUserId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          children: [
            const Text('Técnicos que respondieron',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
            StreamBuilder<List<Quote>>(
              stream: _quotesStream,
              builder: (context, snapshot) {
                final count = snapshot.data?.length ?? 0;
                return Text('$count técnicos disponibles', style: const TextStyle(color: Colors.grey, fontSize: 13));
              },
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<List<Quote>>(
        stream: _quotesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFF8A00)));
          }

          final quotes = snapshot.data ?? [];

          if (quotes.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => setState(() {
                _quotesStream = _firestoreService.getQuotesForClient(_currentUserId);
              }),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.7,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_search_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      const Text('Aún no tienes propuestas',
                          style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'Cuando un técnico responda a tu pedido, aparecerá aquí con su presupuesto.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _quotesStream = _firestoreService.getQuotesForClient(_currentUserId);
                        }),
                        icon: const Icon(Icons.refresh, color: Color(0xFFFF8A00)),
                        label: const Text('Actualizar', style: TextStyle(color: Color(0xFFFF8A00))),
                      )
                    ],
                  ),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: quotes.length,
            itemBuilder: (context, index) {
              final quote = quotes[index];
              return _buildQuoteItem(quote);
            },
          );
        },
      ),
    );
  }

  Widget _buildQuoteItem(Quote quote) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 32,
            backgroundImage: quote.technicianPhotoUrl != null ? NetworkImage(quote.technicianPhotoUrl!) : null,
            child: quote.technicianPhotoUrl == null ? const Icon(Icons.person) : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(quote.technicianName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.blue[600], borderRadius: BorderRadius.circular(4)),
                      child: const Text('PRO',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const Spacer(),
                    Text(
                      quote.minPrice == quote.maxPrice 
                        ? '\$${quote.minPrice.toInt()}' 
                        : '\$${quote.minPrice.toInt()}-\$${quote.maxPrice.toInt()}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    Text(' ${quote.technicianRating.toStringAsFixed(1)}',
                        style:
                            const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFFF8A00))),
                    const Text(' (200)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('A 0.4 millas', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 2),
                const Text('Plomería • 6 años exp.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, AppRoutes.publicProfile, arguments: quote.technicianId);
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF4CAF50)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: const Text('Ver perfil',
                              style: TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: OutlinedButton(
                          onPressed: () => _showRejectDialog(quote),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: const Text('Rechazar',
                              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: ElevatedButton(
                          onPressed: () async {
                            final request = await _firestoreService.getServiceRequestById(quote.requestId);
                            if (request != null && mounted) {
                              Navigator.pushNamed(
                                context, 
                                AppRoutes.requestDetail, 
                                arguments: {
                                  'request': request,
                                  'selectedQuote': quote,
                                }
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1976D2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          child: const Text('Ver pedido',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(Quote quote) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Rechazar Propuesta', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
            '¿Estás seguro de que deseas rechazar la propuesta de ${quote.technicianName}? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              await _firestoreService.rejectQuote(quote.requestId, quote.id);
              if (mounted) {
                Navigator.pop(context); // Close dialog
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Rechazar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
