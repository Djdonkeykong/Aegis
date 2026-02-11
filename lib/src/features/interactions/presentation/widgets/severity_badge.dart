import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../domain/models/interaction_result.dart';

class SeverityBadge extends StatelessWidget {
  final SeverityLevel severity;

  const SeverityBadge({super.key, required this.severity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _label,
            style: TextStyle(
              color: _textColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String get _label {
    switch (severity) {
      case SeverityLevel.high:
        return 'High Risk';
      case SeverityLevel.moderate:
        return 'Moderate Risk';
      case SeverityLevel.low:
        return 'Low Risk';
      case SeverityLevel.unknown:
        return 'Unknown';
    }
  }

  Color get _dotColor {
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

  Color get _backgroundColor {
    switch (severity) {
      case SeverityLevel.high:
        return AppColors.severityHighContainer;
      case SeverityLevel.moderate:
        return AppColors.severityModerateContainer;
      case SeverityLevel.low:
        return AppColors.severityLowContainer;
      case SeverityLevel.unknown:
        return AppColors.severityUnknownContainer;
    }
  }

  Color get _textColor {
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
