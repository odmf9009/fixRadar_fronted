import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/language_service.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

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
        title: Text(
          tr('terminos_condiciones'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
              'TÉRMINOS Y CONDICIONES DE FIX_RADAR',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Última actualización: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 20),
            _buildSection(
              '1. DESCRIPCIÓN DEL SERVICIO',
              'Fix_Radar es una plataforma colaborativa que permite a los usuarios reportar averías técnicas o necesidades de mantenimiento en el hogar para que otros usuarios con habilidades técnicas puedan ofrecer asistencia o ser contratados.\n\nFix_Radar actúa únicamente como una plataforma de conexión e información y no es responsable directo de las reparaciones, contratos o transacciones realizadas entre usuarios.',
            ),
            _buildSection(
              '2. RELACIÓN ENTRE USUARIOS',
              'Fix_Radar no emplea a los técnicos que aparecen en la plataforma.\n\nTodos los perfiles, habilidades, valoraciones y presupuestos son gestionados directamente por los usuarios.\n\nFix_Radar no garantiza el resultado final de una reparación, ni la calidad o seguridad de los servicios prestados por terceros.',
            ),
            _buildSection(
              '3. VERIFICACIÓN DE IDENTIDAD',
              'Aunque Fix_Radar fomenta una comunidad segura, es responsabilidad del usuario verificar la identidad y credenciales del técnico o cliente antes de permitir el acceso a su hogar.\n\nFix_Radar no se hace responsable de incidentes derivados del acceso de personas desconocidas a propiedades privadas.',
            ),
            _buildSection(
              '4. RESPONSABILIDAD DEL USUARIO',
              'El usuario es el único responsable de:\n\n• Describir con precisión la avería.\n• Acordar términos de pago y ejecución del servicio.\n• Cumplir con las normativas de seguridad locales.\n\nToda acción realizada por el usuario fuera de la aplicación será bajo su exclusiva responsabilidad.',
            ),
            _buildSection(
              '5. PROPIEDAD PRIVADA Y ACCESO',
              'Los técnicos solo deben acceder a hogares o propiedades privadas bajo invitación y permiso explícito del cliente.\n\nFix_Radar no autoriza ni promueve el acceso no solicitado a viviendas o espacios restringidos.',
            ),
            _buildSection(
              '6. SEGURIDAD Y RIESGOS',
              'Los usuarios reconocen que los trabajos de reparación (electricidad, plomería, etc.) implican riesgos inherentes.\n\nFix_Radar no será responsable por:\n\n• Accidentes laborales.\n• Daños colaterales a la propiedad.\n• Incumplimiento de servicios.\n• Pérdidas económicas por reparaciones fallidas.\n\nEl usuario asume todos los riesgos asociados con la contratación o prestación de servicios a través de la app.',
            ),
            _buildSection(
              '7. CONTENIDO GENERADO POR LOS USUARIOS',
              'Cada usuario es responsable de todo el contenido que publique dentro de la aplicación, incluyendo fotografías de averías, descripciones técnicas y valoraciones de servicios.\n\nFix_Radar podrá moderar contenido que se considere inapropiado o falso.',
            ),
            _buildSection(
              '8. CONDUCTA PROHIBIDA',
              'Está prohibido utilizar Fix_Radar para:\n\n• Publicar servicios ilegales.\n• Ofrecer reparaciones peligrosas sin certificación si fuera requerida.\n• Acosar a clientes o técnicos.\n• Suplantar identidades profesionales.\n• Distribuir spam o publicidad no relacionada con reparaciones.\n\nFix_Radar podrá suspender cuentas que vulneren la confianza de la comunidad.',
            ),
            _buildSection(
              '9. GEOLOCALIZACIÓN',
              'La aplicación utiliza servicios de ubicación para mostrar averías cercanas y optimizar el tiempo de respuesta de los técnicos.\n\nAl utilizar Fix_Radar, el usuario acepta compartir su ubicación aproximada para fines operativos.',
            ),
            _buildSection(
              '10. LIMITACIÓN DE RESPONSABILIDAD',
              'Fix_Radar se proporciona "tal cual".\n\nEn la máxima medida permitida por la ley, Fix_Radar y sus desarrolladores no serán responsables por daños personales, materiales o económicos derivados de los servicios técnicos gestionados a través de la plataforma.',
            ),
            _buildSection(
              '11. PROPIEDAD INTELECTUAL',
              'Todos los derechos relacionados con el nombre Fix_Radar, logotipos y software pertenecen a sus desarrolladores y están protegidos por leyes de propiedad intelectual.',
            ),
            _buildSection(
              '12. TERMINACIÓN DE CUENTAS',
              'Fix_Radar podrá suspender cuentas con bajas valoraciones recurrentes o reportes de mala conducta para proteger la integridad de la red de técnicos.',
            ),
            _buildSection(
              '13. MODIFICACIONES DEL SERVICIO',
              'Fix_Radar podrá añadir o eliminar categorías de servicios técnicos en cualquier momento.',
            ),
            _buildSection(
              '14. CAMBIOS A LOS TÉRMINOS',
              'El uso continuado de Fix_Radar implica la aceptación de los Términos y Condiciones actualizados.',
            ),
            _buildSection(
              '15. LEY APLICABLE',
              'Estos Términos y Condiciones se rigen por las leyes de jurisdicción local del usuario.',
            ),
            _buildSection(
              '16. CONTACTO',
              'Email: support@fixradar.tech',
              onTap: () => _launchEmail('support@fixradar.tech'),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CLÁUSULA DE SEGURIDAD FIX_RADAR',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Fix_Radar es una herramienta de conexión. Toda reparación y acceso al hogar es responsabilidad exclusiva de los usuarios involucrados. Se recomienda encarecidamente solicitar referencias y certificaciones para trabajos complejos.',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
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
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}
