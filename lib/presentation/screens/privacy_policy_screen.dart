import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/language_service.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  Future<void> _launchEmail(String email) async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: email,
    );
    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
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
        title: const Text(
          'Política de Privacidad',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'POLÍTICA DE PRIVACIDAD DE FIX_RADAR',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Última actualización: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 20),
            const Text(
              'Bienvenido a Fix_Radar. Su privacidad es fundamental para la confianza de nuestra red de servicios técnicos. Esta Política de Privacidad explica cómo recopilamos, utilizamos y protegemos su información cuando utiliza nuestra aplicación para reportar averías o prestar servicios.\n\nAl utilizar Fix_Radar, usted acepta las prácticas descritas en esta Política de Privacidad.',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 24),
            
            _buildSection('1. INFORMACIÓN QUE RECOPILAMOS', 
              'Información proporcionada por el usuario\n• Nombre y apellidos\n• Dirección de correo electrónico\n• Foto de perfil y de trabajos realizados\n• Especialidades técnicas (para técnicos)\n• Descripción de averías y fotos del problema\n• Mensajes de chat entre cliente y técnico\n\nInformación de ubicación\nPara conectar averías con técnicos cercanos, recopilamos:\n• Ubicación actual del dispositivo (en primer y segundo plano si se activa el radar técnico)\n• Dirección aproximada del reporte de avería\n\nLa ubicación es crítica para que el sistema de alertas notifique a los técnicos adecuados según su proximidad.'),

            _buildSection('2. CÓMO UTILIZAMOS LA INFORMACIÓN',
              'Utilizamos la información para:\n• Conectar clientes con técnicos locales.\n• Notificar a los técnicos sobre nuevas averías en su área.\n• Permitir la comunicación directa para coordinar reparaciones.\n• Mostrar la reputación y valoraciones de los usuarios.\n• Mejorar la seguridad de la red técnica.'),

            _buildSection('3. INFORMACIÓN COMPARTIDA CON OTROS USUARIOS',
              'Para facilitar el servicio, compartimos:\n• Fotos y detalles de la avería.\n• Nombre de usuario y calificación.\n• Ubicación de la avería (visible para técnicos registrados).\n\nNo compartimos su número de teléfono ni dirección exacta hasta que usted decida hacerlo a través del chat privado para coordinar la visita.'),

            _buildSection('4. ANALÍTICAS Y MEJORA DEL SERVICIO',
              'Fix_Radar utiliza herramientas para:\n• Analizar qué tipos de averías son más comunes.\n• Optimizar el radio de búsqueda de técnicos.\n• Detectar errores técnicos en la aplicación.'),

            _buildSection('5. SEGURIDAD DE LOS DATOS',
              'Implementamos cifrado y medidas de seguridad de Firebase para proteger sus mensajes y datos personales.\nSin embargo, el usuario es responsable de la información sensible compartida voluntariamente a través del chat.'),

            _buildSection('6. RETENCIÓN Y ELIMINACIÓN',
              'Conservamos el historial de trabajos para fines de reputación y garantía.\nUsted puede solicitar la eliminación de su cuenta en cualquier momento desde los ajustes.'),

            _buildSection('7. MENORES DE EDAD',
              'Fix_Radar está dirigida exclusivamente a adultos con capacidad legal para contratar servicios técnicos o realizarlos.'),

            _buildSection('8. DERECHOS DEL USUARIO',
              'Usted tiene derecho a acceder, rectificar o eliminar sus datos personales enviando una solicitud a nuestro soporte técnico.'),

            _buildSection('9. CONTACTO',
              'Si tiene dudas sobre su privacidad:\nCorreo electrónico: support@fixradar.tech',
              onTap: () => _launchEmail('support@fixradar.tech')),

            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RESUMEN DE PRIVACIDAD FIX_RADAR',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryItem('✅ Ubicación: Usada solo para emparejar averías con técnicos.'),
                  _buildSummaryItem('✅ Datos: No vendemos tu información a anunciantes.'),
                  _buildSummaryItem('✅ Chat: Los mensajes están protegidos para tu seguridad.'),
                  _buildSummaryItem('✅ Transparencia: Tú controlas cuándo compartes tu dirección exacta.'),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            const Center(
              child: Text(
                'Fix_Radar: Conectando habilidades técnicas con necesidades del hogar de forma segura y privada. 🛠️🏡🛡️',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(content, style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
    );
  }
}
