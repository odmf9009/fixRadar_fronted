import 'package:flutter/material.dart';
import '../../core/models/service_request.dart';
import '../../core/models/quote_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/language_service.dart';
import '../../core/config/routes.dart';

class TechniciansListScreen extends StatelessWidget {
  final ServiceRequest request;

  const TechniciansListScreen({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          children: [
            const Text('Técnicos que respondieron', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
            StreamBuilder<List<Quote>>(
              stream: firestoreService.getQuotesForRequest(request.id),
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
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
      ),
      body: StreamBuilder<List<Quote>>(
        stream: firestoreService.getQuotesForRequest(request.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFFFF8A00)));
          final quotes = snapshot.data ?? [];
          if (quotes.isEmpty) return const Center(child: Text('Aún no hay respuestas de técnicos.'));

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: quotes.length,
            itemBuilder: (context, index) {
              final quote = quotes[index];
              return _buildQuoteCard(context, quote, firestoreService);
            },
          );
        },
      ),
    );
  }

  Widget _buildQuoteCard(BuildContext context, Quote quote, FirestoreService firestoreService) {
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
                      child: const Text('PRO', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
                    Text(' ${quote.technicianRating.toStringAsFixed(1)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFFF8A00))),
                    const Text(' (200)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 4),
                if (quote.status == QuoteStatus.counter_offer_sent)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.orange.withOpacity(0.5))),
                    child: const Text('🔄 CONTRAOFERTA', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                if (quote.estimatedTime != null && quote.estimatedTime!.isNotEmpty)
                  Text('Tiempo: ${quote.estimatedTime}', style: const TextStyle(color: Colors.blue, fontSize: 13, fontWeight: FontWeight.w500)),
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
                          child: const Text('Ver perfil', style: TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: OutlinedButton(
                          onPressed: () => _showRejectDialog(context, quote, firestoreService),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: const Text('Rechazar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: ElevatedButton(
                          onPressed: () => _showAcceptDialog(context, quote, firestoreService),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1976D2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          child: const Text('Aceptar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
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

  void _showAcceptDialog(BuildContext context, Quote quote, FirestoreService firestoreService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmar Asignación', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('¿Deseas contratar a ${quote.technicianName} para este trabajo? Se abrirá un chat privado para coordinar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              await firestoreService.acceptQuote(request.id, quote);
              if (context.mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close list
                // Optionally navigate to chat
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF8A00)),
            child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context, Quote quote, FirestoreService firestoreService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Rechazar Propuesta', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('¿Estás seguro de que deseas rechazar la propuesta de ${quote.technicianName}? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              await firestoreService.rejectQuote(request.id, quote.id);
              if (context.mounted) {
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
