import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/language_service.dart';

class TermsScreen extends StatelessWidget {
  /// Si se provee, la pantalla se muestra en modo "obligatorio de inicio":
  /// sin botón de volver, con un botón de "Aceptar" abajo que dispara este
  /// callback. Si es null, se comporta como la vista normal de Ajustes
  /// (solo lectura, con botón de volver).
  final VoidCallback? onAccept;
  const TermsScreen({super.key, this.onAccept});

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
    final bool mandatory = onAccept != null;
    return PopScope(
      canPop: !mandatory,
      child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: !mandatory,
        leading: mandatory ? null : IconButton(
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
      bottomNavigationBar: mandatory
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8A00),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(tr('accept_terms_btn'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ),
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('terms_title'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              tr('last_updated').replaceAll('{date}', '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}'),
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 20),
            _buildSection(tr('terms_s1_title'), tr('terms_s1_body')),
            _buildSection(tr('terms_s2_title'), tr('terms_s2_body')),
            _buildSection(tr('terms_s3_title'), tr('terms_s3_body')),
            _buildSection(tr('terms_s4_title'), tr('terms_s4_body')),
            _buildSection(tr('terms_s5_title'), tr('terms_s5_body')),
            _buildSection(tr('terms_s6_title'), tr('terms_s6_body')),
            _buildSection(tr('terms_s7_title'), tr('terms_s7_body')),
            _buildSection(tr('terms_s8_title'), tr('terms_s8_body')),
            _buildSection(tr('terms_s9_title'), tr('terms_s9_body')),
            _buildSection(tr('terms_s10_title'), tr('terms_s10_body')),
            _buildSection(tr('terms_s11_title'), tr('terms_s11_body')),
            _buildSection(tr('terms_s12_title'), tr('terms_s12_body')),
            _buildSection(tr('terms_s13_title'), tr('terms_s13_body')),
            _buildSection(tr('terms_s14_title'), tr('terms_s14_body')),
            _buildSection(tr('terms_s15_title'), tr('terms_s15_body')),
            _buildSection(
              tr('terms_s16_title'),
              tr('terms_s16_body'),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('security_clause_title'),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr('security_clause_body'),
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
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
