import 'package:flutter/material.dart';
import '../../core/models/user_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/language_service.dart';
import 'phone_verification_screen.dart';

class EditTechnicianProfileScreen extends StatefulWidget {
  final UserModel user;
  const EditTechnicianProfileScreen({super.key, required this.user});

  @override
  State<EditTechnicianProfileScreen> createState() => _EditTechnicianProfileScreenState();
}

class _EditTechnicianProfileScreenState extends State<EditTechnicianProfileScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _bioController;
  late TextEditingController _companyController;
  late TextEditingController _experienceController;
  late TextEditingController _cityController;
  late TextEditingController _radiusController;
  late TextEditingController _hoursController;

  // El teléfono no se edita como texto plano: cambiarlo exige verificación SMS.
  String _phoneNumber = '';
  bool _phoneVerified = false;

  bool _freeQuote = true;
  bool _emergency = false;
  bool _weekend = false;

  @override
  void initState() {
    super.initState();
    _bioController = TextEditingController(text: widget.user.bio);
    _companyController = TextEditingController(text: widget.user.companyName);
    _experienceController = TextEditingController(text: widget.user.yearsOfExperience.toString());
    _cityController = TextEditingController(text: widget.user.city);
    _radiusController = TextEditingController(text: widget.user.serviceRadius.toString());
    _hoursController = TextEditingController(text: widget.user.workHours);
    _phoneNumber = widget.user.phoneNumber ?? '';
    _phoneVerified = widget.user.phoneVerified;
    _freeQuote = widget.user.freeQuote;
    _emergency = widget.user.emergencyService;
    _weekend = widget.user.weekendAvailability;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Perfil Profesional', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Información Pública', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildField('Empresa (Opcional)', _companyController, icon: Icons.business),
              _buildField('Años de Experiencia', _experienceController, icon: Icons.history, keyboardType: TextInputType.number),
              _buildField('Ciudad / Área Principal', _cityController, icon: Icons.location_city),
              _buildField('Radio de Servicio (km)', _radiusController, icon: Icons.radar, keyboardType: TextInputType.number),
              _buildPhoneTile(),
              const SizedBox(height: 24),
              const Text('Biografía Profesional', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bioController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Cuéntale a tus clientes sobre tu experiencia y servicios...',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Configuración Comercial', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildField('Horario de Trabajo', _hoursController, icon: Icons.schedule, hint: 'Ej: Lunes a Viernes 9am - 6pm'),
              SwitchListTile(
                title: const Text('Ofrezco Presupuesto Gratis'),
                value: _freeQuote,
                activeColor: const Color(0xFFFF8A00),
                onChanged: (val) => setState(() => _freeQuote = val),
              ),
              SwitchListTile(
                title: const Text('Atención de Emergencias 24/7'),
                value: _emergency,
                activeColor: const Color(0xFFFF8A00),
                onChanged: (val) => setState(() => _emergency = val),
              ),
              SwitchListTile(
                title: const Text('Disponible Fines de Semana'),
                value: _weekend,
                activeColor: const Color(0xFFFF8A00),
                onChanged: (val) => setState(() => _weekend = val),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8A00),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Guardar Cambios', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPhoneVerification() async {
    final verified = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => PhoneVerificationScreen(initialPhone: _phoneNumber.isEmpty ? null : _phoneNumber),
      ),
    );
    // El backend ya persistió el número y phoneVerified=true; reflejamos en UI.
    if (verified != null && verified.isNotEmpty && mounted) {
      setState(() {
        _phoneNumber = verified;
        _phoneVerified = true;
      });
    }
  }

  Widget _buildPhoneTile() {
    final bool hasPhone = _phoneNumber.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.phone, color: Color(0xFFFF8A00)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('contact_phone'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        hasPhone ? _phoneNumber : tr('phone_not_set'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      if (hasPhone && _phoneVerified) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified, color: Colors.green, size: 18),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _openPhoneVerification,
              child: Text(
                hasPhone ? tr('verify_change_phone') : tr('verify_phone'),
                style: const TextStyle(color: Color(0xFFFF8A00), fontWeight: FontWeight.bold),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {IconData? icon, TextInputType? keyboardType, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: icon != null ? Icon(icon, color: const Color(0xFFFF8A00)) : null,
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          labelStyle: const TextStyle(color: Colors.grey),
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final updatedData = {
      'bio': _bioController.text.trim(),
      'companyName': _companyController.text.trim(),
      'yearsOfExperience': int.tryParse(_experienceController.text) ?? 0,
      'city': _cityController.text.trim(),
      'serviceRadius': double.tryParse(_radiusController.text) ?? 20.0,
      'workHours': _hoursController.text.trim(),
      'freeQuote': _freeQuote,
      'emergencyService': _emergency,
      'weekendAvailability': _weekend,
    };

    try {
      await _firestoreService.saveUser(UserModel.fromJson({
        ...widget.user.toJson(),
        ...updatedData,
        '_id': widget.user.id,
      }));
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil profesional actualizado')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }
}
