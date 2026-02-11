import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../domain/models/medication.dart';
import '../../domain/providers/medication_providers.dart';
import 'add_medication_page.dart';

class MedicationsPage extends ConsumerWidget {
  const MedicationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medications = ref.watch(medicationListProvider);
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Medications'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AddMedicationPage(),
            ),
          );
        },
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        child: const Icon(Icons.add),
      ),
      body: medications.isEmpty
          ? Center(
              child: Padding(
                padding: EdgeInsets.all(spacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.medication_liquid_outlined,
                      size: 64,
                      color: AppColors.textTertiary,
                    ),
                    SizedBox(height: spacing.m),
                    Text(
                      'No medications yet',
                      style: textTheme.titleMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: spacing.s),
                    Text(
                      'Tap + to add your first medication',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(spacing.m),
              itemCount: medications.length,
              itemBuilder: (context, index) {
                final med = medications[index];
                return _MedicationCard(medication: med);
              },
            ),
    );
  }
}

class _MedicationCard extends ConsumerWidget {
  final Medication medication;

  const _MedicationCard({required this.medication});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;

    return Card(
      margin: EdgeInsets.only(bottom: spacing.s),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: spacing.m,
          vertical: spacing.s,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.medication,
            color: AppColors.primary,
          ),
        ),
        title: Text(
          medication.name,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        subtitle: medication.dosage != null
            ? Text(
                '${medication.dosage} - ${medication.frequency ?? 'As needed'}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              )
            : null,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.textTertiary),
          onPressed: () {
            ref.read(medicationListProvider.notifier).remove(medication.id);
          },
        ),
      ),
    );
  }
}
