import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/models/service_request.dart';
import '../../core/config/routes.dart';
import 'category_badge.dart';

class JobCard extends StatelessWidget {
  final ServiceRequest request;

  const JobCard({
    super.key,
    required this.request,
  });

  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final bool alreadyQuoted = request.interestedTechnicians.contains(currentUserId);

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, AppRoutes.requestDetail, arguments: request);
      },
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: alreadyQuoted ? const Color(0xFFFF8A00).withOpacity(0.5) : Colors.grey[200]!,
            width: alreadyQuoted ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Highlighted Category Badge
                CategoryBadge(category: request.category),
                // Urgency and Status Indicators
                Row(
                  children: [
                    if (alreadyQuoted)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, size: 10, color: Colors.white),
                      ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: _getUrgencyColor(request.urgency).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _getUrgencyText(request.urgency),
                        style: TextStyle(
                          color: _getUrgencyColor(request.urgency),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              request.title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, height: 1.2),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    request.address,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people_outline, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      alreadyQuoted 
                        ? 'Ofertado'
                        : '${request.responsesCount} técnicos',
                      style: TextStyle(
                        color: alreadyQuoted ? Colors.blue : Colors.grey, 
                        fontSize: 12,
                        fontWeight: alreadyQuoted ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                if (!alreadyQuoted)
                  const Text(
                    'Postularse',
                    style: TextStyle(
                      color: Color(0xFFFF8A00),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getUrgencyColor(UrgencyLevel urgency) {
    switch (urgency) {
      case UrgencyLevel.high:
        return Colors.red;
      case UrgencyLevel.medium:
        return Colors.orange;
      case UrgencyLevel.low:
        return Colors.green;
    }
  }

  String _getUrgencyText(UrgencyLevel urgency) {
    switch (urgency) {
      case UrgencyLevel.high:
        return 'URGENTE';
      case UrgencyLevel.medium:
        return 'MEDIA';
      case UrgencyLevel.low:
        return 'BAJA';
    }
  }
}
