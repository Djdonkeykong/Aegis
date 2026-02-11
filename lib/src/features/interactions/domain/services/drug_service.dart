import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import '../../../../../core/constants/app_constants.dart';
import '../models/interaction_result.dart';
import 'ai_service.dart';

class DrugService {
  final AiService _aiService;

  DrugService({required AiService aiService}) : _aiService = aiService;

  // Cached interaction rows
  List<List<dynamic>>? _cachedInteractions;
  bool _dataLoadFailed = false;
  String _loadErrorMsg = '';

  // All drug names for autocomplete
  final Set<String> allDrugNames = {};

  // Synonym mapping
  final Map<String, String> drugSynonyms = {
    'paracetamol': 'Acetaminophen',
  };

  bool get isLoaded => _cachedInteractions != null;
  bool get loadFailed => _dataLoadFailed;
  String get loadError => _loadErrorMsg;

  // ------------------------------------------------------------------
  // CSV Loading
  // ------------------------------------------------------------------
  Future<void> loadData() async {
    if (_cachedInteractions != null || _dataLoadFailed) return;

    final List<List<dynamic>> allRows = [];

    try {
      // DDInter CSVs
      for (final asset in AppConstants.ddinterCsvAssets) {
        final csvString = await rootBundle.loadString(asset);
        final csvData =
            const CsvToListConverter().convert(csvString, eol: '\n');
        if (csvData.isNotEmpty) {
          allRows.addAll(csvData.skip(1));
          for (final row in csvData.skip(1)) {
            if (row.length >= 4) {
              allDrugNames.add(row[1].toString().trim());
              allDrugNames.add(row[3].toString().trim());
            }
          }
        }
      }

      // Kaggle CSV
      final kaggleString =
          await rootBundle.loadString(AppConstants.kaggleCsvAsset);
      final kaggleData =
          const CsvToListConverter().convert(kaggleString, eol: '\n');
      if (kaggleData.isNotEmpty) {
        for (var i = 1; i < kaggleData.length; i++) {
          final row = kaggleData[i];
          if (row.length >= 3) {
            final drugA = row[0].toString().trim();
            final drugB = row[1].toString().trim();
            final level = row[2].toString().trim();
            allRows.add(['Kaggle', drugA, 'Kaggle', drugB, level]);
            allDrugNames.add(drugA);
            allDrugNames.add(drugB);
          }
        }
      }

      if (allRows.isEmpty) {
        _dataLoadFailed = true;
        _loadErrorMsg = 'Could not load any CSV data.';
      } else {
        _cachedInteractions = allRows;
      }
    } catch (e) {
      _dataLoadFailed = true;
      _loadErrorMsg = 'Error loading CSVs: $e';
    }
  }

  // ------------------------------------------------------------------
  // Fuzzy Matching
  // ------------------------------------------------------------------
  String fuzzyMatch(String input) {
    if (input.isEmpty) return input;
    final normalized = drugSynonyms[input.toLowerCase()] ?? input;

    String best = normalized;
    double bestScore = 0.0;

    for (final name in allDrugNames) {
      final score = _similarity(normalized.toLowerCase(), name.toLowerCase());
      if (score > bestScore) {
        bestScore = score;
        best = name;
      }
    }

    return best;
  }

  List<String> getSuggestions(String input, {int limit = 5}) {
    if (input.isEmpty) return [];
    final lower = input.toLowerCase();
    return allDrugNames
        .where((name) => name.toLowerCase().contains(lower))
        .take(limit)
        .toList();
  }

  double _similarity(String s1, String s2) {
    if (s1.isEmpty && s2.isEmpty) return 1.0;
    final dist = _levenshtein(s1, s2);
    return 1.0 - dist / (s1.length > s2.length ? s1.length : s2.length);
  }

  int _levenshtein(String s1, String s2) {
    final len1 = s1.length;
    final len2 = s2.length;
    final dp = List.generate(len1 + 1, (_) => List<int>.filled(len2 + 1, 0));
    for (int i = 0; i <= len1; i++) {
      dp[i][0] = i;
    }
    for (int j = 0; j <= len2; j++) {
      dp[0][j] = j;
    }
    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        dp[i][j] = s1[i - 1] == s2[j - 1]
            ? dp[i - 1][j - 1]
            : 1 +
                [dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]]
                    .reduce((a, b) => a < b ? a : b);
      }
    }
    return dp[len1][len2];
  }

  // ------------------------------------------------------------------
  // Search Interactions
  // ------------------------------------------------------------------
  Future<List<Map<String, String>>> searchInteractions(String d1,
      {String? d2}) async {
    await loadData();
    if (_cachedInteractions == null) return [];

    final lowerD1 = fuzzyMatch(d1).toLowerCase();
    final lowerD2 = d2 != null ? fuzzyMatch(d2).toLowerCase() : null;

    final List<Map<String, String>> matches = [];

    for (final row in _cachedInteractions!) {
      if (row.length < 5) continue;
      final drugA = row[1].toString().toLowerCase();
      final drugB = row[3].toString().toLowerCase();
      final level = row[4].toString();

      bool match = drugA.contains(lowerD1) || drugB.contains(lowerD1);
      if (lowerD2 != null) {
        match = match && (drugA.contains(lowerD2) || drugB.contains(lowerD2));
      }

      if (match) {
        matches.add({'drugA': row[1].toString(), 'drugB': row[3].toString(), 'level': level});
      }
    }

    return matches;
  }

  // ------------------------------------------------------------------
  // Check Two Drugs
  // ------------------------------------------------------------------
  Future<InteractionResult> checkTwoDrugs(String d1, String d2) async {
    final matches = await searchInteractions(d1, d2: d2);
    if (matches.isNotEmpty) {
      final descs = matches
          .map((m) => '${m['drugA']} <-> ${m['drugB']}: ${m['level']}')
          .join('\n');
      final prompt =
          'Turn this drug interaction data into 1-2 simple, patient-friendly sentences.\n'
          'Indicate severity: HIGH, MODERATE, or LOW.\n'
          'Data:\n$descs';
      final summary = await _aiService.summarize(prompt);
      final severity = _guessSeverity(descs);
      return InteractionResult(
          drug1: d1, drug2: d2, severity: severity, summary: summary);
    }
    return InteractionResult(
      drug1: d1,
      drug2: d2,
      severity: SeverityLevel.unknown,
      summary: 'No interactions found. Consult a doctor or pharmacist.',
    );
  }

  // ------------------------------------------------------------------
  // Check Single Drug
  // ------------------------------------------------------------------
  Future<SingleDrugResult> checkOneDrug(String drug) async {
    final matches = await searchInteractions(drug);
    if (matches.isNotEmpty) {
      final lines = matches
          .map((m) => '- ${m['drugA']} <-> ${m['drugB']}: ${m['level']}')
          .join('\n');
      final prompt =
          'Create a clear bullet list of interactions for $drug from this data.\n'
          'Keep bullets short and understandable.\n'
          'Add final note: "Based on DDInter database -- consult a healthcare professional."\n'
          'Data:\n$lines';
      final summary = await _aiService.summarize(prompt);
      return SingleDrugResult(drug: drug, summary: summary);
    }
    return SingleDrugResult(
      drug: drug,
      summary: 'No known interactions found.',
    );
  }

  SeverityLevel _guessSeverity(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('major') ||
        lower.contains('fatal') ||
        lower.contains('contraindicated')) {
      return SeverityLevel.high;
    }
    if (lower.contains('moderate') ||
        lower.contains('risk') ||
        lower.contains('caution')) {
      return SeverityLevel.moderate;
    }
    return SeverityLevel.low;
  }
}
