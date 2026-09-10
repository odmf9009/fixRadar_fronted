import 'package:flutter/material.dart';
import '../services/language_service.dart';

class ServiceConstants {
  static const Map<String, String> _categoryTrKeys = {
    'Electricidad': 'cat_electricidad',
    'Plomería': 'cat_plomeria',
    'Aire Acond.': 'cat_aire_acond',
    'Pintura': 'cat_pintura',
    'Techos': 'cat_techos',
    'Gabinetes': 'cat_gabinetes',
    'Drywall y Reparación de Paredes': 'cat_drywall',
    'Paisajismo': 'cat_landscaping',
    'Limpieza': 'cat_limpieza',
    'Electrodomésticos': 'cat_electrodomesticos',
    'Cámaras y Seguridad': 'cat_camaras_seguridad',
    'TV y Montaje': 'cat_tv_montaje',
    'Puertas y Ventanas': 'cat_puertas_ventanas',
    'Mudanzas': 'cat_mudanzas',
    'Handyman': 'cat_handyman',
    'Sistemas Contra Incendios': 'cat_fire_sprinklers',
    'Gestión y Permisos': 'cat_gestion_permisos',
    'Contratista General y Arquitectura': 'cat_gc_architecture',
    'Piscinas': 'cat_pools',
    'Control de Plagas': 'cat_pest_control',
    'Cercas y Barandillas': 'cat_fence_railing',
    'Aislamiento': 'cat_insulation',
    'Pisos': 'cat_floor',
    'Vidrios': 'cat_glass',
    'Carpintería de Acabados': 'cat_millwork',
    'Otros': 'cat_otros',
    'Todos': 'cat_all',
  };

  /// Nombre traducido para mostrar en la UI. El valor de `category` (en
  /// español) se conserva siempre como identificador canónico para
  /// almacenamiento, filtros y coincidencia de especialidades.
  static String getDisplayName(String category) {
    final key = _categoryTrKeys[category];
    return key != null ? tr(key) : category;
  }

  static const Map<String, String> _categoryDescriptionTrKeys = {
    'Electricidad': 'cat_desc_electricidad',
    'Plomería': 'cat_desc_plomeria',
    'Aire Acond.': 'cat_desc_aire_acond',
    'Pintura': 'cat_desc_pintura',
    'Techos': 'cat_desc_techos',
    'Gabinetes': 'cat_desc_gabinetes',
    'Drywall y Reparación de Paredes': 'cat_desc_drywall',
    'Paisajismo': 'cat_desc_landscaping',
    'Limpieza': 'cat_desc_limpieza',
    'Electrodomésticos': 'cat_desc_electrodomesticos',
    'Cámaras y Seguridad': 'cat_desc_camaras_seguridad',
    'TV y Montaje': 'cat_desc_tv_montaje',
    'Puertas y Ventanas': 'cat_desc_puertas_ventanas',
    'Mudanzas': 'cat_desc_mudanzas',
    'Handyman': 'cat_desc_handyman',
    'Sistemas Contra Incendios': 'cat_desc_fire_sprinklers',
    'Gestión y Permisos': 'cat_desc_gestion_permisos',
    'Contratista General y Arquitectura': 'cat_desc_gc_architecture',
    'Piscinas': 'cat_desc_pools',
    'Control de Plagas': 'cat_desc_pest_control',
    'Cercas y Barandillas': 'cat_desc_fence_railing',
    'Aislamiento': 'cat_desc_insulation',
    'Pisos': 'cat_desc_floor',
    'Vidrios': 'cat_desc_glass',
    'Carpintería de Acabados': 'cat_desc_millwork',
    'Otros': 'cat_desc_otros',
  };

  /// Descripción breve de la categoría, para el ícono de info que la
  /// acompaña en la grilla de categorías.
  static String getDescription(String category) {
    final key = _categoryDescriptionTrKeys[category];
    return key != null ? tr(key) : '';
  }

  static const List<Map<String, dynamic>> allCategories = [
    {'name': 'Electricidad', 'icon': Icons.bolt, 'color': Color(0xFFFBC02D)},
    {'name': 'Plomería', 'icon': Icons.water_drop, 'color': Color(0xFF1976D2)},
    {'name': 'Aire Acond.', 'icon': Icons.ac_unit, 'color': Color(0xFF00BCD4)},
    {'name': 'Pintura', 'icon': Icons.format_paint, 'color': Color(0xFFEF6C00)},
    {'name': 'Techos', 'icon': Icons.roofing, 'color': Color(0xFF5D4037)},
    {'name': 'Gabinetes', 'icon': Icons.inventory_2, 'color': Color(0xFF8D6E63)},
    {'name': 'Drywall y Reparación de Paredes', 'icon': Icons.layers, 'color': Color(0xFF546E7A)},
    {'name': 'Paisajismo', 'icon': Icons.grass, 'color': Color(0xFF43A047)},
    {'name': 'Limpieza', 'icon': Icons.cleaning_services, 'color': Color(0xFF388E3C)},
    {'name': 'Electrodomésticos', 'icon': Icons.devices, 'color': Color(0xFFD32F2F)},
    {'name': 'Cámaras y Seguridad', 'icon': Icons.videocam, 'color': Color(0xFF455A64)},
    {'name': 'TV y Montaje', 'icon': Icons.tv, 'color': Color(0xFF303F9F)},
    {'name': 'Puertas y Ventanas', 'icon': Icons.door_front_door, 'color': Color(0xFF795548)},
    {'name': 'Mudanzas', 'icon': Icons.local_shipping, 'color': Color(0xFF7B1FA2)},
    {'name': 'Handyman', 'icon': Icons.build, 'color': Color(0xFF607D8B)},
    {'name': 'Sistemas Contra Incendios', 'icon': Icons.local_fire_department, 'color': Color(0xFFE53935)},
    {'name': 'Gestión y Permisos', 'icon': Icons.assignment_turned_in, 'color': Color(0xFF00838F)},
    {'name': 'Contratista General y Arquitectura', 'icon': Icons.architecture, 'color': Color(0xFF37474F)},
    {'name': 'Piscinas', 'icon': Icons.pool, 'color': Color(0xFF0288D1)},
    {'name': 'Control de Plagas', 'icon': Icons.pest_control, 'color': Color(0xFF795548)},
    {'name': 'Cercas y Barandillas', 'icon': Icons.fence, 'color': Color(0xFF6D4C41)},
    {'name': 'Aislamiento', 'icon': Icons.thermostat, 'color': Color(0xFFFFA000)},
    {'name': 'Pisos', 'icon': Icons.grid_view, 'color': Color(0xFF8D6E63)},
    {'name': 'Vidrios', 'icon': Icons.window, 'color': Color(0xFF00ACC1)},
    {'name': 'Carpintería de Acabados', 'icon': Icons.carpenter, 'color': Color(0xFF5D4037)},
    {'name': 'Otros', 'icon': Icons.more_horiz, 'color': Color(0xFF616161)},
  ];

  static List<String> get categoryNames => allCategories.map((e) => e['name'] as String).toList();

  /// Categorías que se muestran para elegir (grillas, filtros, pickers).
  /// "Handyman" queda oculta de estas listas pero se mantiene en
  /// [allCategories] porque su lógica interna (recibe todas las
  /// especialidades) sigue activa en el resto de la app.
  static List<Map<String, dynamic>> get selectableCategories =>
      allCategories.where((c) => c['name'] != 'Handyman').toList();

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
