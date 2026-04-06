import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../domain/models/lab_result.dart';
import '../../domain/models/lab_test_definition.dart';
import '../../domain/providers/lab_results_providers.dart';

class AddLabResultPage extends ConsumerStatefulWidget {
  const AddLabResultPage({super.key});

  @override
  ConsumerState<AddLabResultPage> createState() => _AddLabResultPageState();
}

class _AddLabResultPageState extends ConsumerState<AddLabResultPage> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _valueController = TextEditingController();
  final _sourceLabController = TextEditingController();
  final _lowController = TextEditingController();
  final _highController = TextEditingController();
  final _noteController = TextEditingController();

  String? _selectedTestId;
  String? _selectedUnit;
  DateTime _collectedAt = DateTime.now();
  bool _useLabRange = false;

  @override
  void dispose() {
    _searchController.dispose();
    _valueController.dispose();
    _sourceLabController.dispose();
    _lowController.dispose();
    _highController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final catalog = ref.watch(labTestCatalogProvider);
    final filteredCatalog = catalog
        .where((test) => test.matchesQuery(_searchController.text))
        .toList();
    final selectedTest = _selectedTest(catalog);
    final previewRange = _previewRange(selectedTest);
    final previewResult = _buildPreviewResult(selectedTest);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Lab Result'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              spacing.m,
              spacing.s,
              spacing.m,
              spacing.xl,
            ),
            children: [
              const _InfoCard(
                title: 'Manual entry first',
                description:
                    'Choose a test, enter the result value and unit, and add the lab-provided range if it appears on the report.',
                icon: Icons.science_outlined,
              ),
              SizedBox(height: spacing.m),
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search tests, aliases, or LOINC',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: spacing.m),
              DropdownButtonFormField<String>(
                initialValue:
                    filteredCatalog.any((test) => test.id == _selectedTestId)
                        ? _selectedTestId
                        : null,
                items: filteredCatalog
                    .map(
                      (test) => DropdownMenuItem<String>(
                        value: test.id,
                        child: Text('${test.name} | ${test.loincCode}'),
                      ),
                    )
                    .toList(),
                decoration: _inputDecoration(
                  label: 'Common blood test',
                  icon: Icons.biotech_outlined,
                ),
                onChanged: (value) {
                  final nextTest =
                      catalog.firstWhere((test) => test.id == value);
                  setState(() {
                    _selectedTestId = value;
                    _selectedUnit = nextTest.defaultUnit;
                    _useLabRange = false;
                    _lowController.clear();
                    _highController.clear();
                  });
                },
                validator: (value) =>
                    value == null ? 'Select the blood test first.' : null,
              ),
              if (selectedTest != null) ...[
                SizedBox(height: spacing.s),
                _DefinitionSummary(test: selectedTest),
              ],
              SizedBox(height: spacing.m),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _valueController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _inputDecoration(
                        label: 'Result value',
                        icon: Icons.show_chart_rounded,
                      ),
                      validator: (value) {
                        final parsed = double.tryParse(value?.trim() ?? '');
                        if (parsed == null) {
                          return 'Enter a numeric result value.';
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  SizedBox(width: spacing.s),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedUnit,
                      items: (selectedTest?.supportedUnits ?? const <String>[])
                          .map(
                            (unit) => DropdownMenuItem<String>(
                              value: unit,
                              child: Text(unit),
                            ),
                          )
                          .toList(),
                      decoration: _inputDecoration(
                        label: 'Unit',
                        icon: Icons.straighten_rounded,
                      ),
                      onChanged: selectedTest == null
                          ? null
                          : (value) => setState(() => _selectedUnit = value),
                      validator: (value) =>
                          value == null ? 'Unit required.' : null,
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacing.m),
              _DateField(
                label: 'Collection date',
                date: _collectedAt,
                onTap: _pickCollectedAt,
              ),
              SizedBox(height: spacing.m),
              TextFormField(
                controller: _sourceLabController,
                decoration: _inputDecoration(
                  label: 'Source lab (optional)',
                  icon: Icons.apartment_rounded,
                ),
              ),
              SizedBox(height: spacing.l),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Reference range',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                    ),
                  ),
                  Switch.adaptive(
                    value: _useLabRange,
                    activeThumbColor: AppColors.primary,
                    onChanged: (value) => setState(() => _useLabRange = value),
                  ),
                ],
              ),
              Text(
                _useLabRange
                    ? 'Enter the low and/or high numbers exactly as shown on the report.'
                    : 'If the report includes a range, turn this on and enter it. Otherwise the app will use a curated general fallback when one exists.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              SizedBox(height: spacing.m),
              if (_useLabRange)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _lowController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _inputDecoration(
                          label: 'Low',
                          icon: Icons.arrow_downward_rounded,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    SizedBox(width: spacing.s),
                    Expanded(
                      child: TextFormField(
                        controller: _highController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _inputDecoration(
                          label: 'High',
                          icon: Icons.arrow_upward_rounded,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                )
              else if (previewRange != null)
                _RangePreviewCard(
                  title: previewRange.label,
                  detail: previewRange.shortLabel,
                  note: previewRange.note,
                  accent: AppColors.primary,
                )
              else if (selectedTest != null)
                _RangePreviewCard(
                  title: 'Lab range required',
                  detail: 'No built-in fallback for ${selectedTest.name}',
                  note: selectedTest.note,
                  accent: AppColors.warning,
                ),
              SizedBox(height: spacing.l),
              TextFormField(
                controller: _noteController,
                maxLines: 3,
                decoration: _inputDecoration(
                  label: 'Notes (optional)',
                  icon: Icons.note_alt_outlined,
                ),
              ),
              SizedBox(height: spacing.l),
              if (selectedTest != null && previewResult != null)
                _InterpretationPreview(
                  result: previewResult,
                  test: selectedTest,
                ),
            ],
          ),
        ),
      ),
    );
  }

  LabTestDefinition? _selectedTest(List<LabTestDefinition> catalog) {
    if (_selectedTestId == null) return null;
    for (final test in catalog) {
      if (test.id == _selectedTestId) {
        return test;
      }
    }
    return null;
  }

  LabReferenceRange? _previewRange(LabTestDefinition? test) {
    if (test == null || _selectedUnit == null || _useLabRange) return null;
    return test.rangeForUnit(_selectedUnit!);
  }

  LabResult? _buildPreviewResult(LabTestDefinition? test) {
    final value = double.tryParse(_valueController.text.trim());
    if (test == null || value == null || _selectedUnit == null) {
      return null;
    }

    final low = double.tryParse(_lowController.text.trim());
    final high = double.tryParse(_highController.text.trim());

    return LabResult(
      id: 'preview',
      testId: test.id,
      testName: test.name,
      loincCode: test.loincCode,
      value: value,
      unit: _selectedUnit!,
      collectedAt: _collectedAt,
      source: LabResultSource.manual,
      reviewStatus: LabReviewStatus.confirmed,
      labReferenceRange: _useLabRange && (low != null || high != null)
          ? LabReferenceRange(
              low: low,
              high: high,
              unit: _selectedUnit!,
              source: LabRangeSource.labProvided,
              label: 'Lab provided reference',
            )
          : null,
    );
  }

  Future<void> _pickCollectedAt() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _collectedAt,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() => _collectedAt = picked);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final catalog = ref.read(labTestCatalogProvider);
    final selectedTest = _selectedTest(catalog);
    if (selectedTest == null || _selectedUnit == null) {
      return;
    }

    final value = double.parse(_valueController.text.trim());
    final low = double.tryParse(_lowController.text.trim());
    final high = double.tryParse(_highController.text.trim());
    if (_useLabRange && low == null && high == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Enter a low or high range value, or turn off lab range.'),
        ),
      );
      return;
    }

    final result = LabResult(
      id: const Uuid().v4(),
      testId: selectedTest.id,
      testName: selectedTest.name,
      loincCode: selectedTest.loincCode,
      value: value,
      unit: _selectedUnit!,
      collectedAt: _collectedAt,
      sourceLab: _trimmedOrNull(_sourceLabController.text),
      note: _trimmedOrNull(_noteController.text),
      source: LabResultSource.manual,
      reviewStatus: LabReviewStatus.confirmed,
      labReferenceRange: _useLabRange
          ? LabReferenceRange(
              low: low,
              high: high,
              unit: _selectedUnit!,
              source: LabRangeSource.labProvided,
              label: 'Lab provided reference',
            )
          : null,
    );

    ref.read(labResultsProvider.notifier).add(result);
    Navigator.of(context).pop();
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: AppColors.outline.withValues(alpha: 0.8),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: AppColors.primary,
          width: 1.3,
        ),
      ),
    );
  }

  String? _trimmedOrNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primaryDark),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DefinitionSummary extends StatelessWidget {
  const _DefinitionSummary({required this.test});

  final LabTestDefinition test;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            test.name,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '${test.category} | LOINC ${test.loincCode}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            test.summary,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          if (test.note != null) ...[
            const SizedBox(height: 8),
            Text(
              test.note!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.outline.withValues(alpha: 0.8)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              color: AppColors.textSecondary,
            ),
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
                  const SizedBox(height: 3),
                  Text(
                    DateFormat('MMM d, y').format(date),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                  ),
                ],
              ),
            ),
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

class _RangePreviewCard extends StatelessWidget {
  const _RangePreviewCard({
    required this.title,
    required this.detail,
    required this.note,
    required this.accent,
  });

  final String title;
  final String detail;
  final String? note;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          if (note != null) ...[
            const SizedBox(height: 8),
            Text(
              note!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InterpretationPreview extends StatelessWidget {
  const _InterpretationPreview({
    required this.result,
    required this.test,
  });

  final LabResult result;
  final LabTestDefinition test;

  @override
  Widget build(BuildContext context) {
    final interpretation = result.interpretation(test);
    final style = _interpretationStyle(interpretation);
    final range = result.effectiveReferenceRange(test);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: style.background,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  style.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: style.foreground,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              const Spacer(),
              Text(
                '${result.formattedValue} ${result.unit}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
              ),
            ],
          ),
          if (range != null) ...[
            const SizedBox(height: 10),
            Text(
              '${range.label}: ${range.shortLabel}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

({Color background, Color foreground, String label}) _interpretationStyle(
  LabResultInterpretation interpretation,
) {
  switch (interpretation) {
    case LabResultInterpretation.low:
      return (
        background: AppColors.warningContainer,
        foreground: AppColors.warning,
        label: 'Low',
      );
    case LabResultInterpretation.inRange:
      return (
        background: AppColors.successContainer,
        foreground: AppColors.success,
        label: 'In range',
      );
    case LabResultInterpretation.high:
      return (
        background: AppColors.errorContainer,
        foreground: AppColors.error,
        label: 'High',
      );
    case LabResultInterpretation.reviewRequired:
      return (
        background: AppColors.primaryContainer,
        foreground: AppColors.primaryDark,
        label: 'Review first',
      );
    case LabResultInterpretation.noRange:
      return (
        background: AppColors.secondaryContainer,
        foreground: AppColors.secondaryDark,
        label: 'Needs range',
      );
  }
}
