import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../../core/constants/app_constants.dart';

abstract class AiService {
  Future<String> summarize(String prompt);
}

class OllamaAiService implements AiService {
  final String endpoint;
  final String model;
  final Duration timeout;

  OllamaAiService({
    this.endpoint = AppConstants.ollamaEndpoint,
    this.model = AppConstants.ollamaModel,
    this.timeout = const Duration(seconds: 8),
  });

  @override
  Future<String> summarize(String prompt) async {
    try {
      final payload = jsonEncode({
        'model': model,
        'prompt': prompt,
        'stream': false,
        'options': {'temperature': 0.3, 'num_predict': 200},
      });

      final res = await http.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: payload,
      ).timeout(timeout);

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        return (json['response'] as String? ?? 'No summary generated.').trim();
      } else {
        return 'AI summarizer returned error (${res.statusCode}).';
      }
    } catch (e) {
      return 'Could not reach AI service: $e';
    }
  }
}
