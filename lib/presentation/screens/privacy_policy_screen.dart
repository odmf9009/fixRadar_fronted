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
        title: Text(
          tr('politica_privacidad'),
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
              tr('privacy_title'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              tr('last_updated').replaceAll('{date}', '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}'),
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Text(
              tr('privacy_intro'),
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 24),

            _buildSection(tr('privacy_s1_title'), tr('privacy_s1_body')),
            _buildSection(tr('privacy_s2_title'), tr('privacy_s2_body')),
            _buildSection(tr('privacy_s3_title'), tr('privacy_s3_body')),
            _buildSection(tr('privacy_s4_title'), tr('privacy_s4_body')),
            _buildSection(tr('privacy_s5_title'), tr('privacy_s5_body')),
            _buildSection(tr('privacy_s6_title'), tr('privacy_s6_body')),
            _buildSection(tr('privacy_s7_title'), tr('privacy_s7_body')),
            _buildSection(tr('privacy_s8_title'), tr('privacy_s8_body')),
            _buildSection(
              tr('privacy_s9_title'),
              tr('privacy_s9_body'),
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
                  Text(
                    tr('privacy_summary_title'),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryItem(tr('privacy_summary_1')),
                  _buildSummaryItem(tr('privacy_summary_2')),
                  _buildSummaryItem(tr('privacy_summary_3')),
                  _buildSummaryItem(tr('privacy_summary_4')),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            Center(
              child: Text(
                tr('privacy_footer'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.grey, fontStyle: FontStyle.italic),
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
