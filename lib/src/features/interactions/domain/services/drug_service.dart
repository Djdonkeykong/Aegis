import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import '../../../../../core/constants/app_constants.dart';
import '../models/interaction_result.dart';
import 'ai_service.dart';
import 'interaction_summary_cache_service.dart';
import 'openfda_service.dart';
import 'rxnav_service.dart';

class DrugSuggestion {
  final String value;
  final String displayLabel;

  const DrugSuggestion({
    required this.value,
    required this.displayLabel,
  });
}

class DrugService {
  final AiService _aiService;
  final RxNavService _rxNavService;
  final OpenFdaService _openFdaService;
  final InteractionSummaryCacheService _summaryCacheService;

  DrugService({
    required AiService aiService,
    required RxNavService rxNavService,
    required OpenFdaService openFdaService,
    required InteractionSummaryCacheService summaryCacheService,
  })  : _aiService = aiService,
        _rxNavService = rxNavService,
        _openFdaService = openFdaService,
        _summaryCacheService = summaryCacheService;

  // Cached interaction rows
  List<InteractionMatch>? _cachedInteractions;
  bool _dataLoadFailed = false;
  String _loadErrorMsg = '';

  // All drug names for autocomplete
  final Set<String> allDrugNames = {};
  final Map<String, String> _canonicalDrugNamesByNormalized = {};
  final Map<String, List<String>> _drugAliasesByCanonical = {};
  final Map<String, String> _aliasToCanonicalByNormalized = {};

  static const List<String> _nonDrugWords = [
    'tablet',
    'tablets',
    'capsule',
    'capsules',
    'caplet',
    'caplets',
    'pill',
    'pills',
    'oral',
    'solution',
    'suspension',
    'injection',
    'cream',
    'gel',
    'ointment',
    'drops',
    'extended',
    'release',
    'delayed',
    'er',
    'xr',
    'sr',
    'dr',
    'mg',
    'mcg',
    'g',
    'ml',
  ];

  bool get isLoaded => _cachedInteractions != null;
  bool get loadFailed => _dataLoadFailed;
  String get loadError => _loadErrorMsg;

  // ------------------------------------------------------------------
  // CSV Loading
  // ------------------------------------------------------------------
  Future<void> loadData() async {
    if (_cachedInteractions != null || _dataLoadFailed) return;

    final List<InteractionMatch> allRows = [];
    final seenKeys = <String>{};

    void addDrugName(String name) {
      final trimmed = name.trim();
      if (trimmed.isEmpty) return;
      allDrugNames.add(trimmed);
      _canonicalDrugNamesByNormalized.putIfAbsent(
        _normalizeForLookup(trimmed),
        () => trimmed,
      );
    }

    void addInteraction({
      required String source,
      required String drugA,
      required String drugB,
      required String level,
    }) {
      final cleanedDrugA = drugA.trim();
      final cleanedDrugB = drugB.trim();
      final cleanedLevel = level.trim();
      if (cleanedDrugA.isEmpty || cleanedDrugB.isEmpty || cleanedLevel.isEmpty) {
        return;
      }

      final pair = [
        _normalizeForLookup(cleanedDrugA),
        _normalizeForLookup(cleanedDrugB),
      ]..sort();
      final key = '${pair[0]}|${pair[1]}|${cleanedLevel.toLowerCase()}';
      if (!seenKeys.add(key)) return;

      allRows.add(
        InteractionMatch(
          drugA: cleanedDrugA,
          drugB: cleanedDrugB,
          level: cleanedLevel,
          source: source,
        ),
      );
      addDrugName(cleanedDrugA);
      addDrugName(cleanedDrugB);
    }

    try {
      await _loadAliasData();

      // DDInter CSVs
      for (final asset in AppConstants.ddinterCsvAssets) {
        final csvString = await rootBundle.loadString(asset);
        final csvData =
            const CsvToListConverter().convert(csvString, eol: '\n');
        if (csvData.isNotEmpty) {
          for (final row in csvData.skip(1)) {
            if (row.length >= 4) {
              addInteraction(
                source: 'DDInter',
                drugA: row[1].toString(),
                drugB: row[3].toString(),
                level: row.length >= 5 ? row[4].toString() : 'Unknown',
              );
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
            addInteraction(
              source: 'Kaggle',
              drugA: row[0].toString(),
              drugB: row[1].toString(),
              level: row[2].toString(),
            );
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
  String _normalizeForLookup(String input) {
    var normalized = input.toLowerCase().trim();
    normalized = normalized.replaceAll(RegExp(r'\(.*?\)'), ' ');
    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    normalized = normalized.replaceAll(RegExp(r'\b\d+(\.\d+)?\b'), ' ');

    final filteredWords = normalized
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty && !_nonDrugWords.contains(word))
        .toList();

    return filteredWords.join(' ').trim();
  }

  Future<String?> _resolveCanonicalDrugName(String input) async {
    final normalizedInput = _normalizeForLookup(input);
    if (normalizedInput.isEmpty) return null;

    final synonymTarget = _aliasToCanonicalByNormalized[normalizedInput];
    if (synonymTarget != null) {
      final normalizedSynonym = _normalizeForLookup(synonymTarget);
      return _canonicalDrugNamesByNormalized[normalizedSynonym] ?? synonymTarget;
    }

    final exactMatch = _canonicalDrugNamesByNormalized[normalizedInput];
    if (exactMatch != null) return exactMatch;

    final rxNavNormalized = await _rxNavService.normalizeDrugName(input);
    if (rxNavNormalized != null) {
      final normalizedRxNavName = _normalizeForLookup(rxNavNormalized);
      final rxNavAliasTarget = _aliasToCanonicalByNormalized[normalizedRxNavName];
      if (rxNavAliasTarget != null) {
        return _canonicalDrugNamesByNormalized[
                _normalizeForLookup(rxNavAliasTarget)] ??
            rxNavAliasTarget;
      }

      final rxNavExactMatch = _canonicalDrugNamesByNormalized[normalizedRxNavName];
      if (rxNavExactMatch != null) return rxNavExactMatch;
    }

    String? best;
    double bestScore = 0.0;

    for (final entry in _canonicalDrugNamesByNormalized.entries) {
      final score = _similarity(normalizedInput, entry.key);
      if (score > bestScore) {
        bestScore = score;
        best = entry.value;
      }
    }

    if (bestScore >= 0.86) {
      return best;
    }

    return null;
  }

  List<DrugSuggestion> getSuggestions(String input, {int limit = 5}) {
    if (input.isEmpty) return [];
    final normalizedInput = _normalizeForLookup(input);
    if (normalizedInput.isEmpty) return [];

    final suggestions = <String, DrugSuggestion>{};

    final synonymTarget = _aliasToCanonicalByNormalized[normalizedInput];
    if (synonymTarget != null) {
      final canonical =
          _canonicalDrugNamesByNormalized[_normalizeForLookup(synonymTarget)] ??
              synonymTarget;
      suggestions[canonical.toLowerCase()] = DrugSuggestion(
        value: canonical,
        displayLabel: _formatSuggestionLabel(canonical),
      );
    }

    for (final name in allDrugNames) {
      final normalizedName = _normalizeForLookup(name);
      if (normalizedName.startsWith(normalizedInput) ||
          normalizedName.contains(normalizedInput) ||
          _matchesAlias(normalizedInput, name)) {
        suggestions[name.toLowerCase()] = DrugSuggestion(
          value: name,
          displayLabel: _formatSuggestionLabel(name),
        );
      }
    }

    final sortedSuggestions = suggestions.values.toList()
      ..sort((a, b) {
        final normalizedA = _normalizeForLookup(a.displayLabel);
        final normalizedB = _normalizeForLookup(b.displayLabel);
        final startsA = normalizedA.startsWith(normalizedInput) ? 0 : 1;
        final startsB = normalizedB.startsWith(normalizedInput) ? 0 : 1;
        final compareStarts = startsA.compareTo(startsB);
        if (compareStarts != 0) return compareStarts;
        return a.displayLabel.toLowerCase().compareTo(
              b.displayLabel.toLowerCase(),
            );
      });

    return sortedSuggestions
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
  Future<List<InteractionMatch>> searchInteractions(String d1, {String? d2}) async {
    await loadData();
    if (_cachedInteractions == null) return [];

    final resolvedD1 = await _resolveCanonicalDrugName(d1);
    final resolvedD2 = d2 != null ? await _resolveCanonicalDrugName(d2) : null;
    if (resolvedD1 == null) return [];
    if (d2 != null && resolvedD2 == null) return [];

    final normalizedD1 = _normalizeForLookup(resolvedD1);
    final normalizedD2 = resolvedD2 != null ? _normalizeForLookup(resolvedD2) : null;

    final List<InteractionMatch> matches = [];

    for (final row in _cachedInteractions!) {
      final drugA = _normalizeForLookup(row.drugA);
      final drugB = _normalizeForLookup(row.drugB);

      bool match = drugA == normalizedD1 || drugB == normalizedD1;
      if (normalizedD2 != null) {
        match = match && (drugA == normalizedD2 || drugB == normalizedD2);
      }

      if (match) {
        matches.add(row);
      }
    }

    return matches;
  }

  // ------------------------------------------------------------------
  // Check Two Drugs
  // ------------------------------------------------------------------
  Future<InteractionResult> checkTwoDrugs(String d1, String d2) async {
    await loadData();
    final resolvedD1 = await _resolveCanonicalDrugName(d1);
    final resolvedD2 = await _resolveCanonicalDrugName(d2);
    final unmatchedInputs = <String>[
      if (resolvedD1 == null) d1,
      if (resolvedD2 == null) d2,
    ];

    if (unmatchedInputs.isNotEmpty) {
      return InteractionResult(
        drug1: d1,
        drug2: d2,
        displayDrug1: d1.trim(),
        displayDrug2: d2.trim(),
        severity: SeverityLevel.unknown,
        summary:
            'We could not recognize ${unmatchedInputs.join(' and ')} in the local interaction database. Try a generic ingredient name.',
        recognizedDrug1: resolvedD1,
        recognizedDrug2: resolvedD2,
        recognizedDisplayDrug1: resolvedD1,
        recognizedDisplayDrug2: resolvedD2,
        unmatchedInputs: unmatchedInputs,
      );
    }

    final matches = await searchInteractions(d1, d2: d2);
    final canonicalDrug1 = resolvedD1!;
    final canonicalDrug2 = resolvedD2!;
    if (matches.isNotEmpty) {
      final descs = matches
          .map((m) => '${m.drugA} <-> ${m.drugB}: ${m.level}')
          .join('\n');
      final summary = await _summarizeTwoDrugMatches(
        canonicalDrug1: canonicalDrug1,
        canonicalDrug2: canonicalDrug2,
        matches: matches,
      );
      final severity = _guessSeverity(descs);
      return InteractionResult(
        drug1: d1,
        drug2: d2,
        displayDrug1: canonicalDrug1,
        displayDrug2: canonicalDrug2,
        severity: severity,
        summary: summary,
        recognizedDrug1: canonicalDrug1,
        recognizedDrug2: canonicalDrug2,
        recognizedDisplayDrug1: canonicalDrug1,
        recognizedDisplayDrug2: canonicalDrug2,
        matches: matches,
      );
    }
    return InteractionResult(
      drug1: d1,
      drug2: d2,
      displayDrug1: canonicalDrug1,
      displayDrug2: canonicalDrug2,
      severity: SeverityLevel.unknown,
      summary:
          'No interaction was found in the bundled database for $canonicalDrug1 and $canonicalDrug2. That does not guarantee the combination is safe.',
      recognizedDrug1: canonicalDrug1,
      recognizedDrug2: canonicalDrug2,
      recognizedDisplayDrug1: canonicalDrug1,
      recognizedDisplayDrug2: canonicalDrug2,
    );
  }

  // ------------------------------------------------------------------
  // Check Single Drug
  // ------------------------------------------------------------------
  Future<SingleDrugResult> checkOneDrug(String drug) async {
    await loadData();
    final resolvedDrug = await _resolveCanonicalDrugName(drug);
    if (resolvedDrug == null) {
      return SingleDrugResult(
        drug: drug,
        displayDrug: drug.trim(),
        summary:
            'We could not recognize "$drug" in the local interaction database. Try a generic ingredient name.',
        unmatchedInputs: [drug],
      );
    }

    final matches = await searchInteractions(drug);
    if (matches.isNotEmpty) {
      final lines = matches
          .map((m) => '- ${m.drugA} <-> ${m.drugB}: ${m.level}')
          .join('\n');
      final summary = await _summarizeSingleDrugMatches(
        drug: drug,
        resolvedDrug: resolvedDrug,
        matches: matches,
        prompt:
            'Write a short patient-friendly summary for $drug based only on the interaction facts below.\n'
            'Do not mention databases, CSV files, or internal sources.\n'
            'Mention a few important examples and advise the user to review combinations with a clinician or pharmacist.\n'
            'Data:\n$lines',
      );
      return SingleDrugResult(
        drug: drug,
        displayDrug: resolvedDrug,
        summary: summary,
        recognizedDrug: resolvedDrug,
        recognizedDisplayDrug: resolvedDrug,
        matches: matches,
        interactionItems: _buildSingleDrugInteractionItems(
          resolvedDrug: resolvedDrug,
          matches: matches,
        ),
      );
    }
    return SingleDrugResult(
      drug: drug,
      displayDrug: resolvedDrug,
      summary:
          'No interactions were found in the bundled database for $resolvedDrug. That does not guarantee the medication has no interactions.',
      recognizedDrug: resolvedDrug,
      recognizedDisplayDrug: resolvedDrug,
    );
  }

  Future<void> _loadAliasData() async {
    if (_drugAliasesByCanonical.isNotEmpty) return;

    final aliasString =
        await rootBundle.loadString(AppConstants.drugAliasesAsset);
    final decoded = jsonDecode(aliasString) as Map<String, dynamic>;

    for (final entry in decoded.entries) {
      final canonical = entry.key.trim();
      final aliases = (entry.value as List<dynamic>)
          .map((alias) => alias.toString().trim())
          .where((alias) => alias.isNotEmpty)
          .toList();

      _drugAliasesByCanonical[_normalizeForLookup(canonical)] = aliases;
      _aliasToCanonicalByNormalized[_normalizeForLookup(canonical)] = canonical;
      for (final alias in aliases) {
        _aliasToCanonicalByNormalized[_normalizeForLookup(alias)] = canonical;
      }
    }
  }

  String _formatSuggestionLabel(String drugName) {
    final trimmed = drugName.trim();
    if (trimmed.isEmpty) return drugName;

    final aliases = _drugAliasesByCanonical[_normalizeForLookup(trimmed)];
    if (aliases == null || aliases.isEmpty) return trimmed;
    return '$trimmed (${aliases.join(', ')})';
  }

  bool _matchesAlias(String normalizedInput, String canonicalName) {
    final aliases = _drugAliasesByCanonical[_normalizeForLookup(canonicalName)];
    if (aliases == null) return false;

    for (final alias in aliases) {
      final normalizedAlias = _normalizeForLookup(alias);
      if (normalizedAlias.startsWith(normalizedInput) ||
          normalizedAlias.contains(normalizedInput)) {
        return true;
      }
    }

    return false;
  }

  List<SingleDrugInteractionItem> _buildSingleDrugInteractionItems({
    required String resolvedDrug,
    required List<InteractionMatch> matches,
  }) {
    final itemsByDrug = <String, SingleDrugInteractionItem>{};
    final normalizedResolvedDrug = _normalizeForLookup(resolvedDrug);

    for (final match in matches) {
      final severity = _guessSeverity(match.level);
      if (severity == SeverityLevel.unknown) continue;

      final normalizedDrugA = _normalizeForLookup(match.drugA);
      final counterpart = normalizedDrugA == normalizedResolvedDrug
          ? match.drugB
          : match.drugA;
      final normalizedCounterpart = _normalizeForLookup(counterpart);
      final displayName = _formatSuggestionLabel(counterpart);

      final current = itemsByDrug[normalizedCounterpart];
      final candidate = SingleDrugInteractionItem(
        drugName: displayName,
        severity: severity,
        levelDescription: match.level,
      );

      if (current == null ||
          _severityRank(severity) < _severityRank(current.severity)) {
        itemsByDrug[normalizedCounterpart] = candidate;
      }
    }

    final items = itemsByDrug.values.toList()
      ..sort((a, b) {
        final severityCompare = _severityRank(a.severity).compareTo(
          _severityRank(b.severity),
        );
        if (severityCompare != 0) return severityCompare;
        return a.drugName.toLowerCase().compareTo(b.drugName.toLowerCase());
      });

    return items;
  }

  Future<String> _summarizeTwoDrugMatches({
    required String canonicalDrug1,
    required String canonicalDrug2,
    required List<InteractionMatch> matches,
  }) async {
    final cacheKey = _buildPairCacheKey(canonicalDrug1, canonicalDrug2);
    final cachedEntry = await _summaryCacheService.get(cacheKey);
    if (cachedEntry != null && cachedEntry.summary.trim().isNotEmpty) {
      return cachedEntry.summary;
    }

    final bestMatch = _bestExplanatoryMatch(matches);
    final severity = _guessSeverity(bestMatch.level);
    final context = await _openFdaService.fetchInteractionContext(
      canonicalDrug1,
      canonicalDrug2,
    );

    final baseSummary = _buildVerifiedInteractionSummary(
      drug1: canonicalDrug1,
      drug2: canonicalDrug2,
      match: bestMatch,
      context: context,
      severity: severity,
    );

    final polishedSummary = await _polishVerifiedInteractionSummary(
      drug1: canonicalDrug1,
      drug2: canonicalDrug2,
      summary: baseSummary,
      context: context,
    );

    await _summaryCacheService.set(
      cacheKey,
      InteractionSummaryCacheEntry(
        summary: polishedSummary,
        severity: severity.name,
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );

    return polishedSummary;
  }

  Future<String> _summarizeSingleDrugMatches({
    required String drug,
    required String resolvedDrug,
    required List<InteractionMatch> matches,
    required String prompt,
  }) async {
    final aiSummary = await _aiService.summarize(prompt);
    if (_isUsableAiSummary(aiSummary)) {
      return aiSummary;
    }

    final items = _buildSingleDrugInteractionItems(
      resolvedDrug: resolvedDrug,
      matches: matches,
    );
    final highestRiskMatch = _highestRiskMatch(matches);
    final highCount =
        items.where((item) => item.severity == SeverityLevel.high).length;
    final moderateCount =
        items.where((item) => item.severity == SeverityLevel.moderate).length;
    final lowCount =
        items.where((item) => item.severity == SeverityLevel.low).length;
    final samplePartners = items.take(4).map((item) => item.drugName).join(', ');

    final severitySummary = <String>[
      if (highCount > 0) '$highCount major',
      if (moderateCount > 0) '$moderateCount moderate',
      if (lowCount > 0) '$lowCount minor',
    ].join(', ');

    final lead = _buildSingleDrugLead(
      drug: resolvedDrug,
      highestRiskMatch: highestRiskMatch,
      highCount: highCount,
      moderateCount: moderateCount,
    );
    final symptoms = highestRiskMatch != null ? _defaultSymptoms(highestRiskMatch) : '';
    final guidance = _defaultSingleDrugGuidance(
      highCount: highCount,
      moderateCount: moderateCount,
    );

    return '$lead '
        'Important examples include: $samplePartners. '
        '${severitySummary.isNotEmpty ? 'The list below includes $severitySummary interactions. ' : ''}'
        '${symptoms.isNotEmpty ? '$symptoms ' : ''}'
        '$guidance';
  }

  bool _isUsableAiSummary(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    return !trimmed.startsWith('AI summarizer returned error') &&
        !trimmed.startsWith('Could not reach AI service');
  }

  String _buildPairCacheKey(String drug1, String drug2) {
    final pair = [_normalizeForLookup(drug1), _normalizeForLookup(drug2)]..sort();
    return '${pair[0]}|${pair[1]}';
  }

  int _severityRank(SeverityLevel severity) {
    switch (severity) {
      case SeverityLevel.high:
        return 0;
      case SeverityLevel.moderate:
        return 1;
      case SeverityLevel.low:
        return 2;
      case SeverityLevel.unknown:
        return 3;
    }
  }

  String _buildVerifiedInteractionSummary({
    required String drug1,
    required String drug2,
    required InteractionMatch match,
    required OpenFdaInteractionContext context,
    required SeverityLevel severity,
  }) {
    final summaryDrug1 = _preferredSummaryDrugName(drug1);
    final summaryDrug2 = _preferredSummaryDrugName(drug2);
    final intro = _summaryLead(
      drug1: summaryDrug1,
      drug2: summaryDrug2,
      match: match,
      severity: severity,
    );
    final warning = context.warnings.isNotEmpty
        ? _cleanSentenceForSummary(context.warnings.first)
        : null;
    final guidance = context.guidance.isNotEmpty
        ? _cleanSentenceForSummary(context.guidance.first)
        : _defaultGuidance(severity);
    final symptoms = context.symptoms.isNotEmpty
        ? _summarizeSymptoms(context.symptoms)
        : _defaultSymptoms(match);
    final parts = <String>[
      intro,
      if (warning != null && warning.isNotEmpty) warning,
      if (symptoms.isNotEmpty) symptoms,
      guidance,
    ];
    return parts.join(' ');
  }

  Future<String> _polishVerifiedInteractionSummary({
    required String drug1,
    required String drug2,
    required String summary,
    required OpenFdaInteractionContext context,
  }) async {
    final prompt = 'Rewrite the following verified drug interaction facts into '
        'one clear patient-friendly paragraph. Keep all facts grounded in the '
        'provided text. Do not add new medical claims.\n'
        'Drugs: $drug1 and $drug2\n'
        'Verified facts:\n$summary\n'
        'Extra evidence:\n'
        '${context.evidence.join('\n')}\n'
        '${context.guidance.join('\n')}';
    final aiSummary = await _aiService.summarize(prompt);
    if (_isUsableAiSummary(aiSummary)) {
      return aiSummary;
    }
    return summary;
  }

  InteractionMatch _bestExplanatoryMatch(List<InteractionMatch> matches) {
    matches.sort((a, b) {
      final scoreDiff = _matchExplanationScore(b) - _matchExplanationScore(a);
      if (scoreDiff != 0) return scoreDiff;
      return b.level.length - a.level.length;
    });
    return matches.first;
  }

  int _matchExplanationScore(InteractionMatch match) {
    final level = match.level.toLowerCase();
    var score = 0;

    if (level.contains('may')) score += 3;
    if (level.contains('increase') || level.contains('decrease')) score += 3;
    if (level.contains('risk') || level.contains('severity')) score += 2;
    if (level.contains('activity') || level.contains('activities')) score += 1;

    switch (_guessSeverity(match.level)) {
      case SeverityLevel.high:
        score += 3;
      case SeverityLevel.moderate:
        score += 2;
      case SeverityLevel.low:
        score += 1;
      case SeverityLevel.unknown:
        break;
    }

    return score;
  }

  String _defaultGuidance(SeverityLevel severity) {
    switch (severity) {
      case SeverityLevel.high:
        return 'Talk to your doctor or pharmacist before combining them, and do not stop either medication on your own.';
      case SeverityLevel.moderate:
        return 'A clinician may want to monitor you more closely or adjust the dose if both medicines are needed.';
      case SeverityLevel.low:
        return 'Check with a clinician if you have other health conditions or take additional medicines.';
      case SeverityLevel.unknown:
        return 'A clinician or pharmacist should review the combination before use.';
    }
  }

  String _summarizeSymptoms(List<String> symptoms) {
    final cleaned = symptoms
        .map((symptom) => _cleanSentenceForSummary(symptom))
        .map(_trimLeadingWatchFor)
        .where((symptom) => symptom.isNotEmpty)
        .toList();
    if (cleaned.isEmpty) return '';
    return 'Call your doctor promptly if you have ${cleaned.take(2).join(' ')}';
  }

  String _defaultSymptoms(InteractionMatch match) {
    final lower = match.level.toLowerCase();
    if (lower.contains('anticoagulant')) {
      return 'Call your doctor promptly if you have unusual bleeding or bruising, vomiting, blood in your urine or stools, headache, dizziness, or weakness.';
    }
    if (lower.contains('central nervous system') ||
        lower.contains('neuroexcitatory')) {
      return 'Call your doctor promptly if you have agitation, dizziness, tremor, or other nervous-system side effects.';
    }
    if (lower.contains('hypotensive')) {
      return 'Call your doctor promptly if you have dizziness, fainting, or unusual weakness from low blood pressure.';
    }
    return '';
  }

  InteractionMatch? _highestRiskMatch(List<InteractionMatch> matches) {
    if (matches.isEmpty) return null;
    final sorted = [...matches]
      ..sort((a, b) {
        final severityCompare = _severityRank(_guessSeverity(a.level))
            .compareTo(_severityRank(_guessSeverity(b.level)));
        if (severityCompare != 0) return severityCompare;
        return b.level.length.compareTo(a.level.length);
      });
    return sorted.first;
  }

  String _buildSingleDrugLead({
    required String drug,
    required InteractionMatch? highestRiskMatch,
    required int highCount,
    required int moderateCount,
  }) {
    if (highCount > 0) {
      return '$drug has several potentially serious interactions and should be reviewed carefully before combining it with other medicines.';
    }
    if (moderateCount > 0) {
      return '$drug has multiple interactions that may require caution, monitoring, or dose changes.';
    }
    if (highestRiskMatch != null) {
      return '$drug can still interact with other medicines, even when the overall risk is lower.';
    }
    return '$drug can interact with other medicines.';
  }

  String _defaultSingleDrugGuidance({
    required int highCount,
    required int moderateCount,
  }) {
    if (highCount > 0) {
      return 'Talk to your doctor or pharmacist before starting any new medicine with it, especially blood thinners, pain relievers, or long-term medications.';
    }
    if (moderateCount > 0) {
      return 'Review new combinations with a doctor or pharmacist before starting them.';
    }
    return 'Check with a clinician before adding new medicines or supplements.';
  }

  String _cleanSentenceForSummary(String text) {
    var cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    cleaned = cleaned.replaceAll(RegExp(r'^[A-Z ]+:\s*'), '');
    return cleaned;
  }

  String _trimLeadingWatchFor(String text) {
    return text.replaceFirst(RegExp(r'^(watch for|call your doctor promptly if you have)\s+', caseSensitive: false), '');
  }

  String _preferredSummaryDrugName(String drugName) {
    final aliases = _drugAliasesByCanonical[_normalizeForLookup(drugName)];
    if (aliases == null || aliases.isEmpty) return drugName;
    return aliases.first;
  }

  String _summaryLead({
    required String drug1,
    required String drug2,
    required InteractionMatch match,
    required SeverityLevel severity,
  }) {
    final lower = match.level.toLowerCase();
    if (lower.contains('anticoagulant')) {
      return 'Using $drug1 with $drug2 is a high-risk combination and may cause harm and bleeding.';
    }
    if (lower.contains('serum concentration')) {
      return 'Using $drug1 with $drug2 may raise drug levels and increase the risk of side effects or toxicity.';
    }
    if (lower.contains('central nervous system') ||
        lower.contains('neuroexcitatory')) {
      return 'Using $drug1 with $drug2 may increase the risk of nervous-system side effects.';
    }
    if (lower.contains('hypotensive')) {
      return 'Using $drug1 with $drug2 may lower your blood pressure too much and increase the risk of dizziness or fainting.';
    }
    if (lower.contains('qtc') || lower.contains('arrhythm')) {
      return 'Using $drug1 with $drug2 may increase the risk of dangerous heart rhythm problems.';
    }

    switch (severity) {
      case SeverityLevel.high:
        return 'Using $drug1 with $drug2 is a high-risk combination and may cause serious harm.';
      case SeverityLevel.moderate:
        return 'Using $drug1 with $drug2 may cause clinically important side effects or require closer monitoring.';
      case SeverityLevel.low:
        return 'Using $drug1 with $drug2 may still affect side effects or how well the medicines are tolerated.';
      case SeverityLevel.unknown:
        return 'Using $drug1 with $drug2 may affect safety or how the medicines work together.';
    }
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
