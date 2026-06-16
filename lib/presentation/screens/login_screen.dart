import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/config/routes.dart';
import '../../core/services/auth_service.dart';
import '../../core/models/user_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _referralController = TextEditingController();
  final _codeController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _codeSent = false;
  bool _isSendingCode = false;
  bool _obscurePassword = true;

  // Countdown for resend button
  int _resendCountdown = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _referralController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  // ─── Send verification code ────────────────────────────────────────────────

  Future<void> _sendVerificationCode() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      _showError('Ingresa un email válido primero');
      return;
    }

    setState(() => _isSendingCode = true);
    try {
      await _authService.sendVerificationCode(email);
      setState(() {
        _codeSent = true;
        _resendCountdown = 60;
      });
      _startResendTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Código enviado. Revisa tu correo.'),
            backgroundColor: Color(0xFFFF8A00),
          ),
        );
      }
    } catch (e) {
      _showError(_parseError(e));
    } finally {
      if (mounted) setState(() => _isSendingCode = false);
    }
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCountdown <= 1) {
        t.cancel();
        if (mounted) setState(() => _resendCountdown = 0);
      } else {
        if (mounted) setState(() => _resendCountdown--);
      }
    });
  }

  // ─── Submit (login or register) ───────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isLogin && !_codeSent) {
      _showError('Primero envía el código de verificación a tu correo');
      return;
    }

    setState(() => _isLoading = true);
    try {
      UserModel? userModel;

      if (_isLogin) {
        userModel = await _authService.signInWithEmailBackend(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      } else {
        userModel = await _authService.signUpWithEmailBackend(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          _nameController.text.trim(),
          _codeController.text.trim(),
          referralCode: _referralController.text.trim().isEmpty
              ? null
              : _referralController.text.trim(),
        );
      }

      if (mounted && userModel != null) {
        _navigateAfterAuth(userModel);
      }
    } catch (e) {
      if (mounted) _showError(_parseError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Google Sign-In ────────────────────────────────────────────────────────

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final userModel = await _authService.signInWithGoogle();
      if (mounted && userModel != null) {
        _navigateAfterAuth(userModel);
      }
    } catch (e) {
      if (mounted) _showError('Error con Google: ${_parseError(e)}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Navigation ────────────────────────────────────────────────────────────

  void _navigateAfterAuth(UserModel user) {
    if (!user.onboardingCompleted || user.userType == null) {
      Navigator.pushReplacementNamed(context, AppRoutes.roleSelection);
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String _parseError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        return data['message']?.toString() ?? data['error']?.toString() ?? 'Error del servidor';
      }
      return 'Error de conexión';
    }
    return e.toString();
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _codeSent = false;
      _resendCountdown = 0;
      _resendTimer?.cancel();
      _codeController.clear();
    });
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Center(
                  child: Image.asset(
                    'assets/logo_centro.png',
                    height: 160,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 32),
                Center(
                  child: Text(
                    _isLogin ? 'Bienvenido de nuevo' : 'Crea tu cuenta',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _isLogin
                        ? 'Encuentra soluciones para tu hogar'
                        : 'Únete a la comunidad de FixRadar',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 40),

                // ── Name (register only) ────────────────────────────────────
                if (!_isLogin) ...[
                  _label('Nombre completo'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: _inputDecoration('Tu nombre', Icons.person_outline),
                    validator: (v) => v!.trim().isEmpty ? 'Ingresa tu nombre' : null,
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Email ───────────────────────────────────────────────────
                _label('Email'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDecoration('tu@email.com', Icons.email_outlined),
                  validator: (v) => !v!.contains('@') ? 'Email inválido' : null,
                ),
                const SizedBox(height: 20),

                // ── Password ────────────────────────────────────────────────
                _label('Contraseña'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: _inputDecoration(
                    '••••••••',
                    Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) => v!.length < 6 ? 'Mínimo 6 caracteres' : null,
                ),

                // ── Register-only fields ─────────────────────────────────────
                if (!_isLogin) ...[
                  const SizedBox(height: 20),
                  _label('Código de referido (Opcional)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _referralController,
                    decoration: _inputDecoration('FIX-XXXX-1234', Icons.card_giftcard),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 24),

                  // ── Send verification code button ──────────────────────────
                  if (!_codeSent) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _isSendingCode ? null : _sendVerificationCode,
                        icon: _isSendingCode
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFFF8A00),
                                ),
                              )
                            : const Icon(Icons.mark_email_unread_outlined,
                                color: Color(0xFFFF8A00)),
                        label: Text(
                          _isSendingCode ? 'Enviando...' : 'Enviar código al correo',
                          style: const TextStyle(color: Color(0xFFFF8A00), fontSize: 15),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFF8A00)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    // ── Verification code input ──────────────────────────────
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Color(0xFFFF8A00), size: 18),
                        const SizedBox(width: 6),
                        const Text(
                          'Código enviado a tu correo',
                          style: TextStyle(color: Color(0xFFFF8A00), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _label('Código de verificación'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: _inputDecoration('123456', Icons.security_outlined),
                      validator: (v) =>
                          (v == null || v.trim().length < 4) ? 'Ingresa el código' : null,
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _resendCountdown > 0 ? null : _sendVerificationCode,
                        child: Text(
                          _resendCountdown > 0
                              ? 'Reenviar en ${_resendCountdown}s'
                              : 'Reenviar código',
                          style: TextStyle(
                            color: _resendCountdown > 0 ? Colors.grey : const Color(0xFFFF8A00),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 32),

                // ── Main action button ──────────────────────────────────────
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8A00),
                    disabledBackgroundColor: const Color(0xFFFFCC99),
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)
                      : Text(
                          _isLogin ? 'Iniciar sesión' : 'Crear cuenta',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),

                const SizedBox(height: 24),
                const Center(
                  child: Text('O continuar con', style: TextStyle(color: Colors.grey)),
                ),
                const SizedBox(height: 24),

                // ── Google button ───────────────────────────────────────────
                OutlinedButton(
                  onPressed: _isLoading ? null : _signInWithGoogle,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.network(
                        'https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg',
                        height: 24,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.g_mobiledata, size: 30, color: Colors.blue),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Continuar con Google',
                        style: TextStyle(color: Colors.black87, fontSize: 16),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Toggle login/register ───────────────────────────────────
                Center(
                  child: TextButton(
                    onPressed: _toggleMode,
                    child: Text(
                      _isLogin
                          ? '¿No tienes cuenta? Regístrate'
                          : '¿Ya tienes cuenta? Inicia sesión',
                      style: const TextStyle(
                        color: Color(0xFFFF8A00),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) =>
      Text(text, style: const TextStyle(fontWeight: FontWeight.bold));

  InputDecoration _inputDecoration(String hint, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.grey),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.grey[50],
      counterText: '',
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF8A00)),
      ),
    );
  }
}
