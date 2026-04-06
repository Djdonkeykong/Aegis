import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../interactions/domain/services/openfda_service.dart';
import '../models/medication.dart';

// In-memory medication list for now. Will be replaced with Supabase in a future phase.
class MedicationListNotifier extends StateNotifier<List<Medication>> {
  MedicationListNotifier() : super([]);

  void add(Medication medication) {
    state = [...state, medication];
  }

  void remove(String id) {
    state = state.where((m) => m.id != id).toList();
  }

  void update(Medication medication) {
    state = [
      for (final m in state)
        if (m.id == medication.id) medication else m,
    ];
  }
}

final medicationListProvider =
    StateNotifierProvider<MedicationListNotifier, List<Medication>>((ref) {
  return MedicationListNotifier();
});

enum MedicationDoseStatus { taken, skipped }

// State: Map<"yyyy-MM-dd", Map<doseLogKey, MedicationDoseStatus>>
class MedicationLogNotifier
    extends StateNotifier<Map<String, Map<String, MedicationDoseStatus>>> {
  MedicationLogNotifier() : super({});

  void setStatus(
    String dateKey,
    String medId,
    MedicationDoseStatus? status,
  ) {
    final current = Map<String, Map<String, MedicationDoseStatus>>.from(state);
    final dayMap =
        Map<String, MedicationDoseStatus>.from(current[dateKey] ?? {});

    if (status == null) {
      dayMap.remove(medId);
    } else {
      dayMap[medId] = status;
    }

    if (dayMap.isEmpty) {
      current.remove(dateKey);
    } else {
      current[dateKey] = dayMap;
    }

    state = current;
  }

  void toggleTaken(String dateKey, String medId) {
    final currentStatus = statusFor(dateKey, medId);
    setStatus(
      dateKey,
      medId,
      currentStatus == MedicationDoseStatus.taken
          ? null
          : MedicationDoseStatus.taken,
    );
  }

  MedicationDoseStatus? statusFor(String dateKey, String medId) {
    return state[dateKey]?[medId];
  }

  bool isTaken(String dateKey, String medId) {
    return statusFor(dateKey, medId) == MedicationDoseStatus.taken;
  }
}

final medicationLogProvider = StateNotifierProvider<MedicationLogNotifier,
    Map<String, Map<String, MedicationDoseStatus>>>((ref) {
  return MedicationLogNotifier();
});

final openFdaMedicationServiceProvider = Provider<OpenFdaService>((ref) {
  return OpenFdaService();
});

final medicationReferenceProvider =
    FutureProvider.family<OpenFdaMedicationReference?, String>(
        (ref, query) async {
  final trimmed = query.trim();
  if (trimmed.length < 2) {
    return null;
  }

  final service = ref.read(openFdaMedicationServiceProvider);
  return service.fetchMedicationReference(trimmed);
});

final medicationAliasesProvider =
    FutureProvider<Map<String, List<String>>>((ref) async {
  final raw = await rootBundle.loadString(AppConstants.drugAliasesAsset);
  final decoded = jsonDecode(raw) as Map<String, dynamic>;

  return {
    for (final entry in decoded.entries)
      entry.key.trim().toLowerCase(): (entry.value as List<dynamic>)
          .map((alias) => alias.toString().trim())
          .where((alias) => alias.isNotEmpty)
          .toList(),
  };
});
