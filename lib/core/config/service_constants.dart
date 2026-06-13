import 'package:flutter/material.dart';

class ServiceConstants {
  static const List<Map<String, dynamic>> allCategories = [
    {'name': 'Electricidad', 'icon': Icons.bolt, 'color': Color(0xFFFBC02D)},
    {'name': 'Plomería', 'icon': Icons.water_drop, 'color': Color(0xFF1976D2)},
    {'name': 'Aire Acond.', 'icon': Icons.ac_unit, 'color': Color(0xFF00BCD4)},
    {'name': 'Pintura', 'icon': Icons.format_paint, 'color': Color(0xFFEF6C00)},
    {'name': 'Techos', 'icon': Icons.roofing, 'color': Color(0xFF5D4037)},
    {'name': 'Carpintería', 'icon': Icons.chair, 'color': Color(0xFF8D6E63)},
    {'name': 'Drywall y Reparación de Paredes', 'icon': Icons.layers, 'color': Color(0xFF546E7A)},
    {'name': 'Jardinería', 'icon': Icons.yard, 'color': Color(0xFF2E7D32)},
    {'name': 'Limpieza', 'icon': Icons.cleaning_services, 'color': Color(0xFF388E3C)},
    {'name': 'Electrodomésticos', 'icon': Icons.kitchen, 'color': Color(0xFFD32F2F)},
    {'name': 'Cámaras y Seguridad', 'icon': Icons.videocam, 'color': Color(0xFF455A64)},
    {'name': 'TV y Montaje', 'icon': Icons.tv, 'color': Color(0xFF303F9F)},
    {'name': 'Puertas y Ventanas', 'icon': Icons.door_front_door, 'color': Color(0xFF795548)},
    {'name': 'Mudanzas', 'icon': Icons.local_shipping, 'color': Color(0xFF7B1FA2)},
    {'name': 'Handyman', 'icon': Icons.build, 'color': Color(0xFF607D8B)},
    {'name': 'Otros', 'icon': Icons.more_horiz, 'color': Color(0xFF616161)},
  ];

  static List<String> get categoryNames => allCategories.map((e) => e['name'] as String).toList();

  static IconData getIcon(String category) {
    try {
      return allCategories.firstWhere(
        (e) => e['name'] == category || _normalize(e['name']) == _normalize(category),
        orElse: () => allCategories.last,
      )['icon'] as IconData;
    } catch (e) {
      return Icons.more_horiz;
    }
  }

  static Color getColor(String category) {
    try {
      return allCategories.firstWhere(
        (e) => e['name'] == category || _normalize(e['name']) == _normalize(category),
        orElse: () => allCategories.last,
      )['color'] as Color;
    } catch (e) {
      return Colors.grey;
    }
  }

  static String _normalize(String s) => s.toLowerCase().replaceAll(' ', '');
}
