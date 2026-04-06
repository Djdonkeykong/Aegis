import 'package:flutter/material.dart';

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
  static const defaultWeekdays = [1, 2, 3, 4, 5, 6, 7];

  final String id;
  final String name;
  final String? dosage;
  final String? frequency;
  final MedicationForm form;
  final List<String> reminderTimes;
  final bool remindersEnabled;
  final String? comment;
  final MedicationFoodTiming foodTiming;
  final DateTime startDate;
  final int? treatmentDurationDays;
  final int? containerQuantity;
  final List<int> selectedWeekdays;
  final int? reminderMinutesBefore;
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
    DateTime? startDate,
    this.treatmentDurationDays,
    this.containerQuantity,
    this.selectedWeekdays = defaultWeekdays,
    this.reminderMinutesBefore = 0,
    DateTime? createdAt,
  })  : startDate = _normalizeDate(startDate ?? DateTime.now()),
        createdAt = createdAt ?? DateTime.now();

  Medication copyWith({
    String? name,
    Object? dosage = _unset,
    Object? frequency = _unset,
    MedicationForm? form,
    List<String>? reminderTimes,
    bool? remindersEnabled,
    Object? comment = _unset,
    MedicationFoodTiming? foodTiming,
    DateTime? startDate,
    Object? treatmentDurationDays = _unset,
    Object? containerQuantity = _unset,
    List<int>? selectedWeekdays,
    Object? reminderMinutesBefore = _unset,
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
      startDate: startDate ?? this.startDate,
      treatmentDurationDays: identical(treatmentDurationDays, _unset)
          ? this.treatmentDurationDays
          : treatmentDurationDays as int?,
      containerQuantity: identical(containerQuantity, _unset)
          ? this.containerQuantity
          : containerQuantity as int?,
      selectedWeekdays: selectedWeekdays ?? this.selectedWeekdays,
      reminderMinutesBefore: identical(reminderMinutesBefore, _unset)
          ? this.reminderMinutesBefore
          : reminderMinutesBefore as int?,
      createdAt: createdAt,
    );
  }

  DateTime get normalizedStartDate => _normalizeDate(startDate);

  DateTime? get treatmentEndDate {
    final duration = treatmentDurationDays;
    if (duration == null || duration <= 0) return null;
    return normalizedStartDate.add(Duration(days: duration - 1));
  }

  bool isCompletedOn(DateTime day) {
    final endDate = treatmentEndDate;
    if (endDate == null) return false;
    return _normalizeDate(day).isAfter(endDate);
  }

  bool appliesOn(DateTime day) {
    if (selectedWeekdays.isEmpty) return true;
    return selectedWeekdays.contains(day.weekday);
  }

  int elapsedTreatmentDaysOn(DateTime day) {
    final normalizedDay = _normalizeDate(day);
    if (normalizedDay.isBefore(normalizedStartDate)) return 0;

    final elapsed = normalizedDay.difference(normalizedStartDate).inDays + 1;
    final duration = treatmentDurationDays;
    if (duration == null || duration <= 0) return elapsed;
    return elapsed.clamp(0, duration);
  }

  static DateTime _normalizeDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
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

  IconData get iconData {
    switch (this) {
      case MedicationForm.pill:
      case MedicationForm.tablet:
      case MedicationForm.capsule:
        return Icons.medication_outlined;
      case MedicationForm.liquid:
        return Icons.local_drink_outlined;
      case MedicationForm.injection:
        return Icons.vaccines_outlined;
      case MedicationForm.drops:
        return Icons.water_drop_outlined;
      case MedicationForm.cream:
        return Icons.healing_outlined;
      case MedicationForm.inhaler:
        return Icons.air_rounded;
      case MedicationForm.patch:
        return Icons.crop_square_rounded;
    }
  }

  String get quantityLabel {
    switch (this) {
      case MedicationForm.capsule:
        return 'capsule';
      case MedicationForm.tablet:
        return 'tablet';
      case MedicationForm.pill:
        return 'pill';
      case MedicationForm.liquid:
        return 'dose';
      case MedicationForm.injection:
        return 'shot';
      case MedicationForm.drops:
        return 'drop';
      case MedicationForm.cream:
        return 'application';
      case MedicationForm.inhaler:
        return 'puff';
      case MedicationForm.patch:
        return 'patch';
    }
  }

  String get quantityLabelPlural {
    switch (this) {
      case MedicationForm.capsule:
        return 'capsules';
      case MedicationForm.tablet:
        return 'tablets';
      case MedicationForm.pill:
        return 'pills';
      case MedicationForm.liquid:
        return 'doses';
      case MedicationForm.injection:
        return 'shots';
      case MedicationForm.drops:
        return 'drops';
      case MedicationForm.cream:
        return 'applications';
      case MedicationForm.inhaler:
        return 'puffs';
      case MedicationForm.patch:
        return 'patches';
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

extension MedicationScheduleLabel on Medication {
  static const _weekdayShortNames = {
    1: 'Mon',
    2: 'Tue',
    3: 'Wed',
    4: 'Thu',
    5: 'Fri',
    6: 'Sat',
    7: 'Sun',
  };

  String get selectedDaysLabel {
    final uniqueDays = {...selectedWeekdays}.toList()..sort();
    if (uniqueDays.isEmpty || uniqueDays.length == 7) {
      return 'Every day';
    }
    return uniqueDays
        .map((day) => _weekdayShortNames[day] ?? '')
        .where((label) => label.isNotEmpty)
        .join(', ');
  }

  String get reminderLabel {
    if (!remindersEnabled) return 'Off';
    final minutes = reminderMinutesBefore;
    if (minutes == null || minutes <= 0) return 'At time of dose';
    if (minutes == 60) return '1 hour before';
    return '$minutes min before';
  }
}
