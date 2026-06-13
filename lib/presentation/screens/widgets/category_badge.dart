import 'package:flutter/material.dart';
import '../../core/config/service_constants.dart';

class CategoryBadge extends StatelessWidget {
  final String category;
  final double fontSize;
  final bool isBold;

  const CategoryBadge({
    super.key,
    required this.category,
    this.fontSize = 12,
    this.isBold = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = ServiceConstants.getColor(category);
    final icon = ServiceConstants.getIcon(category);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: fontSize + 2,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            category.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.normal,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
