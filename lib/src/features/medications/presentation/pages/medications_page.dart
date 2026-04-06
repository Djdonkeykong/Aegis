import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../domain/models/medication.dart';
import '../../domain/providers/medication_providers.dart';
import 'add_medication_page.dart';

enum _MedicationFilter { active, completed }

class MedicationsPage extends ConsumerStatefulWidget {
  const MedicationsPage({super.key});

  @override
  ConsumerState<MedicationsPage> createState() => _MedicationsPageState();
}

class _MedicationsPageState extends ConsumerState<MedicationsPage> {
  _MedicationFilter _filter = _MedicationFilter.active;

  @override
  Widget build(BuildContext context) {
    final medications = ref.watch(medicationListProvider);
    final log = ref.watch(medicationLogProvider);
    final aliases = ref.watch(medicationAliasesProvider).valueOrNull ??
        const <String, List<String>>{};
    final spacing = context.spacing;
    final today = DateTime.now();
    final filtered = _filteredMedications(medications, today);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Medications'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddMedication,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        child: const Icon(Icons.add),
      ),
      body: medications.isEmpty
          ? _EmptyMedicationsState(onTap: _openAddMedication)
          : Padding(
              padding: EdgeInsets.fromLTRB(
                spacing.m,
                spacing.s,
                spacing.m,
                spacing.m,
              ),
              child: Column(
                children: [
                  _MedicationFilterToggle(
                    filter: _filter,
                    onChanged: (value) => setState(() => _filter = value),
                  ),
                  SizedBox(height: spacing.l),
                  Expanded(
                    child: filtered.isEmpty
                        ? _FilteredMedicationsState(filter: _filter)
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final crossAxisCount = constraints.maxWidth < 380
                                  ? 1
                                  : constraints.maxWidth < 760
                                      ? 2
                                      : 3;

                              return GridView.builder(
                                itemCount: filtered.length,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: spacing.m,
                                  mainAxisSpacing: spacing.m,
                                  mainAxisExtent: 256,
                                ),
                                itemBuilder: (context, index) {
                                  final medication = filtered[index];
                                  return _MedicationCard(
                                    medication: medication,
                                    aliases: aliases,
                                    takenCount: _takenCountForMedication(
                                      log,
                                      medication,
                                    ),
                                    onEdit: () =>
                                        _openEditMedication(medication),
                                    onDelete: () => ref
                                        .read(medicationListProvider.notifier)
                                        .remove(medication.id),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  List<Medication> _filteredMedications(
    List<Medication> medications,
    DateTime now,
  ) {
    final filtered = medications.where((medication) {
      final isCompleted = medication.isCompletedOn(now);
      return _filter == _MedicationFilter.active ? !isCompleted : isCompleted;
    }).toList();

    filtered.sort((a, b) {
      final aEnd = a.treatmentEndDate ?? DateTime(9999);
      final bEnd = b.treatmentEndDate ?? DateTime(9999);

      if (_filter == _MedicationFilter.completed) {
        return bEnd.compareTo(aEnd);
      }

      final compareEnd = aEnd.compareTo(bEnd);
      if (compareEnd != 0) return compareEnd;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return filtered;
  }

  int _takenCountForMedication(
    Map<String, Map<String, MedicationDoseStatus>> log,
    Medication medication,
  ) {
    final prefix = '${medication.id}|';
    var count = 0;

    for (final dayMap in log.values) {
      for (final entry in dayMap.entries) {
        if (entry.key.startsWith(prefix) &&
            entry.value == MedicationDoseStatus.taken) {
          count++;
        }
      }
    }

    return count;
  }

  void _openAddMedication() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AddMedicationPage(),
      ),
    );
  }

  void _openEditMedication(Medication medication) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddMedicationPage(existing: medication),
      ),
    );
  }
}

class _MedicationFilterToggle extends StatelessWidget {
  const _MedicationFilterToggle({
    required this.filter,
    required this.onChanged,
  });

  final _MedicationFilter filter;
  final ValueChanged<_MedicationFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: _FilterButton(
              label: 'Active',
              selected: filter == _MedicationFilter.active,
              onTap: () => onChanged(_MedicationFilter.active),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _FilterButton(
              label: 'Completed',
              selected: filter == _MedicationFilter.completed,
              onTap: () => onChanged(_MedicationFilter.completed),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.24),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : const [],
        ),
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
          ),
        ),
      ),
    );
  }
}

class _MedicationCard extends StatelessWidget {
  const _MedicationCard({
    required this.medication,
    required this.aliases,
    required this.takenCount,
    required this.onEdit,
    required this.onDelete,
  });

  final Medication medication;
  final Map<String, List<String>> aliases;
  final int takenCount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String get _displayName {
    final aliasList = aliases[medication.name.trim().toLowerCase()];
    if (aliasList == null || aliasList.isEmpty) return medication.name;
    return aliasList.first;
  }

  bool get _showsAlternateName =>
      _displayName.toLowerCase() != medication.name.toLowerCase();

  String _dateRangeLabel() {
    final formatter = DateFormat('MMM d');
    final start = formatter.format(medication.startDate);
    final end = medication.treatmentEndDate;
    if (end == null) {
      return 'Started $start';
    }
    return '$start - ${formatter.format(end)}';
  }

  String _daysValue(DateTime now) {
    final elapsed = medication.elapsedTreatmentDaysOn(now);
    final total = medication.treatmentDurationDays;
    if (total == null || total <= 0) {
      return '$elapsed';
    }
    return '$elapsed/$total';
  }

  String _quantityValue() {
    final total = medication.containerQuantity;
    if (total == null || total <= 0) {
      return '$takenCount';
    }
    return '$takenCount/$total';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final spacing = context.spacing;
    final secondaryLine = [
      if (medication.dosage != null && medication.dosage!.trim().isNotEmpty)
        medication.dosage!,
      medication.form.label,
    ].join(' | ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onEdit,
        child: Ink(
          padding: EdgeInsets.all(spacing.m),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      medication.form.iconData,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_horiz_rounded,
                      color: AppColors.textSecondary,
                    ),
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEdit();
                      } else if (value == 'delete') {
                        onDelete();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Text('Edit'),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: spacing.m),
              Text(
                _displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                    ),
              ),
              if (_showsAlternateName) ...[
                SizedBox(height: spacing.xs),
                Text(
                  medication.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
              if (secondaryLine.isNotEmpty) ...[
                SizedBox(height: spacing.xs),
                Text(
                  secondaryLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
              SizedBox(height: spacing.xs),
              Text(
                _dateRangeLabel(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              SizedBox(height: spacing.m),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.m,
                  vertical: spacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _MedicationMetric(
                        value: _daysValue(now),
                        label: 'days',
                      ),
                    ),
                    SizedBox(width: spacing.m),
                    Expanded(
                      child: _MedicationMetric(
                        value: _quantityValue(),
                        label: 'quantity',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MedicationMetric extends StatelessWidget {
  const _MedicationMetric({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMedicationsState extends StatelessWidget {
  const _EmptyMedicationsState({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.medication_outlined,
                size: 30,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: spacing.m),
            Text(
              'No medications yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            SizedBox(height: spacing.s),
            Text(
              'Add your first medication to start tracking treatment length, dose times, and supply.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            SizedBox(height: spacing.m),
            FilledButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.add),
              label: const Text('Add medication'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilteredMedicationsState extends StatelessWidget {
  const _FilteredMedicationsState({
    required this.filter,
  });

  final _MedicationFilter filter;

  @override
  Widget build(BuildContext context) {
    final message = filter == _MedicationFilter.active
        ? 'No active courses right now.'
        : 'No completed courses yet.';

    return Center(
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
