import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../../core/theme/theme_extensions.dart';
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
  String _frequency = 'Daily';
  MedicationForm _form = MedicationForm.pill;

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
    if (widget.existing != null) {
      _nameController.text = widget.existing!.name;
      _dosageController.text = widget.existing!.dosage ?? '';
      _frequency = widget.existing!.frequency ?? 'Daily';
      _form = widget.existing!.form;
    }
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    if (_isEditing) {
      final updated = widget.existing!.copyWith(
        name: name,
        dosage: _dosageController.text.trim().isNotEmpty
            ? _dosageController.text.trim()
            : null,
        frequency: _frequency,
        form: _form,
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
      );
      ref.read(medicationListProvider.notifier).add(medication);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

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
              value: _frequency,
              decoration: const InputDecoration(
                labelText: 'Frequency',
                prefixIcon: Icon(Icons.schedule),
              ),
              items: _frequencies
                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _frequency = value);
              },
            ),
            SizedBox(height: spacing.m),
            DropdownButtonFormField<MedicationForm>(
              value: _form,
              decoration: const InputDecoration(
                labelText: 'Form',
                prefixIcon: Icon(Icons.medication_outlined),
              ),
              items: const [
                DropdownMenuItem(
                  value: MedicationForm.pill,
                  child: Text('Pill'),
                ),
                DropdownMenuItem(
                  value: MedicationForm.tablet,
                  child: Text('Tablet'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _form = value);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    super.dispose();
  }
}
