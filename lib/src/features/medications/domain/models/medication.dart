enum MedicationForm {
  pill,
  tablet,
  capsule,
  liquid,
  injection,
  drops,
  cream,
  inhaler,
  patch,
}

enum MedicationFoodTiming {
  noPreference,
  beforeMeals,
  afterMeals,
  withFood,
  withoutFood,
}

class Medication {
  static const _unset = Object();

  final String id;
  final String name;
  final String? dosage;
  final String? frequency;
  final MedicationForm form;
  final List<String> reminderTimes;
  final bool remindersEnabled;
  final String? comment;
  final MedicationFoodTiming foodTiming;
  final DateTime createdAt;

  Medication({
    required this.id,
    required this.name,
    this.dosage,
    this.frequency,
    this.form = MedicationForm.pill,
    this.reminderTimes = const [],
    this.remindersEnabled = true,
    this.comment,
    this.foodTiming = MedicationFoodTiming.noPreference,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Medication copyWith({
    String? name,
    Object? dosage = _unset,
    Object? frequency = _unset,
    MedicationForm? form,
    List<String>? reminderTimes,
    bool? remindersEnabled,
    Object? comment = _unset,
    MedicationFoodTiming? foodTiming,
  }) {
    return Medication(
      id: id,
      name: name ?? this.name,
      dosage: identical(dosage, _unset) ? this.dosage : dosage as String?,
      frequency:
          identical(frequency, _unset) ? this.frequency : frequency as String?,
      form: form ?? this.form,
      reminderTimes: reminderTimes ?? this.reminderTimes,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      comment: identical(comment, _unset) ? this.comment : comment as String?,
      foodTiming: foodTiming ?? this.foodTiming,
      createdAt: createdAt,
    );
  }
}

extension MedicationFormLabel on MedicationForm {
  String get label {
    switch (this) {
      case MedicationForm.pill:
        return 'Pill';
      case MedicationForm.tablet:
        return 'Tablet';
      case MedicationForm.capsule:
        return 'Capsule';
      case MedicationForm.liquid:
        return 'Liquid';
      case MedicationForm.injection:
        return 'Injection';
      case MedicationForm.drops:
        return 'Drops';
      case MedicationForm.cream:
        return 'Cream';
      case MedicationForm.inhaler:
        return 'Inhaler';
      case MedicationForm.patch:
        return 'Patch';
    }
  }
}

extension MedicationFoodTimingLabel on MedicationFoodTiming {
  String get label {
    switch (this) {
      case MedicationFoodTiming.noPreference:
        return 'No preference';
      case MedicationFoodTiming.beforeMeals:
        return 'Before meals';
      case MedicationFoodTiming.afterMeals:
        return 'After meals';
      case MedicationFoodTiming.withFood:
        return 'With food';
      case MedicationFoodTiming.withoutFood:
        return 'Without food';
    }
  }
}
