import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/models/user_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/language_service.dart';
import '../../core/services/upload_service.dart';
import '../../core/widgets/photo_source_picker.dart';
import 'phone_verification_screen.dart';

class EditTechnicianProfileScreen extends StatefulWidget {
  final UserModel user;
  const EditTechnicianProfileScreen({super.key, required this.user});

  @override
  State<EditTechnicianProfileScreen> createState() => _EditTechnicianProfileScreenState();
}

class _EditTechnicianProfileScreenState extends State<EditTechnicianProfileScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final UploadService _uploadService = UploadService();
  final ImagePicker _picker = ImagePicker();
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

  String _licenseDocumentUrl = '';
  bool _licenseVerified = false;
  bool _uploadingLicense = false;

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
    _licenseDocumentUrl = widget.user.licenseDocumentUrl;
    _licenseVerified = widget.user.licenseVerified;
    _freeQuote = widget.user.freeQuote;
    _emergency = widget.user.emergencyService;
    _weekend = widget.user.weekendAvailability;
  }

  Future<void> _uploadLicense() async {
    final source = await PhotoSourcePicker.chooseSource(context);
    if (source == null) return;

    final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 70);
    if (pickedFile == null) return;

    setState(() => _uploadingLicense = true);
    try {
      final url = await _uploadService.uploadLicenseDocument(File(pickedFile.path), widget.user.id);
      if (url != null) {
        await _firestoreService.saveUser(UserModel.fromJson({
          ...widget.user.toJson(),
          'licenseDocumentUrl': url,
          '_id': widget.user.id,
        }));
        await _firestoreService.refreshUserStream(widget.user.id);
        if (mounted) setState(() => _licenseDocumentUrl = url);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('license_uploaded'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('generic_error')), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingLicense = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(tr('professional_profile_title'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
              Text(tr('public_info'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildField(tr('company_optional'), _companyController, icon: Icons.business),
              _buildField(tr('years_experience_label'), _experienceController, icon: Icons.history, keyboardType: TextInputType.number),
              _buildField(tr('main_city_area'), _cityController, icon: Icons.location_city),
              _buildField(tr('service_radius_km'), _radiusController, icon: Icons.radar, keyboardType: TextInputType.number),
              _buildPhoneTile(),
              _buildLicenseTile(),
              const SizedBox(height: 24),
              Text(tr('professional_bio'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bioController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: tr('bio_hint'),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),
              Text(tr('business_settings'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildWorkHoursField(),
              SwitchListTile(
                title: Text(tr('free_quote_offer')),
                value: _freeQuote,
                activeColor: const Color(0xFFFF8A00),
                onChanged: (val) => setState(() => _freeQuote = val),
              ),
              SwitchListTile(
                title: Text(tr('emergency_service_247')),
                value: _emergency,
                activeColor: const Color(0xFFFF8A00),
                onChanged: (val) => setState(() => _emergency = val),
              ),
              SwitchListTile(
                title: Text(tr('weekend_available')),
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
                  child: Text(tr('save_changes'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => PhoneVerificationScreen(initialPhone: _phoneNumber.isEmpty ? null : _phoneNumber),
      ),
    );
    // En ambos modos el backend ya persistió el número al volver de la pantalla
    // (verificado con OTP, o directo por el endpoint dedicado). Reflejamos en UI.
    if (result != null && result.isNotEmpty && mounted) {
      setState(() {
        _phoneNumber = result;
        _phoneVerified = kPhoneVerificationEnabled;
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
                      if (hasPhone && _phoneVerified && kPhoneVerificationEnabled) ...[
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
                kPhoneVerificationEnabled
                    ? (hasPhone ? tr('verify_change_phone') : tr('verify_phone'))
                    : (hasPhone ? tr('change_phone') : tr('add_phone')),
                style: const TextStyle(color: Color(0xFFFF8A00), fontWeight: FontWeight.bold),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLicenseTile() {
    final bool hasLicense = _licenseDocumentUrl.isNotEmpty;
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
            const Icon(Icons.badge_outlined, color: Color(0xFFFF8A00)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('license_or_id'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        hasLicense ? tr('license_uploaded_status') : tr('license_not_set'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      if (hasLicense && _licenseVerified) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified, color: Colors.green, size: 18),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (_uploadingLicense)
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            else
              TextButton(
                onPressed: _uploadLicense,
                child: Text(
                  hasLicense ? tr('change_license') : tr('add_license'),
                  style: const TextStyle(color: Color(0xFFFF8A00), fontWeight: FontWeight.bold),
                  textAlign: TextAlign.end,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkHoursField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: _hoursController,
        readOnly: true,
        onTap: _showWorkHoursPicker,
        decoration: InputDecoration(
          labelText: tr('work_hours'),
          hintText: tr('work_hours_hint'),
          prefixIcon: const Icon(Icons.schedule, color: Color(0xFFFF8A00)),
          suffixIcon: const Icon(Icons.arrow_drop_down),
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          labelStyle: const TextStyle(color: Colors.grey),
        ),
      ),
    );
  }

  Future<void> _showWorkHoursPicker() async {
    final Map<String, bool> days = {
      tr('day_mon_short'): false,
      tr('day_tue_short'): false,
      tr('day_wed_short'): false,
      tr('day_thu_short'): false,
      tr('day_fri_short'): false,
      tr('day_sat_short'): false,
      tr('day_sun_short'): false,
    };
    final weekdayKeys = days.keys.take(5).toList();
    TimeOfDay fromTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay toTime = const TimeOfDay(hour: 18, minute: 0);

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          void applyPreset({required bool everyDay, required TimeOfDay from, required TimeOfDay to}) {
            setDialogState(() {
              for (final key in days.keys) {
                days[key] = everyDay || weekdayKeys.contains(key);
              }
              fromTime = from;
              toTime = to;
            });
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(tr('work_hours'), style: const TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('quick_presets'), style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        label: Text(tr('preset_weekdays_9_18')),
                        onPressed: () => applyPreset(
                          everyDay: false,
                          from: const TimeOfDay(hour: 9, minute: 0),
                          to: const TimeOfDay(hour: 18, minute: 0),
                        ),
                      ),
                      ActionChip(
                        label: Text(tr('preset_everyday_9_18')),
                        onPressed: () => applyPreset(
                          everyDay: true,
                          from: const TimeOfDay(hour: 9, minute: 0),
                          to: const TimeOfDay(hour: 18, minute: 0),
                        ),
                      ),
                      ActionChip(
                        label: Text(tr('preset_24_7')),
                        onPressed: () {
                          setState(() => _hoursController.text = tr('available_24_7'));
                          Navigator.pop(dialogContext);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(tr('select_work_days'), style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: days.keys.map((day) {
                      final bool selected = days[day]!;
                      return ChoiceChip(
                        label: Text(day),
                        selected: selected,
                        selectedColor: const Color(0xFFFF8A00),
                        labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87),
                        onSelected: (val) => setDialogState(() => days[day] = val),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(tr('from_time')),
                    trailing: Text(fromTime.format(dialogContext), style: const TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () async {
                      final picked = await showTimePicker(context: dialogContext, initialTime: fromTime);
                      if (picked != null) setDialogState(() => fromTime = picked);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(tr('to_time')),
                    trailing: Text(toTime.format(dialogContext), style: const TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () async {
                      final picked = await showTimePicker(context: dialogContext, initialTime: toTime);
                      if (picked != null) setDialogState(() => toTime = picked);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(tr('cancel'))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF8A00)),
                onPressed: () {
                  final selectedDays = days.entries.where((e) => e.value).map((e) => e.key).toList();
                  if (selectedDays.isEmpty) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text(tr('select_days_error'))),
                    );
                    return;
                  }
                  final formatted = '${selectedDays.join(', ')} ${fromTime.format(dialogContext)} - ${toTime.format(dialogContext)}';
                  setState(() => _hoursController.text = formatted);
                  Navigator.pop(dialogContext);
                },
                child: Text(tr('save'), style: const TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
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
      // El teléfono NO va aquí: se guarda al editarlo, vía su endpoint dedicado.
    };

    try {
      await _firestoreService.saveUser(UserModel.fromJson({
        ...widget.user.toJson(),
        ...updatedData,
        '_id': widget.user.id,
      }));
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('professional_profile_updated'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('error_label')}: $e'), backgroundColor: Colors.red));
      }
    }
  }
}
