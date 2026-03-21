import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenFdaInteractionContext {
  final List<String> evidence;
  final List<String> warnings;
  final List<String> symptoms;
  final List<String> guidance;

  const OpenFdaInteractionContext({
    this.evidence = const [],
    this.warnings = const [],
    this.symptoms = const [],
    this.guidance = const [],
  });

  bool get hasContent =>
      evidence.isNotEmpty ||
      warnings.isNotEmpty ||
      symptoms.isNotEmpty ||
      guidance.isNotEmpty;
}

class OpenFdaService {
  final http.Client _client;
  final Duration timeout;
  final Map<String, OpenFdaInteractionContext> _cache = {};

  OpenFdaService({
    http.Client? client,
    this.timeout = const Duration(seconds: 4),
  }) : _client = client ?? http.Client();

  Future<OpenFdaInteractionContext> fetchInteractionContext(
    String drug1,
    String drug2,
  ) async {
    final key = '${drug1.toLowerCase()}|${drug2.toLowerCase()}';
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    try {
      final response = await _client
          .get(
            Uri.https('api.fda.gov', '/drug/label.json', {
              'search': 'openfda.generic_name:"$drug1"',
              'limit': '3',
            }),
          )
          .timeout(timeout);

      if (response.statusCode != 200) {
        return _cache[key] = const OpenFdaInteractionContext();
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final results = body['results'] as List<dynamic>? ?? [];
      final loweredDrug2 = drug2.toLowerCase();

      final evidence = <String>{};
      final warnings = <String>{};
      final symptoms = <String>{};
      final guidance = <String>{};

      for (final result in results) {
        final item = result as Map<String, dynamic>;
        final sections = <String>[
          ..._toStringList(item['drug_interactions']),
          ..._toStringList(item['warnings']),
          ..._toStringList(item['precautions']),
          ..._toStringList(item['information_for_patients']),
        ];

        for (final section in sections) {
          for (final sentence in _splitSentences(section)) {
            final cleaned = _cleanSentence(sentence);
            if (cleaned.isEmpty) continue;
            final lower = cleaned.toLowerCase();

            if (lower.contains(loweredDrug2)) {
              evidence.add(cleaned);
            }
            if (_looksLikeWarning(cleaned)) {
              warnings.add(cleaned);
            }
            if (_looksLikeSymptom(cleaned)) {
              symptoms.add(cleaned);
            }
            if (_looksLikeGuidance(cleaned)) {
              guidance.add(cleaned);
            }
          }
        }
      }

      final context = OpenFdaInteractionContext(
        evidence: evidence.take(3).toList(),
        warnings: warnings.take(3).toList(),
        symptoms: symptoms.take(5).toList(),
        guidance: guidance.take(4).toList(),
      );
      _cache[key] = context;
      return context;
    } catch (_) {
      return _cache[key] = const OpenFdaInteractionContext();
    }
  }

  List<String> _toStringList(dynamic value) {
    return (value as List<dynamic>? ?? [])
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  List<String> _splitSentences(String text) {
    return text.split(RegExp(r'(?<=[.!?])\s+'));
  }

  String _cleanSentence(String sentence) {
    return sentence.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  bool _looksLikeWarning(String sentence) {
    final lower = sentence.toLowerCase();
    return lower.contains('warning') ||
        lower.contains('bleed') ||
        lower.contains('serious') ||
        lower.contains('bruis') ||
        lower.contains('blood in your urine') ||
        lower.contains('blood in your stools');
  }

  bool _looksLikeSymptom(String sentence) {
    final lower = sentence.toLowerCase();
    return lower.contains('call your doctor') ||
        lower.contains('seek medical') ||
        lower.contains('unusual bleeding') ||
        lower.contains('bruising') ||
        lower.contains('vomiting') ||
        lower.contains('headache') ||
        lower.contains('dizziness') ||
        lower.contains('weakness');
  }

  bool _looksLikeGuidance(String sentence) {
    final lower = sentence.toLowerCase();
    return lower.contains('tell your doctor') ||
        lower.contains('do not stop') ||
        lower.contains('monitor') ||
        lower.contains('dose adjustment') ||
        lower.contains('inr') ||
        lower.contains('consult');
  }
}
