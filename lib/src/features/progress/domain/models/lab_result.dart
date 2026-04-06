import 'lab_test_definition.dart';

enum LabResultSource {
  manual,
  aiDraft,
}

enum LabReviewStatus {
  confirmed,
  reviewRequired,
}

enum LabResultInterpretation {
  reviewRequired,
  low,
  inRange,
  high,
  noRange,
}

class LabResult {
  const LabResult({
    required this.id,
    required this.testId,
    required this.testName,
    required this.loincCode,
    required this.value,
    required this.unit,
    required this.collectedAt,
    required this.source,
    required this.reviewStatus,
    this.sourceLab,
    this.note,
    this.labReferenceRange,
  });

  final String id;
  final String testId;
  final String testName;
  final String loincCode;
  final double value;
  final String unit;
  final DateTime collectedAt;
  final String? sourceLab;
  final String? note;
  final LabReferenceRange? labReferenceRange;
  final LabResultSource source;
  final LabReviewStatus reviewStatus;

  LabReferenceRange? effectiveReferenceRange(LabTestDefinition? definition) {
    if (labReferenceRange != null && labReferenceRange!.hasBounds) {
      return labReferenceRange;
    }
    return definition?.rangeForUnit(unit);
  }

  LabResultInterpretation interpretation(LabTestDefinition? definition) {
    if (reviewStatus == LabReviewStatus.reviewRequired) {
      return LabResultInterpretation.reviewRequired;
    }

    final range = effectiveReferenceRange(definition);
    if (range == null || !range.hasBounds) {
      return LabResultInterpretation.noRange;
    }
    if (range.low != null && value < range.low!) {
      return LabResultInterpretation.low;
    }
    if (range.high != null && value > range.high!) {
      return LabResultInterpretation.high;
    }
    return LabResultInterpretation.inRange;
  }

  String get formattedValue {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }
}

enum LabUploadDocumentType {
  screenshot,
  pdf,
}

class LabAiDraftEntry {
  const LabAiDraftEntry({
    required this.rawTestName,
    required this.value,
    required this.unit,
    required this.reviewRequired,
    this.matchedTestId,
    this.referenceLow,
    this.referenceHigh,
    this.flag,
    this.rawReferenceText,
    this.confidence,
  });

  final String rawTestName;
  final String? matchedTestId;
  final double value;
  final String unit;
  final double? referenceLow;
  final double? referenceHigh;
  final String? flag;
  final String? rawReferenceText;
  final double? confidence;
  final bool reviewRequired;
}

class LabAiExtractionDraft {
  const LabAiExtractionDraft({
    required this.id,
    required this.fileName,
    required this.documentType,
    required this.createdAt,
    required this.entries,
    this.sourceLab,
  });

  final String id;
  final String fileName;
  final LabUploadDocumentType documentType;
  final DateTime createdAt;
  final List<LabAiDraftEntry> entries;
  final String? sourceLab;

  factory LabAiExtractionDraft.sample() {
    return LabAiExtractionDraft(
      id: 'draft-preview',
      fileName: 'blood-panel-apr-2026.pdf',
      documentType: LabUploadDocumentType.pdf,
      createdAt: DateTime(2026, 4, 6, 11, 0),
      sourceLab: 'Northshore Diagnostics',
      entries: const [
        LabAiDraftEntry(
          rawTestName: 'HbA1c',
          matchedTestId: 'hba1c',
          value: 5.8,
          unit: '%',
          referenceLow: 4.0,
          referenceHigh: 5.6,
          flag: 'high',
          rawReferenceText: '4.0 - 5.6 %',
          confidence: 0.97,
          reviewRequired: true,
        ),
        LabAiDraftEntry(
          rawTestName: 'TSH',
          matchedTestId: 'tsh',
          value: 2.1,
          unit: 'uIU/mL',
          referenceLow: 0.4,
          referenceHigh: 4.0,
          rawReferenceText: '0.4 - 4.0 uIU/mL',
          confidence: 0.95,
          reviewRequired: true,
        ),
      ],
    );
  }
}
