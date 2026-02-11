import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../medications/domain/providers/medication_providers.dart';

class RemindersPage extends ConsumerWidget {
  const RemindersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medications = ref.watch(medicationListProvider);
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
      ),
      body: medications.isEmpty
          ? Center(
              child: Padding(
                padding: EdgeInsets.all(spacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.alarm_off,
                      size: 64,
                      color: AppColors.textTertiary,
                    ),
                    SizedBox(height: spacing.m),
                    Text(
                      'No reminders yet',
                      style: textTheme.titleMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: spacing.s),
                    Text(
                      'Add medications first to set up reminders',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                      textAlign: TextAlign.center,
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
                return Card(
                  margin: EdgeInsets.only(bottom: spacing.s),
                  child: ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.alarm,
                        color: AppColors.primary,
                      ),
                    ),
                    title: Text(med.name),
                    subtitle: Text(
                      med.frequency ?? 'No schedule set',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: Switch(
                      value: med.remindersEnabled,
                      activeTrackColor: AppColors.primaryContainer,
                      activeThumbColor: AppColors.primary,
                      onChanged: (value) {
                        ref
                            .read(medicationListProvider.notifier)
                            .update(med.copyWith(remindersEnabled: value));
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
