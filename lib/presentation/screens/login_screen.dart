import 'package:flutter/material.dart';
import '../../core/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/config/routes.dart';
import '../../core/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _referralController = TextEditingController();
  
  bool _isLogin = true;
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await _authService.signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      } else {
        await _authService.signUpWithEmail(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          _nameController.text.trim(),
          referralCode: _referralController.text.trim().isEmpty ? null : _referralController.text.trim(),
        );
      }

      if (mounted) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        final userData = uid != null ? await _firestoreService.getUser(uid) : null;
        if (userData == null || !userData.onboardingCompleted || userData.userType == null) {
          Navigator.pushReplacementNamed(context, AppRoutes.roleSelection);
        } else {
          Navigator.pushReplacementNamed(context, AppRoutes.home);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
                    _isLogin ? 'Encuentra soluciones para tu hogar' : 'Únete a la comunidad de FixRadar',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 48),

                if (!_isLogin) ...[
                  const Text('Nombre completo', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    decoration: _inputDecoration('Tu nombre', Icons.person_outline),
                    validator: (val) => val!.isEmpty ? 'Ingresa tu nombre' : null,
                  ),
                  const SizedBox(height: 20),
                ],

                const Text('Email', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDecoration('tu@email.com', Icons.email_outlined),
                  validator: (val) => !val!.contains('@') ? 'Email inválido' : null,
                ),
                const SizedBox(height: 20),

                const Text('Contraseña', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: _inputDecoration('********', Icons.lock_outline),
                  validator: (val) => val!.length < 6 ? 'Mínimo 6 caracteres' : null,
                ),

                if (!_isLogin) ...[
                  const SizedBox(height: 20),
                  const Text('Código de referido (Opcional)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _referralController,
                    decoration: _inputDecoration('FIX-XXXX-1234', Icons.card_giftcard),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ],
                
                const SizedBox(height: 40),

                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8A00),
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    elevation: 0,
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _isLogin ? 'Iniciar sesión' : 'Registrarse',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                ),
                
                const SizedBox(height: 24),
                
                const Center(child: Text('O continuar con', style: TextStyle(color: Colors.grey))),
                
                const SizedBox(height: 24),

                OutlinedButton(
                  onPressed: _isLoading ? null : _signInWithGoogle,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.network('https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg', height: 24, 
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, size: 30, color: Colors.blue)),
                      const SizedBox(width: 12),
                      const Text('Continuar con Google', style: TextStyle(color: Colors.black87, fontSize: 16)),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(
                      _isLogin ? '¿No tienes cuenta? Regístrate' : '¿Ya tienes cuenta? Inicia sesión',
                      style: const TextStyle(color: Color(0xFFFF8A00), fontWeight: FontWeight.bold),
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

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final userModel = await _authService.signInWithGoogle();
      if (mounted && userModel != null) {
        final userData = await _firestoreService.getUser(userModel.id);
        if (userData == null || !userData.onboardingCompleted || userData.userType == null) {
          Navigator.pushReplacementNamed(context, AppRoutes.roleSelection);
        } else {
          Navigator.pushReplacementNamed(context, AppRoutes.home);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error con Google: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.grey),
      filled: true,
      fillColor: Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
    );
  }
}
