import 'package:flutter_riverpod/flutter_riverpod.dart';
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

// Tracks which medications have been taken on which dates.
// State: Map<"yyyy-MM-dd", Set<medicationId>>
class MedicationLogNotifier
    extends StateNotifier<Map<String, Set<String>>> {
  MedicationLogNotifier() : super({});

  void toggle(String dateKey, String medId) {
    final current = Map<String, Set<String>>.from(state);
    final daySet = Set<String>.from(current[dateKey] ?? {});
    if (daySet.contains(medId)) {
      daySet.remove(medId);
    } else {
      daySet.add(medId);
    }
    current[dateKey] = daySet;
    state = current;
  }

  bool isTaken(String dateKey, String medId) {
    return state[dateKey]?.contains(medId) ?? false;
  }
}

final medicationLogProvider =
    StateNotifierProvider<MedicationLogNotifier, Map<String, Set<String>>>(
        (ref) {
  return MedicationLogNotifier();
});
