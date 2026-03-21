import 'dart:convert';
import 'package:http/http.dart' as http;

class RxNavService {
  final http.Client _client;
  final Duration timeout;
  final Map<String, String?> _normalizedNameCache = {};

  RxNavService({
    http.Client? client,
    this.timeout = const Duration(seconds: 4),
  }) : _client = client ?? http.Client();

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
