import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../core/services/auth_service.dart';
import '../../core/models/service_request.dart';
import '../../core/models/user_model.dart';
import '../../core/models/alert_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/upload_service.dart';
import '../../core/services/ai_service.dart';
import '../../core/services/language_service.dart';
import '../../core/widgets/photo_source_picker.dart';

import '../../core/config/service_constants.dart';

class PublishServiceRequestScreen extends StatefulWidget {
  const PublishServiceRequestScreen({super.key});

  @override
  State<PublishServiceRequestScreen> createState() => _PublishServiceRequestScreenState();
}

class _PublishServiceRequestScreenState extends State<PublishServiceRequestScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final LocationService _locationService = LocationService();
  final UploadService _uploadService = UploadService();
  final AIService _aiService = AIService();

  int _currentStep = 1;
  bool _isLoading = false;
  bool _isAnalyzing = false;

  // Form State
  String? _selectedCategory;
  final List<File> _imageFiles = [];
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _addressController = TextEditingController(text: tr('detecting_location'));
  UrgencyLevel _selectedUrgency = UrgencyLevel.medium;
  Position? _currentPosition;
  String? _targetTechnicianId;
  UserModel? _targetTechnician;

  final List<Map<String, dynamic>> _categories = ServiceConstants.allCategories;

  @override
  void initState() {
    super.initState();
    _initLocation();
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String) {
        setState(() => _targetTechnicianId = args);
        final tech = await _firestoreService.getUser(args);
        if (mounted && tech != null) {
          setState(() {
            _targetTechnician = tech;
            
            // Auto-select if tech has only one specialty that matches our categories
            final matchingCats = _categories.where((c) => tech.specialties.contains(c['name'])).toList();
            if (matchingCats.length == 1) {
              _selectedCategory = matchingCats.first['name'];
            }
          });
        }
      }
    });
  }

  Future<void> _initLocation() async {
    final hasPermission = await _locationService.checkAndRequestPermissions();
    if (hasPermission) {
      final position = await _locationService.getCurrentLocation();
      if (position != null) {
        setState(() => _currentPosition = position);
        _getAddressFromLatLng(position);
      }
    }
  }

  Future<void> _getAddressFromLatLng(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        // More detailed address: Street Name + Number, City
        String address = '';
        if (place.street != null && place.street!.isNotEmpty) {
          address += place.street!;
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          if (address.isNotEmpty) address += ', ';
          address += place.locality!;
        }
        
        setState(() => _addressController.text = address.isNotEmpty ? address : tr('location_detected'));
      }
    } catch (e) {
      setState(() => _addressController.text = tr('location_manual'));
    }
  }

  static const int _maxPhotos = 3;

  Future<void> _pickImage() async {
    if (_imageFiles.length >= _maxPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('max_photos_reached'))),
      );
      return;
    }

    final bool wasEmpty = _imageFiles.isEmpty;
    final newFiles = await PhotoSourcePicker.pick(
      context,
      remaining: _maxPhotos - _imageFiles.length,
    );
    if (newFiles.isEmpty || !mounted) return;

    setState(() => _imageFiles.addAll(newFiles));
    // Analiza la primera foto con IA solo cuando antes no había ninguna.
    if (wasEmpty) _analyzeImage(_imageFiles.first);
  }

  Future<void> _analyzeImage(File imageFile) async {
    setState(() => _isAnalyzing = true);
    try {
      final suggestion = await _aiService.analyzeObjectImage(imageFile);
      if (suggestion != null && mounted) {
        setState(() {
          _titleController.text = suggestion['title'] ?? '';
          _descriptionController.text = suggestion['description'] ?? '';
        });
      }
    } catch (e) {
      print('Error AI: $e');
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _publish() async {
    if (_titleController.text.isEmpty || _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('select_category_title'))),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      final uid = AuthService.currentUidSync;
      if (uid.isEmpty) {
        throw Exception(tr('must_be_authenticated_to_publish'));
      }

      List<String> imageUrls = [];
      List<String> thumbnailUrls = [];
      for (var file in _imageFiles) {
        try {
          final result = await _uploadService.uploadOptimizedImage(file, 'service_requests');
          imageUrls.add(result['full']!);
          thumbnailUrls.add(result['thumb']!);
        } catch (e) {
          print('Error subiendo imagen: $e');
          throw Exception(tr('error_uploading_image_generic').replaceAll('{e}', '$e'));
        }
      }

      final request = ServiceRequest(
        id: '',
        title: _titleController.text,
        description: _descriptionController.text,
        category: _selectedCategory!,
        imageUrls: imageUrls,
        thumbnailUrls: thumbnailUrls,
        latitude: _currentPosition?.latitude ?? 0.0,
        longitude: _currentPosition?.longitude ?? 0.0,
        address: _addressController.text,
        status: ServiceRequestStatus.open,
        urgency: _selectedUrgency,
        clientId: uid,
        clientName: 'Cliente',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        targetTechnicianId: _targetTechnicianId,
      );

      final String requestId = await _firestoreService.createServiceRequest(request);
      
      // If there is a target technician, notify them via an alert
      if (_targetTechnicianId != null) {
        final alert = AlertModel(
          id: '',
          requestId: requestId,
          requestTitle: request.title,
          requestImageUrl: request.imageUrls.isNotEmpty ? request.imageUrls[0] : '',
          address: request.address,
          distance: 0,
          createdAt: DateTime.now(),
          type: AlertType.directQuote,
        );
        await _firestoreService.saveUserAlert(_targetTechnicianId!, alert);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('problem_published')), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('--- ERROR AL PUBLICAR ---');
      print(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tr('error_label')}: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(tr('publish_problem')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentStep > 1) setState(() => _currentStep--);
            else Navigator.pop(context);
          },
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : Column(
            children: [
              _buildStepIndicator(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: _buildCurrentStep(),
                ),
              ),
              _buildBottomButton(),
            ],
          ),
    );
  }

  Widget _buildStepIndicator() {
    return Column(
      children: [
        if (_targetTechnician != null)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            margin: const EdgeInsets.only(bottom: 8),
            color: Colors.blue.withValues(alpha: 0.1),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('requesting_direct_quote').replaceAll('{name}', _targetTechnician!.name),
                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [1, 2, 3].map((step) {
              bool isActive = step <= _currentStep;
              return Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: isActive ? const Color(0xFFFF8A00) : Colors.grey[300],
                    child: Text('$step', style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                  if (step < 3) Container(width: 40, height: 2, color: step < _currentStep ? const Color(0xFFFF8A00) : Colors.grey[300]),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 1: return _stepCategory();
      case 2: return _stepDetails();
      case 3: return _stepLocation();
      default: return const SizedBox();
    }
  }

  Widget _stepCategory() {
    List<Map<String, dynamic>> displayCategories = _categories;

    if (_targetTechnician != null && _targetTechnician!.specialties.isNotEmpty) {
      displayCategories = _categories.where((cat) {
        return _targetTechnician!.specialties.contains(cat['name']);
      }).toList();
      
      // Always allow "Otros" if needed or keep it strict? 
      // User says "ONLY that matches skill". So I keep it strict.
      // If no matches found (shouldn't happen if profile is correct), 
      // we show what we found.
      if (displayCategories.isEmpty) {
         displayCategories = _categories.where((cat) => cat['name'] == 'Otros').toList();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('what_problem_type'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2.5,
          ),
          itemCount: displayCategories.length,
          itemBuilder: (context, index) {
            final cat = displayCategories[index];
            bool isSelected = _selectedCategory == cat['name'];
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat['name']),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFFF8A00) : Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isSelected ? const Color(0xFFFF8A00) : Colors.grey[200]!),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(cat['icon'], color: isSelected ? Colors.white : cat['color']),
                    const SizedBox(width: 8),
                    Flexible(child: Text(ServiceConstants.getDisplayName(cat['name']), style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.w500))),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _stepDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('tell_us_more'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        
        // Photos (hasta 3, cámara o galería)
        Text(tr('step_add_photos'), style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (int i = 0; i < _imageFiles.length; i++) _buildPhotoThumb(i),
              if (_imageFiles.length < _maxPhotos) _buildAddPhotoTile(),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Title
        Text(tr('step_problem_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _titleController, 
          decoration: InputDecoration(hintText: _getTitleHint()),
        ),
        const SizedBox(height: 24),

        // Description
        Text(tr('step_describe_problem'), style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionController, 
          maxLines: 3, 
          decoration: InputDecoration(hintText: _getDescriptionHint()),
        ),
        const SizedBox(height: 24),

        // Urgency
        Text(tr('step_urgency'), style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: UrgencyLevel.values.map((u) {
            bool sel = _selectedUrgency == u;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedUrgency = u),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: sel ? const Color(0xFFFF8A00) : Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                  alignment: Alignment.center,
                  child: Text(_getUrgencyText(u), style: TextStyle(color: sel ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPhotoThumb(int index) {
    return Container(
      width: 110,
      height: 110,
      margin: const EdgeInsets.only(right: 12),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(_imageFiles[index], width: 110, height: 110, fit: BoxFit.cover),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => setState(() => _imageFiles.removeAt(index)),
              child: Container(
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                padding: const EdgeInsets.all(4),
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddPhotoTile() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_a_photo_outlined, size: 36, color: Colors.grey),
            const SizedBox(height: 4),
            Text(tr('add_photo'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _stepLocation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('confirm_location'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
          child: Row(
            children: [
              const Icon(Icons.location_on, color: Color(0xFFFF8A00)),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.grey), 
                onPressed: () {
                  _addressController.text = 'Actualizando...';
                  _initLocation();
                }
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(tr('address_correct_hint'), style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 4),
        Text(tr('tech_will_arrive'), style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildBottomButton() {
    bool canProceed = false;
    if (_currentStep == 1 && _selectedCategory != null) canProceed = true;
    if (_currentStep == 2 && _titleController.text.isNotEmpty) canProceed = true;
    if (_currentStep == 3) canProceed = true;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: ElevatedButton(
        onPressed: canProceed ? () {
          if (_currentStep < 3) setState(() => _currentStep++);
          else _publish();
        } : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF8A00),
          disabledBackgroundColor: Colors.grey[300],
        ),
        child: Text(_currentStep == 3 ? tr('publish_now') : tr('next')),
      ),
    );
  }

  String _getUrgencyText(UrgencyLevel u) {
    switch (u) {
      case UrgencyLevel.low: return tr('urgency_low');
      case UrgencyLevel.medium: return tr('urgency_medium');
      case UrgencyLevel.high: return tr('urgency_high');
    }
  }

  String _getTitleHint() {
    switch (_selectedCategory) {
      case 'Electricidad': return tr('th_elec');
      case 'Plomería': return tr('th_plom');
      case 'Aire Acond.': return tr('th_aire');
      case 'Pintura': return tr('th_pint');
      case 'Techos': return tr('th_tech');
      case 'Carpintería': return tr('th_carp');
      case 'Drywall y Reparación de Paredes': return tr('th_drywall');
      case 'Electrodomésticos': return tr('th_appliance');
      case 'Jardinería': return tr('th_garden');
      case 'Limpieza': return tr('th_clean');
      case 'Cámaras y Seguridad': return tr('th_security');
      case 'TV y Montaje': return tr('th_tv');
      case 'Puertas y Ventanas': return tr('th_doors');
      case 'Mudanzas': return tr('th_moving');
      case 'Handyman': return tr('th_handyman');
      default: return tr('th_default');
    }
  }

  String _getDescriptionHint() {
    switch (_selectedCategory) {
      case 'Electricidad': return tr('dh_elec');
      case 'Plomería': return tr('dh_plom');
      case 'Aire Acond.': return tr('dh_aire');
      case 'Pintura': return tr('dh_pint');
      case 'Techos': return tr('dh_tech');
      case 'Carpintería': return tr('dh_carp');
      case 'Drywall y Reparación de Paredes': return tr('dh_drywall');
      case 'Electrodomésticos': return tr('dh_appliance');
      case 'Jardinería': return tr('dh_garden');
      case 'Limpieza': return tr('dh_clean');
      case 'Cámaras y Seguridad': return tr('dh_security');
      case 'TV y Montaje': return tr('dh_tv');
      case 'Puertas y Ventanas': return tr('dh_doors');
      case 'Mudanzas': return tr('dh_moving');
      case 'Handyman': return tr('dh_handyman');
      default: return tr('dh_default');
    }
  }
}
