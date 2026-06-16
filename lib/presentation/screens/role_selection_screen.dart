import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/config/routes.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkExistingRole();
  }

  Future<void> _checkExistingRole() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      final userData = await _firestoreService.getUser(firebaseUser.uid);
      if (userData != null && userData.onboardingCompleted && userData.userType != null) {
        if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    } else {
      final token = await _authService.getBackendToken();
      if (token != null) {
        final userData = await _authService.syncCurrentUserFromBackend();
        if (userData != null && userData.onboardingCompleted && userData.userType != null) {
          if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.home);
        }
      }
    }
  }

  Future<void> _selectRole(String role) async {
    setState(() => _isLoading = true);
    try {
      // PUT /users/me uses the token identity — uid param is ignored by the backend
      await _firestoreService.updateUserRole('', role);
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Image.asset('assets/logo_centro.png', height: 120),
              const SizedBox(height: 30),
              const Text(
                '¡Bienvenido a FixRadar!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                '¿Cómo planeas usar la aplicación?',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 60),
              
              _roleCard(
                title: 'Soy Cliente',
                description: 'Busco ayuda experta para reparaciones y mantenimiento en mi hogar.',
                icon: Icons.home_repair_service_outlined,
                color: const Color(0xFF1976D2),
                onTap: () => _selectRole('client'),
              ),
              
              const SizedBox(height: 24),
              
              _roleCard(
                title: 'Soy Técnico',
                description: 'Ofrezco mis servicios profesionales y busco nuevos trabajos.',
                icon: Icons.engineering_outlined,
                color: const Color(0xFFFF8A00),
                onTap: () => _selectRole('technician'),
              ),
              
              const Spacer(),
              if (_isLoading)
                const CircularProgressIndicator(color: Color(0xFFFF8A00)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(description, style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
