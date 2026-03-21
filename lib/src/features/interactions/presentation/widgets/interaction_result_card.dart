import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../domain/models/interaction_result.dart';
import 'severity_badge.dart';

class InteractionResultCard extends StatelessWidget {
  final InteractionResult result;

  const InteractionResultCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(spacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${result.displayDrug1}  <->  ${result.displayDrug2}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.s),
            SeverityBadge(severity: result.severity),
            if ((result.recognizedDrug1 != null || result.recognizedDrug2 != null) &&
                ((result.recognizedDisplayDrug1 ?? result.displayDrug1)
                            .toLowerCase() !=
                        result.displayDrug1.toLowerCase() ||
                    (result.recognizedDisplayDrug2 ?? result.displayDrug2)
                            .toLowerCase() !=
                        result.displayDrug2.toLowerCase()))
              Padding(
                padding: EdgeInsets.only(top: spacing.s),
                child: Text(
                  'Matched as: ${result.recognizedDisplayDrug1 ?? result.displayDrug1} and ${result.recognizedDisplayDrug2 ?? result.displayDrug2}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (result.hasUnmatchedInputs)
              Padding(
                padding: EdgeInsets.only(top: spacing.s),
                child: Text(
                  'Unrecognized input: ${result.unmatchedInputs.join(', ')}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
              ),
            SizedBox(height: spacing.m),
            Text(
              result.summary,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class SingleDrugResultCard extends StatelessWidget {
  final SingleDrugResult result;
  final ValueChanged<String>? onInteractionTap;
  final Set<SeverityLevel> expandedSections;
  final void Function(SeverityLevel severity, bool expanded)?
      onSectionExpansionChanged;

  const SingleDrugResultCard({
    super.key,
    required this.result,
    this.onInteractionTap,
    required this.expandedSections,
    this.onSectionExpansionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(spacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.displayDrug,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (result.recognizedDrug != null &&
                (result.recognizedDisplayDrug ?? result.displayDrug)
                        .toLowerCase() !=
                    result.displayDrug.toLowerCase())
              Padding(
                padding: EdgeInsets.only(top: spacing.s),
                child: Text(
                  'Matched as: ${result.recognizedDisplayDrug ?? result.displayDrug}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (result.hasUnmatchedInputs)
              Padding(
                padding: EdgeInsets.only(top: spacing.s),
                child: Text(
                  'Unrecognized input: ${result.unmatchedInputs.join(', ')}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
              ),
            SizedBox(height: spacing.m),
            Text(
              result.summary,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                  ),
            ),
            if (result.hasInteractionItems) ...[
              SizedBox(height: spacing.l),
              Text(
                'Most frequent interactions',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              SizedBox(height: spacing.xs),
              Text(
                'View interaction reports for ${result.displayDrug} and the medicines listed below.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              SizedBox(height: spacing.m),
              Wrap(
                spacing: spacing.m,
                runSpacing: spacing.s,
                children: const [
                  _SeverityLegendItem(
                    label: 'Major',
                    color: AppColors.severityHigh,
                  ),
                  _SeverityLegendItem(
                    label: 'Moderate',
                    color: AppColors.severityModerate,
                  ),
                  _SeverityLegendItem(
                    label: 'Minor',
                    color: AppColors.severityLow,
                  ),
                ],
              ),
              SizedBox(height: spacing.m),
              ..._buildSeveritySections(
                result,
                onInteractionTap,
                expandedSections,
                onSectionExpansionChanged,
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSeveritySections(
    SingleDrugResult result,
    ValueChanged<String>? onInteractionTap,
    Set<SeverityLevel> expandedSections,
    void Function(SeverityLevel severity, bool expanded)?
        onSectionExpansionChanged,
  ) {
    final sections = <Widget>[];
    final groupedItems = <SeverityLevel, List<SingleDrugInteractionItem>>{
      SeverityLevel.high: [],
      SeverityLevel.moderate: [],
      SeverityLevel.low: [],
    };

    for (final item in result.interactionItems) {
      if (groupedItems.containsKey(item.severity)) {
        groupedItems[item.severity]!.add(item);
      }
    }

    for (final severity in const [
      SeverityLevel.high,
      SeverityLevel.moderate,
      SeverityLevel.low,
    ]) {
      final items = groupedItems[severity]!;
      if (items.isEmpty) continue;
      sections.add(
        _SeveritySection(
          title: _sectionTitle(severity),
          severity: severity,
          items: items,
          expanded: expandedSections.contains(severity),
          onInteractionTap: onInteractionTap,
          onExpansionChanged: onSectionExpansionChanged,
        ),
      );
      sections.add(const SizedBox(height: 10));
    }

    if (sections.isNotEmpty) {
      sections.removeLast();
    }

    return sections;
  }

  String _sectionTitle(SeverityLevel severity) {
    switch (severity) {
      case SeverityLevel.high:
        return 'Major';
      case SeverityLevel.moderate:
        return 'Moderate';
      case SeverityLevel.low:
        return 'Minor';
      case SeverityLevel.unknown:
        return 'Unknown';
    }
  }
}

class _SeverityLegendItem extends StatelessWidget {
  final String label;
  final Color color;

  const _SeverityLegendItem({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }
}

class _SingleDrugInteractionRow extends StatelessWidget {
  final SingleDrugInteractionItem item;
  final VoidCallback? onTap;

  const _SingleDrugInteractionRow({
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _severityColor(item.severity),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.drugName,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.primaryDark,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _severityColor(SeverityLevel severity) {
    switch (severity) {
      case SeverityLevel.high:
        return AppColors.severityHigh;
      case SeverityLevel.moderate:
        return AppColors.severityModerate;
      case SeverityLevel.low:
        return AppColors.severityLow;
      case SeverityLevel.unknown:
        return AppColors.severityUnknown;
    }
  }
}

class _SeveritySection extends StatelessWidget {
  final String title;
  final SeverityLevel severity;
  final List<SingleDrugInteractionItem> items;
  final bool expanded;
  final ValueChanged<String>? onInteractionTap;
  final void Function(SeverityLevel severity, bool expanded)? onExpansionChanged;

  const _SeveritySection({
    required this.title,
    required this.severity,
    required this.items,
    required this.expanded,
    this.onInteractionTap,
    this.onExpansionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _sectionColor(severity).withValues(alpha: 0.25),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          key: PageStorageKey('severity-section-${severity.name}'),
          initiallyExpanded: expanded,
          onExpansionChanged: (expanded) {
            onExpansionChanged?.call(severity, expanded);
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _sectionColor(severity),
              shape: BoxShape.circle,
            ),
          ),
          title: Text(
            '$title (${items.length})',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          children: [
            for (final item in items) ...[
              _SingleDrugInteractionRow(
                item: item,
                onTap: onInteractionTap == null
                    ? null
                    : () => onInteractionTap!(item.drugName),
              ),
              if (item != items.last) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  Color _sectionColor(SeverityLevel severity) {
    switch (severity) {
      case SeverityLevel.high:
        return AppColors.severityHigh;
      case SeverityLevel.moderate:
        return AppColors.severityModerate;
      case SeverityLevel.low:
        return AppColors.severityLow;
      case SeverityLevel.unknown:
        return AppColors.severityUnknown;
    }
  }
}
