import 'package:flutter/material.dart';
import '../../core/services/language_service.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('go_premium'))),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.workspace_premium, size: 80, color: Colors.orange),
            const SizedBox(height: 24),
            Text(tr('unlock_advanced_features'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            ElevatedButton(onPressed: () {}, child: Text(tr('subscribe_now'))),
          ],
        ),
      ),
    );
  }
}
