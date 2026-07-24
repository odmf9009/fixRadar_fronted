import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/language_service.dart';
import '../../core/config/routes.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          tr('ayuda_soporte'),
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
            Center(
              child: Column(
                children: [
                  Text(
                    tr('help_title'),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr('help_subtitle'),
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Quick Action Buttons Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: [
                _buildQuickActionButton(Icons.help_outline, tr('faq_label'), Colors.blue, () {}),
                _buildQuickActionButton(Icons.support_agent, tr('contact_label'), Colors.green, () => _launchEmail('support@fixradar.tech', subject: tr('email_subject_support'))),
                _buildQuickActionButton(Icons.bug_report_outlined, tr('report_error_label'), Colors.red, () => _launchEmail('support@fixradar.tech', subject: tr('email_subject_error'))),
                _buildQuickActionButton(Icons.lightbulb_outline, tr('suggestion_label'), Colors.orange, () => _launchEmail('support@fixradar.tech', subject: tr('email_subject_suggestion'))),
              ],
            ),

            const SizedBox(height: 40),
            Text(
              tr('faq_title'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildFAQTile(
              tr('faq_q1'),
              tr('faq_a1'),
            ),
            _buildFAQTile(
              tr('faq_q2'),
              tr('faq_a2'),
            ),
            _buildFAQTile(
              tr('faq_q3'),
              tr('faq_a3'),
            ),
            _buildFAQTile(
              tr('faq_q4'),
              tr('faq_a4'),
            ),
            _buildFAQTile(
              tr('faq_q5'),
              tr('faq_a5'),
            ),

            const SizedBox(height: 40),
            _buildInfoCard(
              tr('contact_card_title'),
              tr('need_assistance'),
              'support@fixradar.tech',
              tr('response_time_est'),
              const Color(0xFFE8F5E9),
              Colors.green[700]!,
              onTap: () => _launchEmail('support@fixradar.tech', subject: tr('email_subject_support')),
            ),

            const SizedBox(height: 20),
            _buildInfoCard(
              tr('report_error_card_title'),
              tr('if_you_find_bug'),
              'support@fixradar.tech',
              tr('include_screenshots'),
              const Color(0xFFFFEBEE),
              Colors.red[700]!,
              onTap: () => _launchEmail('support@fixradar.tech', subject: tr('email_subject_error')),
            ),

            const SizedBox(height: 20),
            _buildInfoCard(
              tr('suggest_feature_title'),
              tr('how_improve_fixradar'),
              'support@fixradar.tech',
              tr('ideas_help_grow'),
              const Color(0xFFFFF3E0),
              Colors.orange[700]!,
              onTap: () => _launchEmail('support@fixradar.tech', subject: tr('email_subject_suggestion')),
            ),

            const SizedBox(height: 40),
            Text(
              tr('legal_info'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _buildLinkTile(context, tr('politica_privacidad'), AppRoutes.privacyPolicy),
            _buildLinkTile(context, tr('terminos_condiciones'), AppRoutes.terms),
            _buildLinkTile(context, tr('licencias_terceros'), AppRoutes.licenses),

            const SizedBox(height: 60),
            Center(
              child: Column(
                children: [
                  Text(
                    tr('thanks_using'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      tr('connecting_skills'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFAQTile(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(
            answer,
            style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String beforeEmail, String email, String afterEmail, Color bgColor, Color accentColor, {required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accentColor.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: accentColor),
              ),
              const SizedBox(height: 12),
              Text(
                beforeEmail,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 4),
              Text(
                email,
                style: TextStyle(
                  fontSize: 15, 
                  fontWeight: FontWeight.bold, 
                  color: accentColor,
                  decoration: TextDecoration.underline,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                afterEmail,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkTile(BuildContext context, String title, String? route) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontSize: 14, color: Color(0xFFFF8A00))),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: route != null ? () => Navigator.pushNamed(context, route) : null,
    );
  }
}
