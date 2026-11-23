// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../services/classifier.dart';
import '../theme/app_theme.dart';

/// One row of the Result screen: label name, a bar, the percentage.
/// The top row ([emphasised]) gets a tinted background and bold text.
class PredictionRow extends StatelessWidget {
  const PredictionRow({
    super.key,
    required this.prediction,
    this.emphasised = false,
  });

  final Prediction prediction;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelStyle = emphasised
        ? theme.textTheme.titleMedium?.copyWith(
            color: scheme.onPrimaryContainer,
            fontWeight: FontWeight.w700,
          )
        : theme.textTheme.bodyLarge;
    final percentStyle = labelStyle?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: emphasised ? scheme.primaryContainer : null,
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              prediction.label,
              style: labelStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.small),
              child: LinearProgressIndicator(
                value: prediction.confidence.clamp(0.0, 1.0),
                minHeight: emphasised ? 10 : 8,
                color: emphasised ? scheme.primary : scheme.secondary,
                backgroundColor: emphasised
                    ? scheme.surfaceContainerLowest
                    : scheme.surfaceContainerHighest,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            width: 64,
            child: Text(
              prediction.percent,
              style: percentStyle,
              textAlign: TextAlign.end,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
