import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../config/service_constants.dart';

class AIService {
  // Llave FixRadar (Proyecto: fixradar-77067)
  static const String _apiKey = 'AIzaSyALY9r9RAlgQbyr7aOk8YNFBPwGZ4KhaqI';

  final GenerativeModel _model;

  AIService()
      : _model = GenerativeModel(
          model: 'gemini-2.5-flash',
          apiKey: _apiKey,
        );

  Future<Map<String, String>?> analyzeObjectImage(File imageFile) async {
    try {
      print('AIService: Enviando imagen a Gemini...');
      final imageBytes = await imageFile.readAsBytes();
      
      final prompt = TextPart(
        'Analiza esta imagen de un problema o avería en el hogar (plomería, electricidad, aire acondicionado, etc.). '
        'Genera: 1. Un título corto. 2. Una categoría de esta lista: [${ServiceConstants.categoryNames.join(', ')}]. 3. Una descripción de máximo 20 palabras detallando el problema técnico. '
        'Responde ÚNICAMENTE en formato JSON plano: {"title": "...", "category": "...", "description": "..."}'
      );

      final content = [
        Content.multi([
          prompt,
          DataPart('image/jpeg', imageBytes),
        ])
      ];

      final response = await _model.generateContent(content);
      final text = response.text;

      if (text != null) {
        print('Gemini Response: $text');
        final jsonMatch = RegExp(r'\{.*\}', dotAll: true).stringMatch(text);
        if (jsonMatch != null) {
          final Map<String, dynamic> data = jsonDecode(jsonMatch);
          return {
            'title': data['title']?.toString() ?? '',
            'category': data['category']?.toString() ?? 'Otros',
            'description': data['description']?.toString() ?? '',
          };
        }
      }
    } catch (e) {
      print('--- ERROR GEMINI ---');
      print(e);
    }
    return null;
  }
}
