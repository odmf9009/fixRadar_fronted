import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/language_service.dart';

/// Interruptor del flujo de verificación por SMS.
///
/// TEMPORAL: mientras no haya cuenta de Twilio configurada lo dejamos en `false`,
/// de modo que el usuario solo edita el número (país + dígitos) y se guarda sin
/// comprobación. Cambiar a `true` para reactivar el OTP por SMS.
const bool kPhoneVerificationEnabled = false;

/// Verificación del teléfono por **SMS (OTP vía Twilio)**.
///
/// Objetivo: comprobar que el número que ingresa el profesional existe y que él
/// lo controla (recibe el SMS) antes de guardarlo en su perfil.
///
/// Paso 1: el usuario escribe el número → el backend genera un código y lo envía
/// por SMS (`POST /users/me/phone/send-code`).
/// Paso 2: escribe el código recibido → el backend lo valida y guarda el número
/// como verificado (`POST /users/me/phone/verify`). Al terminar hace
/// `Navigator.pop(context, phone)`.
class PhoneVerificationScreen extends StatefulWidget {
  final String? initialPhone;
  const PhoneVerificationScreen({super.key, this.initialPhone});

  @override
  State<PhoneVerificationScreen> createState() => _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  bool _codeSent = false;
  bool _isLoading = false;
  String _phone = '';

  // País seleccionado para el prefijo telefónico. Por defecto Colombia.
  _Country _country = _countries.firstWhere((c) => c.dial == '+57');

  static const Color _primary = Color(0xFFFF8A00);

  @override
  void initState() {
    super.initState();
    // Si llega un número previo con prefijo (+57…), preseleccionamos el país y
    // dejamos en el input solo la parte local. Si no, todo va al input.
    final initial = (widget.initialPhone ?? '').replaceAll(' ', '').trim();
    if (initial.startsWith('+')) {
      final match = _countries
          .where((c) => initial.startsWith(c.dial))
          .fold<_Country?>(null, (best, c) =>
              best == null || c.dial.length > best.dial.length ? c : best);
      if (match != null) {
        _country = match;
        _phoneController.text = initial.substring(match.dial.length);
      } else {
        _phoneController.text = initial.replaceAll(RegExp(r'\D'), '');
      }
    } else {
      _phoneController.text = initial.replaceAll(RegExp(r'\D'), '');
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  // Paso 1: pedir al backend que envíe el SMS con el código al número.
  Future<void> _sendCode() async {
    // El input solo contiene dígitos locales; anteponemos el código de país.
    final local = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (local.length < 6) {
      _showError(tr('phone_invalid'));
      return;
    }
    final phone = '${_country.dial}$local';

    // Sin verificación: devolvemos el número para que el perfil lo guarde directo.
    if (!kPhoneVerificationEnabled) {
      Navigator.pop(context, phone);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _firestoreService.sendPhoneVerificationCode(phone);
      if (!mounted) return;
      setState(() {
        _phone = phone;
        _codeSent = true;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError(e.toString());
      }
    }
  }

  // Paso 2: confirmar el código con el backend; si coincide, guarda el número.
  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length < 6) return;

    setState(() => _isLoading = true);
    try {
      await _firestoreService.verifyPhoneCode(_phone, code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('phone_verified_success')), backgroundColor: Colors.green),
      );
      Navigator.pop(context, _phone);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError(e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageService(),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Text(kPhoneVerificationEnabled ? tr('verify_phone') : tr('edit_phone'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: const Color(0xFF121212),
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _codeSent ? _buildCodeStep() : _buildPhoneStep(),
          ),
        );
      },
    );
  }

  Widget _buildPhoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('phone_number'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(tr('phone_enter_hint'), style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 16),
        Row(
          children: [
            // Selector de código de país.
            InkWell(
              onTap: _isLoading ? null : _pickCountry,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_country.flag, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 6),
                    Text(_country.dial,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Input: solo dígitos del número local.
            Expanded(
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.phone, color: _primary),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        _primaryButton(kPhoneVerificationEnabled ? tr('send_code') : tr('save'),
            _isLoading ? null : _sendCode),
      ],
    );
  }

  Widget _buildCodeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${tr('enter_code_sent')} $_phone',
            style: const TextStyle(fontSize: 15, color: Colors.black87)),
        const SizedBox(height: 20),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 28),
        _primaryButton(tr('verify'), _isLoading ? null : _verify),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _isLoading ? null : _sendCode,
            child: Text(tr('resend_code'), style: const TextStyle(color: _primary)),
          ),
        ),
      ],
    );
  }

  // Hoja inferior con buscador para elegir el país (prefijo telefónico).
  Future<void> _pickCountry() async {
    final selected = await showModalBottomSheet<_Country>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setSheet) {
            final filtered = _countries.where((c) {
              final q = query.toLowerCase();
              return q.isEmpty ||
                  c.name.toLowerCase().contains(q) ||
                  c.dial.contains(q);
            }).toList();
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: FractionallySizedBox(
                heightFactor: 0.8,
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        autofocus: true,
                        onChanged: (v) => setSheet(() => query = v),
                        decoration: InputDecoration(
                          hintText: tr('search_country'),
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final c = filtered[i];
                          return ListTile(
                            leading: Text(c.flag, style: const TextStyle(fontSize: 24)),
                            title: Text(c.name),
                            trailing: Text(c.dial,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            onTap: () => Navigator.pop(context, c),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (selected != null && mounted) {
      setState(() => _country = selected);
    }
  }

  Widget _primaryButton(String label, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isLoading
            ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}

/// País con su prefijo telefónico (E.164) y bandera para el selector.
class _Country {
  final String name;
  final String dial;
  final String flag;
  const _Country(this.name, this.dial, this.flag);
}

// Códigos de país. Colombia primero por ser el mercado principal.
const List<_Country> _countries = [
  _Country('Colombia', '+57', '🇨🇴'),
  _Country('Argentina', '+54', '🇦🇷'),
  _Country('Bolivia', '+591', '🇧🇴'),
  _Country('Chile', '+56', '🇨🇱'),
  _Country('Costa Rica', '+506', '🇨🇷'),
  _Country('Cuba', '+53', '🇨🇺'),
  _Country('Ecuador', '+593', '🇪🇨'),
  _Country('El Salvador', '+503', '🇸🇻'),
  _Country('España', '+34', '🇪🇸'),
  _Country('Estados Unidos', '+1', '🇺🇸'),
  _Country('Guatemala', '+502', '🇬🇹'),
  _Country('Honduras', '+504', '🇭🇳'),
  _Country('México', '+52', '🇲🇽'),
  _Country('Nicaragua', '+505', '🇳🇮'),
  _Country('Panamá', '+507', '🇵🇦'),
  _Country('Paraguay', '+595', '🇵🇾'),
  _Country('Perú', '+51', '🇵🇪'),
  _Country('Puerto Rico', '+1787', '🇵🇷'),
  _Country('República Dominicana', '+1809', '🇩🇴'),
  _Country('Uruguay', '+598', '🇺🇾'),
  _Country('Venezuela', '+58', '🇻🇪'),
  _Country('Brasil', '+55', '🇧🇷'),
  _Country('Portugal', '+351', '🇵🇹'),
];
