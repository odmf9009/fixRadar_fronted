import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/models/service_request.dart';
import '../../core/models/user_model.dart';
import '../../core/models/alert_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/upload_service.dart';
import '../../core/services/ai_service.dart';

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
  final ImagePicker _picker = ImagePicker();

  int _currentStep = 1;
  bool _isLoading = false;
  bool _isAnalyzing = false;

  // Form State
  String? _selectedCategory;
  final List<File> _imageFiles = [];
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  UrgencyLevel _selectedUrgency = UrgencyLevel.medium;
  Position? _currentPosition;
  String _currentAddress = 'Detectando ubicación...';
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
        setState(() => _currentAddress = '${place.street}, ${place.locality}');
      }
    } catch (e) {
      setState(() => _currentAddress = 'Ubicación manual');
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (pickedFile != null) {
      setState(() => _imageFiles.add(File(pickedFile.path)));
      if (_imageFiles.length == 1) _analyzeImage(File(pickedFile.path));
    }
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
    if (_imageFiles.isEmpty || _titleController.text.isEmpty || _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos y añade una foto.')),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Debes estar autenticado para publicar.');
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
          throw Exception('Error al subir la imagen. Verifica tu conexión y los permisos de Storage.');
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
        address: _currentAddress,
        status: ServiceRequestStatus.open,
        urgency: _selectedUrgency,
        clientId: user.uid,
        clientName: user.displayName ?? 'Cliente',
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
          const SnackBar(content: Text('¡Problema publicado con éxito!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('--- ERROR AL PUBLICAR ---');
      print(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
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
        title: const Text('Publicar problema'),
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
                    'Solicitando cotización directa a ${_targetTechnician!.name}',
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
        const Text('¿Qué tipo de problema es?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                    Flexible(child: Text(cat['name'], style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.w500))),
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
        const Text('Cuéntanos más detalles', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        
        // Photo
        const Text('1. Toma una foto del problema', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!)),
            child: _imageFiles.isEmpty 
              ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt_outlined, size: 40, color: Colors.grey), Text('Agregar foto', style: TextStyle(color: Colors.grey))])
              : Image.file(_imageFiles[0], fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 24),

        // Title
        const Text('2. Título del problema', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _titleController, 
          decoration: InputDecoration(hintText: _getTitleHint()),
        ),
        const SizedBox(height: 24),

        // Description
        const Text('3. Describe el problema', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionController, 
          maxLines: 3, 
          decoration: InputDecoration(hintText: _getDescriptionHint()),
        ),
        const SizedBox(height: 24),

        // Urgency
        const Text('4. ¿Qué tan urgente es?', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _stepLocation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Confirma tu ubicación', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
          child: Row(
            children: [
              const Icon(Icons.location_on, color: Color(0xFFFF8A00)),
              const SizedBox(width: 12),
              Expanded(child: Text(_currentAddress, style: const TextStyle(fontSize: 16))),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _initLocation),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('Un técnico llegará a esta dirección para asistirte.', style: TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildBottomButton() {
    bool canProceed = false;
    if (_currentStep == 1 && _selectedCategory != null) canProceed = true;
    if (_currentStep == 2 && _imageFiles.isNotEmpty && _titleController.text.isNotEmpty) canProceed = true;
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
        child: Text(_currentStep == 3 ? 'Publicar ahora' : 'Siguiente'),
      ),
    );
  }

  String _getUrgencyText(UrgencyLevel u) {
    switch (u) {
      case UrgencyLevel.low: return 'Baja';
      case UrgencyLevel.medium: return 'Media';
      case UrgencyLevel.high: return 'Alta';
    }
  }

  String _getTitleHint() {
    switch (_selectedCategory) {
      case 'Electricidad': return 'Ej: Cortocircuito / Tomacorriente quemado';
      case 'Plomería': return 'Ej: Tubería rota / Fuga de agua';
      case 'Aire Acond.': return 'Ej: Aire no enfría / Goteo unidad interna';
      case 'Pintura': return 'Ej: Pintar fachada / Humedad en pared';
      case 'Techos': return 'Ej: Gotera en el techo / Teja rota';
      case 'Carpintería': return 'Ej: Puerta no cierra / Mueble roto';
      case 'Drywall y Reparación de Paredes': return 'Ej: Hueco en la pared / Grieta en el techo';
      case 'Electrodomésticos': return 'Ej: Lavadora no centrifuga / Refrigerador ruidoso';
      case 'Jardinería': return 'Ej: Podar césped / Plaga en plantas';
      case 'Limpieza': return 'Ej: Limpieza profunda / Lavado de alfombras';
      case 'Cámaras y Seguridad': return 'Ej: Cámara no graba / Instalación de DVR';
      case 'TV y Montaje': return 'Ej: Montaje de TV 65" / Cableado oculto';
      case 'Puertas y Ventanas': return 'Ej: Cerradura trabada / Vidrio roto';
      case 'Mudanzas': return 'Ej: Mudanza pequeña / Acarreo de muebles';
      case 'Handyman': return 'Ej: Reparación general / Varios arreglos';
      default: return 'Ej: Describa brevemente el problema';
    }
  }

  String _getDescriptionHint() {
    switch (_selectedCategory) {
      case 'Electricidad': return 'Se fue la luz en la cocina después de conectar el horno...';
      case 'Plomería': return 'Se rompió la tubería debajo del fregadero y hay mucha agua...';
      case 'Aire Acond.': return 'El aire acondicionado enciende pero no sale aire frío...';
      case 'Pintura': return 'Necesito pintar el cuarto de los niños, unos 12 m2 aprox...';
      case 'Techos': return 'Cada vez que llueve cae agua cerca de la lámpara del comedor...';
      case 'Carpintería': return 'La bisagra de la puerta principal se rompió y no cierra bien...';
      case 'Drywall y Reparación de Paredes': return 'Se hizo un hueco en la pared de yeso al mover un mueble...';
      case 'Electrodomésticos': return 'La lavadora se detiene a mitad del ciclo y muestra un error E3...';
      case 'Jardinería': return 'El césped está muy alto y necesito podar los arbustos del frente...';
      case 'Limpieza': return 'Busco limpieza general de un apartamento de 2 habitaciones...';
      case 'Cámaras y Seguridad': return 'Necesito instalar 4 cámaras de seguridad con visión nocturna...';
      case 'TV y Montaje': return 'Instalación de soporte de pared para TV y configuración de sonido...';
      case 'Puertas y Ventanas': return 'La ventana no desliza bien y la cerradura está floja...';
      case 'Mudanzas': return 'Traslado de muebles de un piso 2 a una casa de una planta...';
      case 'Handyman': return 'Tengo varios arreglos pequeños pendientes en casa...';
      default: return 'Cuéntanos más detalles sobre el problema técnico...';
    }
  }
}
