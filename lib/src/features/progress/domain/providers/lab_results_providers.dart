import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/common_lab_tests.dart';
import '../models/lab_result.dart';
import '../models/lab_test_definition.dart';

class LabResultsNotifier extends StateNotifier<List<LabResult>> {
  LabResultsNotifier() : super(const []);

  void add(LabResult result) {
    state = [...state, result]
      ..sort((a, b) => b.collectedAt.compareTo(a.collectedAt));
  }

  void remove(String id) {
    state = state.where((result) => result.id != id).toList();
  }
}

final labResultsProvider =
    StateNotifierProvider<LabResultsNotifier, List<LabResult>>((ref) {
  return LabResultsNotifier();
});

final labTestCatalogProvider = Provider<List<LabTestDefinition>>((ref) {
  return commonLabTests;
});

final labTestMapProvider = Provider<Map<String, LabTestDefinition>>((ref) {
  final catalog = ref.watch(labTestCatalogProvider);
  return {
    for (final test in catalog) test.id: test,
  };
});

final labAiDraftPreviewProvider = Provider<LabAiExtractionDraft>((ref) {
  return LabAiExtractionDraft.sample();
});
