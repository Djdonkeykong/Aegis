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

class OpenFdaMedicationReference {
  final String displayName;
  final List<String> genericNames;
  final List<String> brandNames;
  final List<String> manufacturers;
  final List<String> dosageForms;
  final List<String> routes;
  final String? productType;

  const OpenFdaMedicationReference({
    required this.displayName,
    this.genericNames = const [],
    this.brandNames = const [],
    this.manufacturers = const [],
    this.dosageForms = const [],
    this.routes = const [],
    this.productType,
  });

  bool get hasContent =>
      genericNames.isNotEmpty ||
      brandNames.isNotEmpty ||
      manufacturers.isNotEmpty ||
      dosageForms.isNotEmpty ||
      routes.isNotEmpty ||
      (productType?.isNotEmpty ?? false);
}

class OpenFdaService {
  final http.Client _client;
  final Duration timeout;
  final Map<String, OpenFdaInteractionContext> _cache = {};
  final Map<String, OpenFdaMedicationReference?> _medicationReferenceCache = {};

  OpenFdaService({
    http.Client? client,
    this.timeout = const Duration(seconds: 4),
  }) : _client = client ?? http.Client();

  Future<OpenFdaMedicationReference?> fetchMedicationReference(
    String drugName,
  ) async {
    final query = drugName.trim().toLowerCase();
    if (query.isEmpty) return null;
    if (_medicationReferenceCache.containsKey(query)) {
      return _medicationReferenceCache[query];
    }

    final genericMatch = await _fetchMedicationReferenceByField(
      field: 'openfda.generic_name',
      drugName: drugName,
    );
    if (genericMatch != null) {
      return _medicationReferenceCache[query] = genericMatch;
    }

    final brandMatch = await _fetchMedicationReferenceByField(
      field: 'openfda.brand_name',
      drugName: drugName,
    );
    return _medicationReferenceCache[query] = brandMatch;
  }

  Future<OpenFdaMedicationReference?> _fetchMedicationReferenceByField({
    required String field,
    required String drugName,
  }) async {
    try {
      final response = await _client
          .get(
            Uri.https('api.fda.gov', '/drug/label.json', {
              'search': '$field:"${drugName.trim()}"',
              'limit': '1',
            }),
          )
          .timeout(timeout);

      if (response.statusCode != 200) {
        return null;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final results = body['results'] as List<dynamic>? ?? [];
      if (results.isEmpty) return null;

      final item = results.first as Map<String, dynamic>;
      final openFda = item['openfda'] as Map<String, dynamic>? ?? const {};
      final genericNames = _toStringList(openFda['generic_name']);
      final brandNames = _toStringList(openFda['brand_name']);
      final manufacturers = _toStringList(openFda['manufacturer_name']);
      final dosageForms = _toStringList(openFda['dosage_form']);
      final routes = _toStringList(openFda['route']);
      final displayName = genericNames.isNotEmpty
          ? genericNames.first
          : brandNames.isNotEmpty
              ? brandNames.first
              : drugName.trim();

      return OpenFdaMedicationReference(
        displayName: displayName,
        genericNames: genericNames,
        brandNames: brandNames,
        manufacturers: manufacturers,
        dosageForms: dosageForms,
        routes: routes,
        productType: item['product_type']?.toString().trim(),
      );
    } catch (_) {
      return null;
    }
  }

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
