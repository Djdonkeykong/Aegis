enum SeverityLevel { high, moderate, low, unknown }

class InteractionResult {
  final String drug1;
  final String drug2;
  final SeverityLevel severity;
  final String summary;

  InteractionResult({
    required this.drug1,
    required this.drug2,
    required this.severity,
    required this.summary,
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
}

class SingleDrugResult {
  final String drug;
  final String summary;

  SingleDrugResult({required this.drug, required this.summary});
}
