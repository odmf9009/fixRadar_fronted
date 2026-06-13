import 'package:flutter/material.dart';
import '../../core/config/routes.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _pages = [
    OnboardingData(
      title: '¡Bienvenido a FixRadar!',
      description: 'Encuentra expertos para todas las reparaciones de tu hogar. Conectamos tus necesidades con soluciones profesionales cerca de ti.',
      icon: Icons.handyman_rounded,
      color: const Color(0xFFFF8A00),
    ),
    OnboardingData(
      title: 'Solicita Servicios',
      description: 'Publica lo que necesitas, desde plomería hasta electricidad, y recibe cotizaciones instantáneas de técnicos calificados.',
      icon: Icons.add_task_rounded,
      color: const Color(0xFF1976D2),
    ),
    OnboardingData(
      title: 'Elige al Mejor',
      description: 'Compara perfiles, revisa fotos de trabajos anteriores y lee las calificaciones para contratar con total confianza.',
      icon: Icons.verified_user_rounded,
      color: const Color(0xFF4CAF50),
    ),
    OnboardingData(
      title: 'Todo bajo Control',
      description: 'Gestiona tus solicitudes, chatea con los técnicos y califica el servicio recibido para ayudar a la comunidad.',
      icon: Icons.star_rounded,
      color: const Color(0xFFFFD700),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              return _OnboardingPage(data: _pages[index]);
            },
          ),
          
          // Navigation UI
          Positioned(
            bottom: 50,
            left: 24,
            right: 24,
            child: Column(
              children: [
                // Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 8,
                      width: _currentPage == index ? 24 : 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index 
                            ? const Color(0xFFFF8A00) 
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Button
                ElevatedButton(
                  onPressed: () {
                    if (_currentPage < _pages.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      Navigator.pushReplacementNamed(context, AppRoutes.login);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF121212),
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(
                    _currentPage == _pages.length - 1 ? '¡Empezar ahora!' : 'Siguiente',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                
                if (_currentPage < _pages.length - 1)
                  TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
                    child: const Text('Saltar tutorial', style: TextStyle(color: Colors.grey)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final OnboardingData data;
  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (data.title.contains('FixRadar') || data.title.contains('Fix_Radar'))
            Image.asset('assets/logo_centro.png', height: 160)
          else
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: data.color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(data.icon, size: 100, color: data.color),
            ),
          const SizedBox(height: 60),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF121212)),
          ),
          const SizedBox(height: 20),
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[600], height: 1.5),
          ),
        ],
      ),
    );
  }
}

class OnboardingData {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  OnboardingData({required this.title, required this.description, required this.icon, required this.color});
}
