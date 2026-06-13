import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/models/service_request.dart';
import '../../core/config/routes.dart';
import 'widgets/category_badge.dart';

class AllNearbyRequestsScreen extends StatelessWidget {
  final List<ServiceRequest> requests;
  final Position? currentPosition;

  const AllNearbyRequestsScreen({super.key, required this.requests, this.currentPosition});

  @override
  Widget build(BuildContext context) {
    final displayedRequests = requests.take(20).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Pedidos cercanos',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: displayedRequests.isEmpty
          ? const Center(
              child: Text('No hay pedidos en tu rango de búsqueda',
                  style: TextStyle(color: Colors.grey)),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: displayedRequests.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final req = displayedRequests[index];
                return _buildListItem(context, req);
              },
            ),
    );
  }

  Widget _buildListItem(BuildContext context, ServiceRequest req) {
    Color statusColor;
    switch (req.status) {
      case ServiceRequestStatus.open: statusColor = Colors.green; break;
      case ServiceRequestStatus.assigned: statusColor = Colors.blue; break;
      case ServiceRequestStatus.inProgress: statusColor = Colors.orange; break;
      case ServiceRequestStatus.finishedByTechnician: statusColor = Colors.blue; break;
      case ServiceRequestStatus.completed: statusColor = Colors.grey; break;
      case ServiceRequestStatus.cancelled: statusColor = Colors.red; break;
    }

    String distanceText = '';
    if (currentPosition != null) {
      double distanceInMeters = Geolocator.distanceBetween(
        currentPosition!.latitude, currentPosition!.longitude,
        req.latitude, req.longitude
      );
      double distanceInMiles = distanceInMeters / 1609.34;
      distanceText = '${distanceInMiles.toStringAsFixed(1)} mi';
    }

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.requestDetail, arguments: req),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(color: Colors.grey[100]!),
        ),
        child: Row(
          children: [
            Hero(
              tag: 'image_${req.id}',
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: req.imageUrls.isNotEmpty
                      ? Image.network(req.imageUrls[0], fit: BoxFit.cover)
                      : const Icon(Icons.image, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    req.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      CategoryBadge(category: req.category, fontSize: 10),
                      if (distanceText.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.circle, size: 4, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          distanceText,
                          style: const TextStyle(color: Color(0xFFFF8A00), fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          req.address,
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
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
