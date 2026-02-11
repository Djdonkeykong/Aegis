enum MedicationForm {
  pill,
  tablet,
}

class Medication {
  final String id;
  final String name;
  final String? dosage;
  final String? frequency;
  final MedicationForm form;
  final List<String> reminderTimes;
  final bool remindersEnabled;
  final DateTime createdAt;

  Medication({
    required this.id,
    required this.name,
    this.dosage,
    this.frequency,
    this.form = MedicationForm.pill,
    this.reminderTimes = const [],
    this.remindersEnabled = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Medication copyWith({
    String? name,
    String? dosage,
    String? frequency,
    MedicationForm? form,
    List<String>? reminderTimes,
    bool? remindersEnabled,
  }) {
    return Medication(
      id: id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      frequency: frequency ?? this.frequency,
      form: form ?? this.form,
      reminderTimes: reminderTimes ?? this.reminderTimes,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      createdAt: createdAt,
    );
  }
}
