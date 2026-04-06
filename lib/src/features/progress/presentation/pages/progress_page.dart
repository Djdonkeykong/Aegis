import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../domain/models/lab_result.dart';
import '../../domain/models/lab_test_definition.dart';
import '../../domain/providers/lab_results_providers.dart';
import 'add_lab_result_page.dart';
import 'upload_lab_result_page.dart';

class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LabResultsPage();
  }
}

class LabResultsPage extends ConsumerWidget {
  const LabResultsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final results = ref.watch(labResultsProvider);
    final testsById = ref.watch(labTestMapProvider);
    final pendingReviewCount = results
        .where(
            (result) => result.reviewStatus == LabReviewStatus.reviewRequired)
        .length;
    final outOfRangeCount = results.where((result) {
      final interpretation = result.interpretation(testsById[result.testId]);
      return interpretation == LabResultInterpretation.low ||
          interpretation == LabResultInterpretation.high;
    }).length;
    final trendGroups = _buildTrendGroups(results, testsById);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lab Results'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openManualEntry(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                spacing.m,
                spacing.s,
                spacing.m,
                spacing.xl,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  [
                    const _SafetyHeaderCard(),
                    SizedBox(height: spacing.m),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            label: 'Manual Entry',
                            icon: Icons.edit_note_rounded,
                            filled: true,
                            onTap: () => _openManualEntry(context),
                          ),
                        ),
                        SizedBox(width: spacing.s),
                        Expanded(
                          child: _ActionButton(
                            label: 'Upload Result',
                            icon: Icons.upload_file_rounded,
                            filled: false,
                            onTap: () => _openUploadFlow(context),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: spacing.m),
                    Row(
                      children: [
                        Expanded(
                          child: _OverviewTile(
                            label: 'Saved',
                            value: '${results.length}',
                            accent: AppColors.primary,
                          ),
                        ),
                        SizedBox(width: spacing.s),
                        Expanded(
                          child: _OverviewTile(
                            label: 'Review',
                            value: '$pendingReviewCount',
                            accent: AppColors.warning,
                          ),
                        ),
                        SizedBox(width: spacing.s),
                        Expanded(
                          child: _OverviewTile(
                            label: 'Out of range',
                            value: '$outOfRangeCount',
                            accent: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: spacing.l),
                    if (results.isEmpty)
                      _EmptyLabState(
                        onManualEntry: () => _openManualEntry(context),
                        onUploadFlow: () => _openUploadFlow(context),
                      )
                    else ...[
                      if (trendGroups.isNotEmpty) ...[
                        const _SectionTitle(
                          title: 'Trends',
                          subtitle:
                              'Charts appear once the same test has 2 or more saved results.',
                        ),
                        SizedBox(height: spacing.s),
                        SizedBox(
                          height: 160,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: trendGroups.length,
                            separatorBuilder: (_, __) =>
                                SizedBox(width: spacing.s),
                            itemBuilder: (context, index) {
                              return _TrendCard(group: trendGroups[index]);
                            },
                          ),
                        ),
                        SizedBox(height: spacing.l),
                      ],
                      const _SectionTitle(
                        title: 'Recent results',
                        subtitle:
                            'Lab-provided ranges take priority. General fallbacks are clearly labeled.',
                      ),
                      SizedBox(height: spacing.s),
                      ...results.map(
                        (result) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _LabResultCard(result: result),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openManualEntry(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AddLabResultPage(),
      ),
    );
  }

  void _openUploadFlow(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const UploadLabResultPage(),
      ),
    );
  }
}

class _SafetyHeaderCard extends StatelessWidget {
  const _SafetyHeaderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFF7FDFF),
            Color(0xFFEAF8FC),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.monitor_heart_outlined,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Track blood work with safer defaults',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manual entry is live today. AI upload is scaffolded so screenshots and PDFs come back as review-first drafts instead of being auto-saved.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniTag(label: 'LOINC-aware'),
              _MiniTag(label: 'Unit-aware'),
              _MiniTag(label: 'Review before save'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.outline),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = filled ? AppColors.primary : Colors.white;
    final foreground = filled ? Colors.white : AppColors.textPrimary;

    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: background,
          foregroundColor: foreground,
          side: BorderSide(
            color: filled ? Colors.transparent : AppColors.outline,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class _OverviewTile extends StatelessWidget {
  const _OverviewTile({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 4,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }
}

class _EmptyLabState extends ConsumerWidget {
  const _EmptyLabState({
    required this.onManualEntry,
    required this.onUploadFlow,
  });

  final VoidCallback onManualEntry;
  final VoidCallback onUploadFlow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final tests = ref.watch(labTestCatalogProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.query_stats_rounded,
              color: AppColors.primaryDark,
              size: 34,
            ),
          ),
          SizedBox(height: spacing.m),
          Text(
            'No lab results saved yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: spacing.s),
          Text(
            'Start with manual entry, then layer in screenshot or PDF uploads once your backend is ready to parse them into review-first drafts.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: spacing.l),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Manual Entry',
                  icon: Icons.edit_note_rounded,
                  filled: true,
                  onTap: onManualEntry,
                ),
              ),
              SizedBox(width: spacing.s),
              Expanded(
                child: _ActionButton(
                  label: 'Upload Result',
                  icon: Icons.upload_file_rounded,
                  filled: false,
                  onTap: onUploadFlow,
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.l),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Common tests supported',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
            ),
          ),
          SizedBox(height: spacing.s),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tests
                .take(8)
                .map((test) => _MiniTag(label: test.name))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _LabResultCard extends ConsumerWidget {
  const _LabResultCard({required this.result});

  final LabResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final test = ref.watch(labTestMapProvider)[result.testId];
    final interpretation = result.interpretation(test);
    final style = _interpretationStyle(interpretation);
    final effectiveRange = result.effectiveReferenceRange(test);
    final dateLabel = DateFormat('MMM d, y').format(result.collectedAt);
    final sourceLabel = result.sourceLab?.trim();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.biotech_outlined,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.testName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'LOINC ${result.loincCode}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${result.formattedValue} ${result.unit}',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () =>
                    ref.read(labResultsProvider.notifier).remove(result.id),
                icon: const Icon(Icons.delete_outline_rounded),
                color: AppColors.textSecondary,
                tooltip: 'Delete result',
              ),
            ],
          ),
          if (effectiveRange != null) ...[
            const SizedBox(height: 14),
            _InfoRow(
              label: effectiveRange.label,
              value: effectiveRange.shortLabel,
            ),
            if (effectiveRange.note != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  effectiveRange.note!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ),
          ] else ...[
            const SizedBox(height: 14),
            const _InfoRow(
              label: 'Reference range',
              value: 'Needs lab-provided range',
            ),
          ],
          if (sourceLabel != null && sourceLabel.isNotEmpty) ...[
            const SizedBox(height: 10),
            _InfoRow(
              label: 'Source lab',
              value: sourceLabel,
            ),
          ],
          if (result.note != null && result.note!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _InfoRow(
              label: 'Notes',
              value: result.note!.trim(),
            ),
          ],
          if (result.reviewStatus == LabReviewStatus.reviewRequired) ...[
            const SizedBox(height: 10),
            const _InfoRow(
              label: 'Review',
              value:
                  'This AI-extracted result still needs confirmation before it should be trusted.',
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}

class _TrendGroup {
  const _TrendGroup({
    required this.test,
    required this.results,
  });

  final LabTestDefinition test;
  final List<LabResult> results;
}

List<_TrendGroup> _buildTrendGroups(
  List<LabResult> results,
  Map<String, LabTestDefinition> testsById,
) {
  final grouped = <String, List<LabResult>>{};

  for (final result in results) {
    final key = '${result.testId}|${result.unit}';
    grouped.putIfAbsent(key, () => []).add(result);
  }

  final groups = <_TrendGroup>[];
  for (final entry in grouped.entries) {
    final sorted = [...entry.value]
      ..sort((a, b) => a.collectedAt.compareTo(b.collectedAt));
    if (sorted.length < 2) continue;
    final test = testsById[sorted.first.testId];
    if (test == null) continue;
    groups.add(_TrendGroup(test: test, results: sorted));
  }

  groups.sort(
    (a, b) => b.results.last.collectedAt.compareTo(a.results.last.collectedAt),
  );

  return groups;
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.group});

  final _TrendGroup group;

  @override
  Widget build(BuildContext context) {
    final latest = group.results.last;
    final previous = group.results[group.results.length - 2];
    final delta = latest.value - previous.value;
    final deltaPrefix = delta > 0 ? '+' : '';

    return Container(
      width: 220,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.test.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '${group.results.length} results | ${latest.unit}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: CustomPaint(
              painter: _SparklinePainter(
                values: group.results.map((result) => result.value).toList(),
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${latest.formattedValue} ${latest.unit}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '$deltaPrefix${delta.toStringAsFixed(delta.abs() >= 10 ? 0 : 1)} since previous',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values});

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final backgroundPaint = Paint()
      ..color = AppColors.primaryContainer.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = AppColors.primaryDark
      ..style = PaintingStyle.fill;

    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range = maxValue - minValue;

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : i * size.width / (values.length - 1);
      final normalized = range == 0 ? 0.5 : (values[i] - minValue) / range;
      final y = size.height - (normalized * (size.height - 12)) - 6;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(18),
      ),
      backgroundPaint,
    );
    canvas.drawPath(path, linePaint);

    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : i * size.width / (values.length - 1);
      final normalized = range == 0 ? 0.5 : (values[i] - minValue) / range;
      final y = size.height - (normalized * (size.height - 12)) - 6;
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.values != values;
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
