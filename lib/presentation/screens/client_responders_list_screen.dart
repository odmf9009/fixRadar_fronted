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
            Text(tr('techs_responded'),
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
            StreamBuilder<List<Quote>>(
              stream: _quotesStream,
              builder: (context, snapshot) {
                final count = snapshot.data?.length ?? 0;
                return Text(tr('techs_available').replaceAll('{count}', '$count'), style: const TextStyle(color: Colors.grey, fontSize: 13));
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
                      Text(tr('no_proposals_yet'),
                          style: const TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          tr('proposals_appear_here'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _quotesStream = _firestoreService.getQuotesForClient(_currentUserId);
                        }),
                        icon: const Icon(Icons.refresh, color: Color(0xFFFF8A00)),
                        label: Text(tr('refresh'), style: const TextStyle(color: Color(0xFFFF8A00))),
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
                    Text(' ${tr('reviews_count_demo')}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(tr('at_distance_demo'), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 2),
                Text(tr('plumbing_demo'), style: const TextStyle(color: Colors.grey, fontSize: 13)),
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
                          child: Text(tr('view_profile'),
                              style: const TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold, fontSize: 12)),
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
                          child: Text(tr('reject'),
                              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
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
                            if (!mounted) return;
                            if (request != null) {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.requestDetail,
                                arguments: {
                                  'request': request,
                                  'selectedQuote': quote,
                                }
                              );
                            } else {
                              // El pedido ya no existe (fue eliminado): avisar en vez de no hacer nada.
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(tr('order_unavailable')),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1976D2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          child: Text(tr('view_order'),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
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
        title: Text(tr('reject_proposal'), style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
            tr('reject_proposal_confirm').replaceAll('{name}', quote.technicianName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('cancel'), style: const TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              try {
                await _firestoreService.rejectQuote(quote.requestId, quote.id);
                if (mounted) {
                  Navigator.pop(context); // Close dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(tr('proposal_rejected')), backgroundColor: Colors.orange),
                  );
                  // Force a manual refresh in case socket is slow
                  setState(() {
                    _quotesStream = _firestoreService.getQuotesForClient(_currentUserId);
                  });
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${tr('error_label')}: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(tr('reject'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
