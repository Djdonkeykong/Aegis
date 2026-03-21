enum SeverityLevel { high, moderate, low, unknown }

class InteractionMatch {
  final String drugA;
  final String drugB;
  final String level;
  final String source;

  const InteractionMatch({
    required this.drugA,
    required this.drugB,
    required this.level,
    required this.source,
  });
}

class SingleDrugInteractionItem {
  final String drugName;
  final SeverityLevel severity;
  final String levelDescription;

  const SingleDrugInteractionItem({
    required this.drugName,
    required this.severity,
    required this.levelDescription,
  });
}

class InteractionResult {
  final String drug1;
  final String drug2;
  final String displayDrug1;
  final String displayDrug2;
  final SeverityLevel severity;
  final String summary;
  final String? recognizedDrug1;
  final String? recognizedDrug2;
  final String? recognizedDisplayDrug1;
  final String? recognizedDisplayDrug2;
  final List<String> unmatchedInputs;
  final List<InteractionMatch> matches;

  InteractionResult({
    required this.drug1,
    required this.drug2,
    required this.displayDrug1,
    required this.displayDrug2,
    required this.severity,
    required this.summary,
    this.recognizedDrug1,
    this.recognizedDrug2,
    this.recognizedDisplayDrug1,
    this.recognizedDisplayDrug2,
    this.unmatchedInputs = const [],
    this.matches = const [],
  });

  String get severityText {
    switch (severity) {
      case SeverityLevel.high:
        return 'High Risk';
      case SeverityLevel.moderate:
        return 'Moderate Risk';
      case SeverityLevel.low:
        return 'Low Risk';
      case SeverityLevel.unknown:
        return 'Unknown';
    }
  }

  bool get hasMatches => matches.isNotEmpty;
  bool get hasUnmatchedInputs => unmatchedInputs.isNotEmpty;
}

class SingleDrugResult {
  final String drug;
  final String displayDrug;
  final String summary;
  final String? recognizedDrug;
  final String? recognizedDisplayDrug;
  final List<String> unmatchedInputs;
  final List<InteractionMatch> matches;
  final List<SingleDrugInteractionItem> interactionItems;

  SingleDrugResult({
    required this.drug,
    required this.displayDrug,
    required this.summary,
    this.recognizedDrug,
    this.recognizedDisplayDrug,
    this.unmatchedInputs = const [],
    this.matches = const [],
    this.interactionItems = const [],
  });

  bool get hasMatches => matches.isNotEmpty;
  bool get hasUnmatchedInputs => unmatchedInputs.isNotEmpty;
  bool get hasInteractionItems => interactionItems.isNotEmpty;
}
