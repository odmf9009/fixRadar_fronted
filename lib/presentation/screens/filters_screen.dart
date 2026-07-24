import 'package:flutter/material.dart';
import '../../core/models/filter_model.dart';
import '../../core/services/language_service.dart';
import '../../core/config/service_constants.dart';

class FiltersScreen extends StatefulWidget {
  final FilterModel initialFilters;
  final List<String> specialties;
  final int resultsCount;

  const FiltersScreen({
    super.key, 
    required this.initialFilters,
    this.specialties = const [],
    this.resultsCount = 0,
  });

  @override
  State<FiltersScreen> createState() => _FiltersScreenState();
}

class _FiltersScreenState extends State<FiltersScreen> {
  late double _distance;
  late double _alertDistance;
  late String _selectedTime;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final filters = widget.initialFilters;
    _distance = filters.distance;
    _alertDistance = filters.alertDistance;
    _selectedTime = filters.timeRange;
    _searchController.text = filters.searchQuery;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          tr('advanced_filters'),
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _distance = 10;
                _alertDistance = 5;
                _selectedTime = 'all';
                _searchController.clear();
              });
            },
            child: Text(
              tr('clear'),
              style: const TextStyle(color: Color(0xFFFF8A00), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search keyword
            Text(tr('search_by_keyword'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: tr('keyword_hint'),
                prefixIcon: const Icon(Icons.search, color: Color(0xFFFF8A00)),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),

            const SizedBox(height: 24),

            Text(tr('max_work_distance'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(tr('mi_1'), style: const TextStyle(color: Colors.grey)),
                Text(tr('x_miles').replaceAll('{n}', '${_distance.toInt()}'), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF8A00))),
                Text(tr('mi_50'), style: const TextStyle(color: Colors.grey)),
              ],
            ),
            Slider(
              value: _distance,
              min: 1,
              max: 50,
              divisions: 49,
              activeColor: const Color(0xFFFF8A00),
              inactiveColor: Colors.grey[200],
              onChanged: (value) => setState(() => _distance = value),
            ),

            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(tr('jobs_found'), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                      Text('${widget.resultsCount}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFFF8A00))),
                    ],
                  ),
                  if (widget.specialties.isNotEmpty) ...[
                    const Divider(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('my_specialties_label'), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.specialties.map(ServiceConstants.getDisplayName).join(', '),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            Text(tr('distancia_alertas'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(tr('mi_1'), style: const TextStyle(color: Colors.grey)),
                Text(tr('x_miles').replaceAll('{n}', '${_alertDistance.toInt()}'), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1976D2))),
                Text(tr('mi_50'), style: const TextStyle(color: Colors.grey)),
              ],
            ),
            Slider(
              value: _alertDistance,
              min: 1,
              max: 50,
              divisions: 49,
              activeColor: const Color(0xFF1976D2),
              inactiveColor: Colors.grey[200],
              onChanged: (value) => setState(() => _alertDistance = value),
            ),

            const SizedBox(height: 24),

            Text(tr('publish_date'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildSelectableBadge(tr('last_24h'), '24h', _selectedTime, (val) => setState(() => _selectedTime = val)),
                const SizedBox(width: 8),
                _buildSelectableBadge(tr('last_3_days'), '3d', _selectedTime, (val) => setState(() => _selectedTime = val)),
                const SizedBox(width: 8),
                _buildSelectableBadge(tr('always'), 'all', _selectedTime, (val) => setState(() => _selectedTime = val)),
              ],
            ),

            const SizedBox(height: 24),

            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: () {
                final result = FilterModel(
                  distance: _distance,
                  alertDistance: _alertDistance,
                  category: 'Todos',
                  status: 'Todos',
                  timeRange: _selectedTime,
                  searchQuery: _searchController.text.trim(),
                );
                Navigator.pop(context, result);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8A00),
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text(
                tr('show_results'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectableBadge(String label, String value, String groupValue, Function(String) onSelected) {
    final isSelected = value == groupValue;
    return GestureDetector(
      onTap: () => onSelected(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF8A00) : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
