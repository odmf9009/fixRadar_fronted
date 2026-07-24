import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/language_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/config/routes.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _launchEmail(String email, {String? subject}) async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: subject != null ? {'subject': subject} : null,
    );
    try {
      await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error lanzando email: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          tr('acerca_de'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              decoration: const BoxDecoration(
                color: Color(0xFF121212),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  const Icon(Icons.build_circle_rounded, color: Color(0xFFFF8A00), size: 48),
                  const SizedBox(height: 16),
                  Text(
                    tr('tech_support_network'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Fix_Radar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr('about_tagline'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('what_is_fixradar'),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr('what_is_fixradar_body'),
                    style: const TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
                  ),

                  const SizedBox(height: 32),
                  _buildSectionCard(
                    tr('our_mission'),
                    tr('our_mission_body'),
                    Colors.blue.withOpacity(0.1),
                    Colors.blue,
                  ),

                  const SizedBox(height: 32),
                  Text(
                    tr('how_it_works'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildStep(1, tr('step_1')),
                  _buildStep(2, tr('step_2')),
                  _buildStep(3, tr('step_3')),
                  _buildStep(4, tr('step_4')),

                  const SizedBox(height: 32),
                  Text(
                    tr('community_stats_title'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<Map<String, dynamic>>(
                    stream: firestoreService.getGlobalStats(),
                    builder: (context, snapshot) {
                      final stats = snapshot.data ?? {
                        'totalObjectsPosted': 0,
                        'totalObjectsReused': 0,
                        'totalUsers': 0,
                        'totalCities': 1,
                      };

                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: _buildStatItem('🔧', stats['totalObjectsPosted'].toString(), tr('reports_stat'))),
                              Expanded(child: _buildStatItem('✅', stats['totalObjectsReused'].toString(), tr('repaired_stat'))),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _buildStatItem('👤', stats['totalUsers'].toString(), tr('fixers_stat'))),
                              Expanded(child: _buildStatItem('📍', stats['totalCities'].toString(), tr('zones_stat'))),
                            ],
                          ),
                        ],
                      );
                    }
                  ),

                  const SizedBox(height: 32),
                  Text(
                    tr('why_use_fixradar'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildBulletPoint(tr('bullet_ultra_local')),
                  _buildBulletPoint(tr('bullet_fast_response')),
                  _buildBulletPoint(tr('bullet_qualified_techs')),
                  _buildBulletPoint(tr('bullet_save_time')),
                  _buildBulletPoint(tr('bullet_constant_support')),

                  const SizedBox(height: 40),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          tr('version_label'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(tr('version_number'), style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    tr('links_label'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildLink(
                    context,
                    tr('politica_privacidad'),
                    onTap: () => Navigator.pushNamed(context, AppRoutes.privacyPolicy)
                  ),
                  _buildLink(
                    context,
                    tr('terminos_condiciones'),
                    onTap: () => Navigator.pushNamed(context, AppRoutes.terms)
                  ),
                  _buildLink(
                    context,
                    tr('support_link'),
                    onTap: () => _launchEmail('support@fixradar.tech', subject: tr('email_subject_support'))
                  ),
                  _buildLink(
                    context,
                    tr('report_problem_link'),
                    onTap: () => _launchEmail('support@fixradar.tech', subject: tr('email_subject_problem_report'))
                  ),
                  _buildLink(
                    context,
                    tr('contact_link'),
                    onTap: () => _launchEmail('support@fixradar.tech', subject: tr('email_subject_contact'))
                  ),

                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      children: [
                        Text(
                          tr('made_for_community'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          tr('made_for_community_quote'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.black54,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      tr('turn_fix_mission'),
                      style: const TextStyle(
                        color: Color(0xFFFF8A00),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, String content, Color bgColor, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: accentColor)),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(color: Color(0xFF121212), shape: BoxShape.circle),
            child: Center(
              child: Text(
                number.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildStatItem(String emoji, String value, String label) {
    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Color(0xFFFF8A00), size: 18),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildLink(BuildContext context, String title, {required VoidCallback onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontSize: 14, color: Color(0xFFFF8A00))),
      trailing: const Icon(Icons.chevron_right, size: 18, color: Color(0xFFFF8A00)),
      onTap: onTap,
    );
  }
}
