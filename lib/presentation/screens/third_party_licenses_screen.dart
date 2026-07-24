import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/language_service.dart';

class ThirdPartyLicensesScreen extends StatelessWidget {
  const ThirdPartyLicensesScreen({super.key});

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
          tr('licencias_terceros'),
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
            Text(
              tr('licenses_title'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              tr('last_updated').replaceAll('{date}', '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}'),
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Text(
              tr('licenses_intro'),
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 24),

            _buildLicenseSection('Google Maps Platform', tr('lic_maps_body')),

            _buildLicenseSection('Firebase', tr('lic_firebase_body')),

            _buildLicenseSection('Google Sign-In', tr('lic_google_signin_body')),

            _buildLicenseSection('Apple Sign-In', tr('lic_apple_signin_body')),

            _buildLicenseSection('Flutter Framework', tr('lic_flutter_body')),

            _buildLicenseSection(tr('lic_dart_label'), tr('lic_dart_body')),

            _buildLicenseSection(tr('lic_oss_title'), tr('lic_oss_body')),

            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    tr('oss_libraries_title'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr('oss_libraries_desc'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => showLicensePage(
                      context: context,
                      applicationName: 'Fix_Radar',
                      applicationVersion: '1.0.0',
                      applicationIcon: const Icon(Icons.build_circle_rounded, color: Color(0xFFFF8A00), size: 48),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF121212),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(tr('view_all_licenses')),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            Text(tr('credits_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(tr('credits_body'), style: const TextStyle(fontSize: 14, color: Colors.black87)),

            const SizedBox(height: 24),
            Text(tr('contact_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _launchEmail('support@fixradar.tech'),
              child: Text(tr('license_contact_body'), style: const TextStyle(fontSize: 14, color: Colors.black87)),
            ),

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildLicenseSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87)),
        ],
      ),
    );
  }
}
