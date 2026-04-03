import 'dart:convert';
import 'package:http/http.dart' as http;

class RxNavService {
  final http.Client _client;
  final Duration timeout;
  final Map<String, String?> _normalizedNameCache = {};
  final Map<String, List<RxNavDrugCandidate>> _candidateCache = {};

  RxNavService({
    http.Client? client,
    this.timeout = const Duration(seconds: 4),
  }) : _client = client ?? http.Client();

  Future<List<RxNavDrugCandidate>> fetchDrugCandidates(
    String input, {
    int limit = 12,
  }) async {
    final query = input.trim().toLowerCase();
    if (query.isEmpty) return const [];
    if (_candidateCache.containsKey(query)) {
      return _candidateCache[query]!;
    }

    try {
      final response = await _client
          .get(
            Uri.https(
              'rxnav.nlm.nih.gov',
              '/REST/drugs.json',
              {'name': input.trim(), 'expand': 'psn'},
            ),
          )
          .timeout(timeout);

      if (response.statusCode != 200) {
        return _candidateCache[query] = const [];
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final drugGroup = body['drugGroup'] as Map<String, dynamic>?;
      final conceptGroups = drugGroup?['conceptGroup'] as List<dynamic>? ?? [];
      final candidates = <RxNavDrugCandidate>[];
      final seen = <String>{};

      for (final group in conceptGroups) {
        final groupMap = group as Map<String, dynamic>;
        final tty = groupMap['tty']?.toString();
        final properties =
            groupMap['conceptProperties'] as List<dynamic>? ?? const [];

        for (final property in properties) {
          final item = property as Map<String, dynamic>;
          final name = item['name']?.toString().trim() ?? '';
          final synonym = item['synonym']?.toString().trim();
          final psn = item['psn']?.toString().trim();
          final normalizedKey =
              '${name.toLowerCase()}|${(synonym ?? '').toLowerCase()}|${(psn ?? '').toLowerCase()}';

          if (name.isEmpty || !seen.add(normalizedKey)) {
            continue;
          }

          candidates.add(
            RxNavDrugCandidate(
              name: name,
              synonym: synonym != null && synonym.isNotEmpty ? synonym : null,
              prescribableName: psn != null && psn.isNotEmpty ? psn : null,
              tty: tty,
            ),
          );

          if (candidates.length >= limit) {
            return _candidateCache[query] = candidates;
          }
        }
      }

      return _candidateCache[query] = candidates;
    } catch (_) {
      return _candidateCache[query] = const [];
    }
  }

  Future<String?> normalizeDrugName(String input) async {
    final query = input.trim().toLowerCase();
    if (query.isEmpty) return null;
    if (_normalizedNameCache.containsKey(query)) {
      return _normalizedNameCache[query];
    }

    try {
      final rxcuiResponse = await _client
          .get(
            Uri.https(
              'rxnav.nlm.nih.gov',
              '/REST/Prescribe/rxcui.json',
              {'name': input.trim(), 'search': '2'},
            ),
          )
          .timeout(timeout);

      if (rxcuiResponse.statusCode != 200) {
        return _normalizedNameCache[query] = null;
      }

      final rxcuiJson = jsonDecode(rxcuiResponse.body) as Map<String, dynamic>;
      final idGroup = rxcuiJson['idGroup'] as Map<String, dynamic>?;
      final rxnormIds = (idGroup?['rxnormId'] as List<dynamic>? ?? [])
          .map((id) => id.toString())
          .where((id) => id.isNotEmpty)
          .toList();

      if (rxnormIds.isEmpty) {
        return _normalizedNameCache[query] = null;
      }

      final propertyResponse = await _client
          .get(
            Uri.https(
              'rxnav.nlm.nih.gov',
              '/REST/rxcui/${rxnormIds.first}/property.json',
              {'propName': 'RxNorm Name'},
            ),
          )
          .timeout(timeout);

      if (propertyResponse.statusCode != 200) {
        return _normalizedNameCache[query] = null;
      }

      final propertyJson =
          jsonDecode(propertyResponse.body) as Map<String, dynamic>;
      final propConceptGroup =
          propertyJson['propConceptGroup'] as Map<String, dynamic>?;
      final propConcepts =
          (propConceptGroup?['propConcept'] as List<dynamic>? ?? []);
      final normalizedNames = propConcepts
          .map((item) => item as Map<String, dynamic>)
          .map((item) => item['propValue']?.toString().trim())
          .where((value) => value != null && value.isNotEmpty)
          .cast<String>()
          .toList();

      final normalizedName =
          normalizedNames.isNotEmpty ? normalizedNames.first : null;
      return _normalizedNameCache[query] = normalizedName;
    } catch (_) {
      return _normalizedNameCache[query] = null;
    }
  }
}

class RxNavDrugCandidate {
  final String name;
  final String? synonym;
  final String? prescribableName;
  final String? tty;

  const RxNavDrugCandidate({
    required this.name,
    this.synonym,
    this.prescribableName,
    this.tty,
  });

  List<String> get candidateNames => [
        name,
        if (synonym != null) synonym!,
        if (prescribableName != null) prescribableName!,
      ];
}
