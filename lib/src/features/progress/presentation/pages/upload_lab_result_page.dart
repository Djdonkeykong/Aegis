import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../domain/models/lab_result.dart';
import '../../domain/providers/lab_results_providers.dart';

class UploadLabResultPage extends ConsumerWidget {
  const UploadLabResultPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final draft = ref.watch(labAiDraftPreviewProvider);
    final dateLabel = DateFormat('MMM d, y | HH:mm').format(draft.createdAt);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Upload Result'),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            spacing.m,
            spacing.s,
            spacing.m,
            spacing.xl,
          ),
          children: [
            _Panel(
              background: const Color(0xFFE6F6FB),
              borderColor: AppColors.primary.withValues(alpha: 0.18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.cloud_upload_outlined,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'AI upload scaffold',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'This release keeps uploads review-first. The app is ready for a screenshot or PDF to be sent from your backend to an AI parser, then brought back as a draft the user must confirm before saving.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            SizedBox(height: spacing.m),
            const _SafetyCard(
              title: 'Safety rules baked in',
              items: [
                'Uploads should stay server-side instead of going directly from the client to the model.',
                'AI drafts must stay marked as review required until the user confirms each result.',
                'Only use reference ranges shown on the report. Do not invent missing ranges.',
                'If the report does not include a range, save without one and let the manual editor fill it in later.',
                'OpenAI notes that file and image inputs can be deleted or expire, and are also scanned for CSAM with possible retention for manual review in those cases.',
              ],
            ),
            SizedBox(height: spacing.m),
            Text(
              'Recommended flow',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
            ),
            SizedBox(height: spacing.s),
            const _FlowStep(
              number: '1',
              title: 'Secure upload',
              description:
                  'Accept a screenshot or PDF in the app, then hand it off to your backend for storage and parsing.',
            ),
            const _FlowStep(
              number: '2',
              title: 'Structured extraction',
              description:
                  'Call the AI with file input plus a strict JSON schema so each test, value, unit, and lab range comes back in a fixed shape.',
            ),
            const _FlowStep(
              number: '3',
              title: 'Human review',
              description:
                  'Show every extracted result as a draft with review badges before anything is written into the user record.',
            ),
            const _FlowStep(
              number: '4',
              title: 'Save confirmed entries',
              description:
                  'Only confirmed rows become real lab results. Unconfirmed rows stay editable or can be discarded.',
            ),
            SizedBox(height: spacing.l),
            Text(
              'Draft review preview',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
            ),
            SizedBox(height: spacing.s),
            _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    draft.fileName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${draft.sourceLab ?? 'Unknown lab'} | $dateLabel',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 16),
                  for (final entry in draft.entries) ...[
                    _DraftEntryTile(entry: entry),
                    if (entry != draft.entries.last) const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            SizedBox(height: spacing.l),
            Text(
              'Backend contract checklist',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
            ),
            SizedBox(height: spacing.s),
            const _SafetyCard(
              title: 'Expected structured fields',
              items: [
                'raw test name from the report',
                'matched common-test id when the match is confident',
                'numeric value and unit',
                'reference low and high exactly as shown on the report',
                'raw reference text for auditability',
                'abnormal flag when present on the report',
                'confidence score and review_required = true',
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.background = AppColors.surface,
    this.borderColor,
  });

  final Widget child;
  final Color background;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: borderColor ?? AppColors.outline.withValues(alpha: 0.85),
        ),
      ),
      child: child,
    );
  }
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard({
    required this.title,
    required this.items,
  });

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      background: AppColors.surface,
      borderColor: AppColors.warning.withValues(alpha: 0.18),
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
          const SizedBox(height: 12),
          for (final item in items) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 7),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ),
              ],
            ),
            if (item != items.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _FlowStep extends StatelessWidget {
  const _FlowStep({
    required this.number,
    required this.title,
    required this.description,
  });

  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
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
          ),
        ],
      ),
    );
  }
}

class _DraftEntryTile extends StatelessWidget {
  const _DraftEntryTile({required this.entry});

  final LabAiDraftEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.rawTestName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Review required',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${entry.value} ${entry.unit}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
          ),
          if (entry.rawReferenceText != null) ...[
            const SizedBox(height: 4),
            Text(
              'Report range: ${entry.rawReferenceText}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
          if (entry.confidence != null) ...[
            const SizedBox(height: 4),
            Text(
              'Confidence: ${(entry.confidence! * 100).round()}%',
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
