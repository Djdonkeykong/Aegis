import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../home/presentation/pages/home_page.dart';
import '../../../interactions/domain/services/openfda_service.dart';
import '../../../interactions/presentation/widgets/drug_search_field.dart';
import '../../domain/models/medication.dart';
import '../../domain/providers/medication_providers.dart';

class AddMedicationPage extends ConsumerStatefulWidget {
  final Medication? existing;

  const AddMedicationPage({super.key, this.existing});

  @override
  ConsumerState<AddMedicationPage> createState() => _AddMedicationPageState();
}

class _AddMedicationPageState extends ConsumerState<AddMedicationPage> {
  static const _dosageUnits = ['mg', 'g', 'mcg', 'mL', 'IU', 'units'];
  static const _weekdayOrder = [1, 2, 3, 4, 5, 6, 7];
  static const _weekdayLabels = {
    1: 'M',
    2: 'T',
    3: 'W',
    4: 'T',
    5: 'F',
    6: 'S',
    7: 'S',
  };
  static const _reminderOptions = [
    (0, 'At time of dose'),
    (5, '5 min before'),
    (10, '10 min before'),
    (15, '15 min before'),
    (30, '30 min before'),
    (60, '1 hour before'),
  ];

  final _nameController = TextEditingController();
  final _dosageAmountController = TextEditingController();
  final _commentController = TextEditingController();
  final _quantityController = TextEditingController();

  String _dosageUnit = _dosageUnits.first;
  MedicationForm _form = MedicationForm.pill;
  MedicationFoodTiming _foodTiming = MedicationFoodTiming.noPreference;
  List<String> _doseTimes = ['09:00'];
  Set<int> _selectedWeekdays = {...Medication.defaultWeekdays};
  bool _remindersEnabled = true;
  int _reminderMinutesBefore = 0;
  late DateTime _startDate;
  DateTime? _endDate;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_handleNameChanged);

    if (widget.existing != null) {
      final existing = widget.existing!;
      _nameController.text = existing.name;
      _commentController.text = existing.comment ?? '';
      _quantityController.text = existing.containerQuantity?.toString() ?? '';
      _hydrateDosage(existing.dosage);
      _form = existing.form;
      _foodTiming = existing.foodTiming;
      _startDate = existing.startDate;
      _endDate = existing.treatmentEndDate;
      _doseTimes = existing.reminderTimes.isNotEmpty
          ? List<String>.from(existing.reminderTimes)
          : ['09:00'];
      _selectedWeekdays = existing.selectedWeekdays.isNotEmpty
          ? {...existing.selectedWeekdays}
          : {...Medication.defaultWeekdays};
      _remindersEnabled = existing.remindersEnabled;
      _reminderMinutesBefore = existing.reminderMinutesBefore ?? 0;
    } else {
      _startDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_handleNameChanged);
    _nameController.dispose();
    _dosageAmountController.dispose();
    _commentController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _handleNameChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _hydrateDosage(String? dosage) {
    if (dosage == null || dosage.trim().isEmpty) return;

    final match =
        RegExp(r'^\s*([\d.,]+)\s*([A-Za-z]+)?\s*$').firstMatch(dosage);
    if (match == null) {
      _dosageAmountController.text = dosage;
      return;
    }

    _dosageAmountController.text = match.group(1)?.trim() ?? dosage;
    final parsedUnit = match.group(2)?.trim();
    if (parsedUnit != null &&
        _dosageUnits
            .any((unit) => unit.toLowerCase() == parsedUnit.toLowerCase())) {
      _dosageUnit = _dosageUnits.firstWhere(
        (unit) => unit.toLowerCase() == parsedUnit.toLowerCase(),
      );
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;

    setState(() {
      _startDate = DateTime(picked.year, picked.month, picked.day);
      if (_endDate != null && _endDate!.isBefore(_startDate)) {
        _endDate = _startDate;
      }
    });
  }

  Future<void> _pickEndDate() async {
    final initialDate = _endDate == null || _endDate!.isBefore(_startDate)
        ? _startDate
        : _endDate!;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );
    if (picked == null) return;

    setState(() {
      _endDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _pickTime(int index) async {
    final current = _parseStoredTime(_doseTimes[index]);
    final picked = await showModalBottomSheet<TimeOfDay>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _WheelTimePickerSheet(initialTime: current),
    );
    if (picked == null) return;

    setState(() {
      _doseTimes[index] = _storeTime(picked);
      _doseTimes.sort();
    });
  }

  Future<void> _pickReminderTiming() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: _reminderOptions
                .map(
                  (option) => ListTile(
                    title: Text(option.$2),
                    trailing: option.$1 == _reminderMinutesBefore
                        ? const Icon(
                            Icons.check_rounded,
                            color: AppColors.primary,
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(option.$1),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
    if (picked == null) return;

    setState(() {
      _reminderMinutesBefore = picked;
    });
  }

  void _addDoseTime() {
    if (_doseTimes.length >= 6) return;
    final nextHour = (8 + _doseTimes.length * 4).clamp(0, 23);
    setState(() {
      _doseTimes = [..._doseTimes, '${nextHour.toString().padLeft(2, '0')}:00']
        ..sort();
    });
  }

  void _removeDoseTime(int index) {
    if (_doseTimes.length <= 1) return;
    setState(() {
      _doseTimes = List<String>.from(_doseTimes)..removeAt(index);
    });
  }

  void _toggleWeekday(int day) {
    setState(() {
      if (_selectedWeekdays.contains(day) && _selectedWeekdays.length > 1) {
        _selectedWeekdays.remove(day);
      } else {
        _selectedWeekdays.add(day);
      }
    });
  }

  TimeOfDay _parseStoredTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  String _storeTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _displayTime(String value) {
    final time = _parseStoredTime(value);
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _displayDate(DateTime date) {
    return DateFormat('MMM d, y').format(date);
  }

  int? _parsePositiveInt(TextEditingController controller) {
    final value = int.tryParse(controller.text.trim());
    if (value == null || value <= 0) return null;
    return value;
  }

  int? _treatmentDurationFromDates() {
    if (_endDate == null) return null;
    return _endDate!.difference(_startDate).inDays + 1;
  }

  String _reminderLabel() {
    if (!_remindersEnabled) return 'Off';
    if (_reminderMinutesBefore <= 0) return 'At time of dose';
    if (_reminderMinutesBefore == 60) return '1 hour before';
    return '$_reminderMinutesBefore min before';
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final cleanedComment = _commentController.text.trim();
    final cleanedTimes = _doseTimes
        .map((time) => time.trim())
        .where((time) => time.isNotEmpty)
        .toList()
      ..sort();
    final dosageAmount = _dosageAmountController.text.trim();
    final dosage =
        dosageAmount.isNotEmpty ? '$dosageAmount $_dosageUnit' : null;
    final treatmentDays = _treatmentDurationFromDates();
    final containerQuantity = _parsePositiveInt(_quantityController);
    final selectedWeekdays = _selectedWeekdays.toList()..sort();

    if (_isEditing) {
      final updated = widget.existing!.copyWith(
        name: name,
        dosage: dosage,
        frequency: null,
        form: _form,
        reminderTimes: cleanedTimes,
        comment: cleanedComment.isNotEmpty ? cleanedComment : null,
        foodTiming: _foodTiming,
        startDate: _startDate,
        treatmentDurationDays: treatmentDays,
        containerQuantity: containerQuantity,
        selectedWeekdays: selectedWeekdays,
        remindersEnabled: _remindersEnabled,
        reminderMinutesBefore:
            _remindersEnabled ? _reminderMinutesBefore : null,
      );
      ref.read(medicationListProvider.notifier).update(updated);
    } else {
      final medication = Medication(
        id: const Uuid().v4(),
        name: name,
        dosage: dosage,
        frequency: null,
        form: _form,
        reminderTimes: cleanedTimes,
        comment: cleanedComment.isNotEmpty ? cleanedComment : null,
        foodTiming: _foodTiming,
        startDate: _startDate,
        treatmentDurationDays: treatmentDays,
        containerQuantity: containerQuantity,
        selectedWeekdays: selectedWeekdays,
        remindersEnabled: _remindersEnabled,
        reminderMinutesBefore:
            _remindersEnabled ? _reminderMinutesBefore : null,
      );
      ref.read(medicationListProvider.notifier).add(medication);
      ref.read(calendarViewModeProvider.notifier).state =
          CalendarViewMode.weekly;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final medicationName = _nameController.text.trim();
    final medicationReference =
        ref.watch(medicationReferenceProvider(medicationName));

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Medication' : 'Add Medication'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(spacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DrugSearchField(
              controller: _nameController,
              label: 'Medication name',
            ),
            if (medicationName.length >= 2) ...[
              SizedBox(height: spacing.m),
              _MedicationReferenceCard(referenceAsync: medicationReference),
            ],
            SizedBox(height: spacing.m),
            Text(
              'Dosage',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            SizedBox(height: spacing.s),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _dosageAmountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      hintText: '500',
                      prefixIcon: Icon(Icons.straighten),
                    ),
                  ),
                ),
                SizedBox(width: spacing.s),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _dosageUnit,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                    ),
                    items: _dosageUnits
                        .map(
                          (unit) => DropdownMenuItem(
                            value: unit,
                            child: Text(unit),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _dosageUnit = value);
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.l),
            Text(
              'Treatment course',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            SizedBox(height: spacing.s),
            _SelectableFormField(
              icon: Icons.event_outlined,
              label: 'Start date',
              value: _displayDate(_startDate),
              onTap: _pickStartDate,
            ),
            SizedBox(height: spacing.s),
            _SelectableFormField(
              icon: Icons.event_available_outlined,
              label: 'End date',
              value: _endDate == null ? 'No end date' : _displayDate(_endDate!),
              onTap: _pickEndDate,
              trailing: _endDate == null
                  ? null
                  : IconButton(
                      onPressed: () => setState(() => _endDate = null),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary,
                        size: 18,
                      ),
                    ),
            ),
            SizedBox(height: spacing.s),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Quantity',
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
            ),
            SizedBox(height: spacing.l),
            Text(
              'Dose times',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            SizedBox(height: spacing.xs),
            Text(
              'Tap any time to adjust it with the 24-hour scroll wheel.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            SizedBox(height: spacing.s),
            ...List.generate(_doseTimes.length, (index) {
              return Padding(
                padding: EdgeInsets.only(bottom: spacing.s),
                child: Container(
                  padding: EdgeInsets.all(spacing.s),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${index + 1}',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                      SizedBox(width: spacing.s),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _pickTime(index),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.access_time_rounded,
                                  size: 18,
                                  color: AppColors.textSecondary,
                                ),
                                SizedBox(width: spacing.s),
                                Text(
                                  _displayTime(_doseTimes[index]),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_doseTimes.length > 1)
                        IconButton(
                          onPressed: () => _removeDoseTime(index),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                    ],
                  ),
                ),
              );
            }),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addDoseTime,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add another dose'),
              ),
            ),
            SizedBox(height: spacing.m),
            Text(
              'Selected days',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            SizedBox(height: spacing.xs),
            Text(
              'Choose the days this routine should run.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            SizedBox(height: spacing.s),
            Wrap(
              spacing: spacing.s,
              runSpacing: spacing.s,
              children: _weekdayOrder
                  .map(
                    (day) => _WeekdayChip(
                      label: _weekdayLabels[day]!,
                      selected: _selectedWeekdays.contains(day),
                      onTap: () => _toggleWeekday(day),
                    ),
                  )
                  .toList(),
            ),
            SizedBox(height: spacing.l),
            Text(
              'Reminders',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            SizedBox(height: spacing.s),
            Container(
              padding: EdgeInsets.all(spacing.m),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.outline),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.notifications_active_outlined,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(width: spacing.s),
                      Expanded(
                        child: Text(
                          'Enable reminders',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                      Switch.adaptive(
                        value: _remindersEnabled,
                        onChanged: (value) {
                          setState(() => _remindersEnabled = value);
                        },
                      ),
                    ],
                  ),
                  if (_remindersEnabled) ...[
                    Divider(
                      color: AppColors.outline,
                      height: spacing.l,
                    ),
                    _SelectableFormField(
                      icon: Icons.alarm_rounded,
                      label: 'Reminder timing',
                      value: _reminderLabel(),
                      onTap: _pickReminderTiming,
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: spacing.l),
            Text(
              'Medication category',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            SizedBox(height: spacing.s),
            Wrap(
              spacing: spacing.s,
              runSpacing: spacing.s,
              children: MedicationForm.values
                  .map(
                    (form) => _MedicationFormChip(
                      form: form,
                      selected: _form == form,
                      onTap: () => setState(() => _form = form),
                    ),
                  )
                  .toList(),
            ),
            SizedBox(height: spacing.l),
            Text(
              'Food instructions',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            SizedBox(height: spacing.s),
            Wrap(
              spacing: spacing.s,
              runSpacing: spacing.s,
              children: MedicationFoodTiming.values
                  .map(
                    (timing) => ChoiceChip(
                      label: Text(timing.label),
                      selected: _foodTiming == timing,
                      onSelected: (_) => setState(() => _foodTiming = timing),
                    ),
                  )
                  .toList(),
            ),
            SizedBox(height: spacing.l),
            TextField(
              controller: _commentController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Comment',
                alignLabelWithHint: true,
                hintText: 'Add notes, instructions, or anything important.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectableFormField extends StatelessWidget {
  const _SelectableFormField({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outline),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                  ),
                ],
              ),
            ),
            trailing ??
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textSecondary,
                ),
          ],
        ),
      ),
    );
  }
}

class _WeekdayChip extends StatelessWidget {
  const _WeekdayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryContainer : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.outline,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? AppColors.onPrimaryContainer
                      : AppColors.textSecondary,
                ),
          ),
        ),
      ),
    );
  }
}

class _MedicationFormChip extends StatelessWidget {
  const _MedicationFormChip({
    required this.form,
    required this.selected,
    required this.onTap,
  });

  final MedicationForm form;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryContainer : AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.outline,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  form.iconData,
                  size: 15,
                  color: selected
                      ? AppColors.onPrimaryContainer
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                form.label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? AppColors.onPrimaryContainer
                          : AppColors.textPrimary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WheelTimePickerSheet extends StatefulWidget {
  const _WheelTimePickerSheet({
    required this.initialTime,
  });

  final TimeOfDay initialTime;

  @override
  State<_WheelTimePickerSheet> createState() => _WheelTimePickerSheetState();
}

class _WheelTimePickerSheetState extends State<_WheelTimePickerSheet> {
  late int _hour;
  late int _minute;
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialTime.hour;
    _minute = widget.initialTime.minute;
    _hourController = FixedExtentScrollController(initialItem: _hour);
    _minuteController = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final selectedLabel =
        '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}';

    return SafeArea(
      child: Padding(
        padding:
            EdgeInsets.fromLTRB(spacing.m, spacing.s, spacing.m, spacing.m),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Select dose time',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            SizedBox(height: spacing.xs),
            Text(
              selectedLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            SizedBox(height: spacing.m),
            SizedBox(
              height: 220,
              child: Row(
                children: [
                  Expanded(
                    child: _WheelColumn(
                      controller: _hourController,
                      values: List<String>.generate(
                        24,
                        (index) => index.toString().padLeft(2, '0'),
                      ),
                      onSelected: (index) => setState(() => _hour = index),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      ':',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                  ),
                  Expanded(
                    child: _WheelColumn(
                      controller: _minuteController,
                      values: List<String>.generate(
                        60,
                        (index) => index.toString().padLeft(2, '0'),
                      ),
                      onSelected: (index) => setState(() => _minute = index),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: spacing.m),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                SizedBox(width: spacing.s),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(
                      TimeOfDay(hour: _hour, minute: _minute),
                    ),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WheelColumn extends StatelessWidget {
  const _WheelColumn({
    required this.controller,
    required this.values,
    required this.onSelected,
  });

  final FixedExtentScrollController controller;
  final List<String> values;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
      ),
      child: CupertinoPicker(
        scrollController: controller,
        itemExtent: 44,
        useMagnifier: true,
        magnification: 1.05,
        onSelectedItemChanged: onSelected,
        children: values
            .map(
              (value) => Center(
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _MedicationReferenceCard extends StatelessWidget {
  const _MedicationReferenceCard({
    required this.referenceAsync,
  });

  final AsyncValue<OpenFdaMedicationReference?> referenceAsync;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return referenceAsync.when(
      data: (reference) {
        if (reference == null || !reference.hasContent) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: EdgeInsets.all(spacing.m),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FCFD),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDCEFF4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reference Data',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              SizedBox(height: spacing.s),
              _ReferenceLine(
                label: 'Generic',
                value: reference.genericNames.join(', '),
              ),
              _ReferenceLine(
                label: 'Brand',
                value: reference.brandNames.take(3).join(', '),
              ),
              _ReferenceLine(
                label: 'Manufacturer',
                value: reference.manufacturers.take(2).join(', '),
              ),
              _ReferenceLine(
                label: 'Form',
                value: reference.dosageForms.take(2).join(', '),
              ),
              _ReferenceLine(
                label: 'Route',
                value: reference.routes.take(2).join(', '),
              ),
              _ReferenceLine(
                label: 'Type',
                value: reference.productType ?? '',
              ),
              SizedBox(height: spacing.xs),
              Text(
                'Read-only metadata from openFDA. This does not change interaction results.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                    ),
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        padding: EdgeInsets.all(spacing.m),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FCFD),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDCEFF4)),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: spacing.s),
            const Expanded(child: Text('Looking up reference data...')),
          ],
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _ReferenceLine extends StatelessWidget {
  const _ReferenceLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.black87,
              ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
