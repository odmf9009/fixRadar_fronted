import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/language_service.dart';
import '../../core/widgets/delete_account_dialog.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _shareLocationHistory = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _shareLocationHistory = prefs.getBool('privacy_share_location') ?? true;
      _isLoading = false;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
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
          tr('privacidad_title'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF8A00)))
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _buildHeader(tr('location_data')),
                _buildSwitchTile(
                  tr('smart_radar'),
                  tr('bg_location_desc'),
                  _shareLocationHistory,
                  (val) {
                    setState(() => _shareLocationHistory = val);
                    _saveSetting('privacy_share_location', val);
                  },
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const Icon(Icons.verified_user_rounded, color: Colors.green, size: 40),
                      const SizedBox(height: 16),
                      Text(
                        tr('privacy_serious_desc'),
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/privacy-policy'),
                        child: Text(
                          tr('read_full_privacy'),
                          style: const TextStyle(color: Color(0xFFFF8A00), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: Text(tr('delete_account'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  subtitle: Text(tr('delete_account_desc')),
                  onTap: () => showDeleteAccountDialog(context),
                ),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFFF8A00),
          fontWeight: FontWeight.bold,
          fontSize: 14,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
      ),
      value: value,
      activeColor: const Color(0xFFFF8A00),
      onChanged: onChanged,
    );
  }
}
