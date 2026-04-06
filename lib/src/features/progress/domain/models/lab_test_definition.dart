enum LabRangeSource {
  none,
  labProvided,
  fallbackGeneral,
}

class LabReferenceRange {
  const LabReferenceRange({
    required this.unit,
    required this.source,
    required this.label,
    this.low,
    this.high,
    this.note,
  });

  final double? low;
  final double? high;
  final String unit;
  final LabRangeSource source;
  final String label;
  final String? note;

  bool get hasBounds => low != null || high != null;

  bool matchesUnit(String otherUnit) {
    return _normalizeUnit(unit) == _normalizeUnit(otherUnit);
  }

  String get shortLabel {
    if (!hasBounds) {
      return 'No range';
    }
    if (low != null && high != null) {
      return '${_formatNumber(low!)}-${_formatNumber(high!)} $unit';
    }
    if (low != null) {
      return '>= ${_formatNumber(low!)} $unit';
    }
    return '<= ${_formatNumber(high!)} $unit';
  }
}

class LabTestDefinition {
  const LabTestDefinition({
    required this.id,
    required this.name,
    required this.loincCode,
    required this.category,
    required this.defaultUnit,
    required this.supportedUnits,
    required this.summary,
    this.aliases = const [],
    this.generalReferenceRanges = const [],
    this.note,
  });

  final String id;
  final String name;
  final String loincCode;
  final String category;
  final String defaultUnit;
  final List<String> supportedUnits;
  final List<String> aliases;
  final String summary;
  final List<LabReferenceRange> generalReferenceRanges;
  final String? note;

  LabReferenceRange? rangeForUnit(String unit) {
    for (final range in generalReferenceRanges) {
      if (range.matchesUnit(unit) && range.hasBounds) {
        return range;
      }
    }
    return null;
  }

  bool matchesQuery(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return true;

    final haystack = <String>[
      name,
      loincCode,
      category,
      ...aliases,
    ].join(' ').toLowerCase();

    return haystack.contains(normalizedQuery);
  }
}

String _normalizeUnit(String value) {
  return value.trim().toLowerCase().replaceAll('μ', 'u');
}

String _formatNumber(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}
