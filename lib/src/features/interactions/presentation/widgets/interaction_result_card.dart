import 'package:flutter/material.dart';
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
                    '${result.drug1}  <->  ${result.drug2}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.s),
            SeverityBadge(severity: result.severity),
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

  const SingleDrugResultCard({super.key, required this.result});

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
              result.drug,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
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
