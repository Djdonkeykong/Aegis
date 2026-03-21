import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ai_service.dart';
import '../services/drug_service.dart';
import '../services/interaction_summary_cache_service.dart';
import '../services/openfda_service.dart';
import '../services/rxnav_service.dart';
import '../models/interaction_result.dart';

// AI Service provider - swap implementation here for cloud API later
final aiServiceProvider = Provider<AiService>((ref) {
  return OllamaAiService();
});

// Drug Service provider
final rxNavServiceProvider = Provider<RxNavService>((ref) {
  return RxNavService();
});

final openFdaServiceProvider = Provider<OpenFdaService>((ref) {
  return OpenFdaService();
});

final interactionSummaryCacheServiceProvider =
    Provider<InteractionSummaryCacheService>((ref) {
  return InteractionSummaryCacheService();
});

// Drug Service provider
final drugServiceProvider = Provider<DrugService>((ref) {
  final aiService = ref.watch(aiServiceProvider);
  final rxNavService = ref.watch(rxNavServiceProvider);
  final openFdaService = ref.watch(openFdaServiceProvider);
  final cacheService = ref.watch(interactionSummaryCacheServiceProvider);
  return DrugService(
    aiService: aiService,
    rxNavService: rxNavService,
    openFdaService: openFdaService,
    summaryCacheService: cacheService,
  );
});

// Data loading state
final drugDataLoadedProvider = FutureProvider<void>((ref) async {
  final drugService = ref.read(drugServiceProvider);
  await drugService.loadData();
});

// Drug suggestions for autocomplete
final drugSuggestionsProvider =
    Provider.family<List<DrugSuggestion>, String>((ref, input) {
  final drugService = ref.read(drugServiceProvider);
  return drugService.getSuggestions(input);
});

// Two-drug check
final twoDrugCheckProvider = FutureProvider.autoDispose
    .family<InteractionResult, ({String drug1, String drug2})>(
        (ref, params) async {
  final drugService = ref.read(drugServiceProvider);
  return drugService.checkTwoDrugs(params.drug1, params.drug2);
});

// Single-drug check
final singleDrugCheckProvider =
    FutureProvider.autoDispose.family<SingleDrugResult, String>(
        (ref, drug) async {
  final drugService = ref.read(drugServiceProvider);
  return drugService.checkOneDrug(drug);
});
