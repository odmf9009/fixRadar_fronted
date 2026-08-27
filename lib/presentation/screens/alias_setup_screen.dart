import 'package:flutter/material.dart';
import '../../core/config/routes.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/language_service.dart';

/// Paso obligatorio: el usuario debe elegir un alias público antes de poder
/// usar el resto de la app. El alias es lo que se muestra en todos lados en
/// vez del nombre real (perfil público, listados de técnicos, chat, etc.).
class AliasSetupScreen extends StatefulWidget {
  const AliasSetupScreen({super.key});

  @override
  State<AliasSetupScreen> createState() => _AliasSetupScreenState();
}

class _AliasSetupScreenState extends State<AliasSetupScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _controller = TextEditingController();
  bool _isSaving = false;
  String? _error;

  Future<void> _submit() async {
    final alias = _controller.text.trim();
    if (alias.length < 3) {
      setState(() => _error = tr('alias_too_short'));
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final userId = AuthService.currentUidSync;
      await _firestoreService.updateUserAlias(userId, alias);
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    } catch (e) {
      if (mounted) setState(() => _error = tr('generic_error'));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/logo_centro.png', height: 100),
                const SizedBox(height: 30),
                Text(
                  tr('set_public_alias'),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  tr('alias_desc'),
                  style: const TextStyle(fontSize: 15, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: tr('alias_hint'),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    errorText: _error,
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8A00),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(tr('continue_btn'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
