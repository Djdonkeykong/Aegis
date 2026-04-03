import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../interactions/domain/services/openfda_service.dart';
import '../../../home/presentation/pages/home_page.dart';
import '../../domain/models/medication.dart';
import '../../domain/providers/medication_providers.dart';
import '../../../interactions/presentation/widgets/drug_search_field.dart';

class AddMedicationPage extends ConsumerStatefulWidget {
  final Medication? existing;

  const AddMedicationPage({super.key, this.existing});

  @override
  ConsumerState<AddMedicationPage> createState() => _AddMedicationPageState();
}

class _AddMedicationPageState extends ConsumerState<AddMedicationPage> {
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _commentController = TextEditingController();
  String _frequency = 'Daily';
  MedicationForm _form = MedicationForm.pill;
  MedicationFoodTiming _foodTiming = MedicationFoodTiming.noPreference;
  List<String> _doseTimes = ['09:00'];

  bool get _isEditing => widget.existing != null;

  static const _frequencies = [
    'Daily',
    'Twice daily',
    'Three times daily',
    'As needed',
    'Weekly',
  ];

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_handleNameChanged);
    if (widget.existing != null) {
      _nameController.text = widget.existing!.name;
      _dosageController.text = widget.existing!.dosage ?? '';
      _commentController.text = widget.existing!.comment ?? '';
      _frequency = widget.existing!.frequency ?? 'Daily';
      _form = widget.existing!.form;
      _foodTiming = widget.existing!.foodTiming;
      _doseTimes = widget.existing!.reminderTimes.isNotEmpty
          ? List<String>.from(widget.existing!.reminderTimes)
          : _defaultTimesForFrequency(_frequency);
    } else {
      _doseTimes = _defaultTimesForFrequency(_frequency);
    }
  }

  void _handleNameChanged() {
    if (!mounted) return;
    setState(() {});
  }

  List<String> _defaultTimesForFrequency(String frequency) {
    switch (frequency) {
      case 'Twice daily':
        return ['09:00', '20:00'];
      case 'Three times daily':
        return ['08:00', '14:00', '20:00'];
      default:
        return ['09:00'];
    }
  }

  void _syncTimesWithFrequency(String frequency) {
    final suggested = _defaultTimesForFrequency(frequency);
    if (_doseTimes.length >= suggested.length) return;

    setState(() {
      _doseTimes = [
        ..._doseTimes,
        ...suggested.skip(_doseTimes.length),
      ];
    });
  }

  Future<void> _pickTime(int index) async {
    final current = _parseStoredTime(_doseTimes[index]);
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
    );
    if (picked == null) return;

    setState(() {
      _doseTimes[index] = _storeTime(picked);
      _doseTimes.sort();
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

  String _displayTime(BuildContext context, String value) {
    final time = _parseStoredTime(value);
    return MaterialLocalizations.of(context).formatTimeOfDay(time);
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

    if (_isEditing) {
      final updated = widget.existing!.copyWith(
        name: name,
        dosage: _dosageController.text.trim().isNotEmpty
            ? _dosageController.text.trim()
            : null,
        frequency: _frequency,
        form: _form,
        reminderTimes: cleanedTimes,
        comment: cleanedComment.isNotEmpty ? cleanedComment : null,
        foodTiming: _foodTiming,
      );
      ref.read(medicationListProvider.notifier).update(updated);
    } else {
      final medication = Medication(
        id: const Uuid().v4(),
        name: name,
        dosage: _dosageController.text.trim().isNotEmpty
            ? _dosageController.text.trim()
            : null,
        frequency: _frequency,
        form: _form,
        reminderTimes: cleanedTimes,
        comment: cleanedComment.isNotEmpty ? cleanedComment : null,
        foodTiming: _foodTiming,
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
            TextField(
              controller: _dosageController,
              decoration: const InputDecoration(
                labelText: 'Dosage (e.g., 500mg)',
                prefixIcon: Icon(Icons.straighten),
              ),
            ),
            SizedBox(height: spacing.m),
            DropdownButtonFormField<String>(
              initialValue: _frequency,
              decoration: const InputDecoration(
                labelText: 'Frequency',
                prefixIcon: Icon(Icons.schedule),
              ),
              items: _frequencies
                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _frequency = value);
                  _syncTimesWithFrequency(value);
                }
              },
            ),
            SizedBox(height: spacing.m),
            Text(
              'Dose times',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            SizedBox(height: spacing.s),
            ...List.generate(_doseTimes.length, (index) {
              return Padding(
                padding: EdgeInsets.only(bottom: spacing.s),
                child: Container(
                  padding: EdgeInsets.all(spacing.s),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dose ${index + 1}',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            SizedBox(height: spacing.xs),
                            TextButton(
                              onPressed: () => _pickTime(index),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                alignment: Alignment.centerLeft,
                              ),
                              child: Text(
                                  _displayTime(context, _doseTimes[index])),
                            ),
                          ],
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
            TextButton.icon(
              onPressed: _addDoseTime,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add another dose'),
            ),
            SizedBox(height: spacing.m),
            Text(
              'Form',
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
                    (form) => ChoiceChip(
                      label: Text(form.label),
                      selected: _form == form,
                      onSelected: (_) => setState(() => _form = form),
                    ),
                  )
                  .toList(),
            ),
            SizedBox(height: spacing.m),
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
            SizedBox(height: spacing.m),
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

  @override
  void dispose() {
    _nameController.removeListener(_handleNameChanged);
    _nameController.dispose();
    _dosageController.dispose();
    _commentController.dispose();
    super.dispose();
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
