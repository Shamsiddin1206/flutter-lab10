// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../services/history.dart';
import '../theme/app_theme.dart';
import '../widgets/prediction_row.dart';
import '../widgets/source_badge.dart';

/// Screen 3. The same widget for camera, gallery and download.
/// Never runs the model: it only shows a finished [HistoryEntry].
class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.entry,
    required this.history,
    required this.labels,
  });

  final HistoryEntry entry;
  final HistoryStore history;
  final List<String> labels;

  static Route<void> route({
    required HistoryEntry entry,
    required HistoryStore history,
    required List<String> labels,
  }) => MaterialPageRoute(
    builder: (_) =>
        ResultScreen(entry: entry, history: history, labels: labels),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final maxImageHeight = MediaQuery.sizeOf(context).height * 0.45;
    final sum = entry.predictions.fold<double>(0, (s, p) => s + p.confidence);
    final timing = entry.timing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Result'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: Center(child: SourceBadge(source: entry.source)),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: [
            // 1. The image, centred, uncropped, at most ~half the screen.
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxImageHeight),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                  child: Image.memory(
                    entry.bytes,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Prediction', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            // 2 + 3. One row per label, highest first, top row emphasised.
            for (var i = 0; i < entry.predictions.length; i++) ...[
              PredictionRow(
                prediction: entry.predictions[i],
                emphasised: i == 0,
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            const SizedBox(height: AppSpacing.sm),
            // 4 + 5. Sum check, source, timing.
            Text(
              'Sum ${(sum * 100).toStringAsFixed(1)} %  ·  '
              'from ${entry.source.label.toLowerCase()}'
              '${timing == null ? '' : '  ·  pre-processing '
                        '${timing.preprocess.inMilliseconds} ms, inference '
                        '${timing.inference.inMilliseconds} ms'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const Divider(),
            const SizedBox(height: AppSpacing.lg),
            _EvaluationPicker(entry: entry, history: history, labels: labels),
          ],
        ),
      ),
    );
  }
}

/// For the evaluation table (T23): tap what the picture really shows.
class _EvaluationPicker extends StatelessWidget {
  const _EvaluationPicker({
    required this.entry,
    required this.history,
    required this.labels,
  });

  final HistoryEntry entry;
  final HistoryStore history;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListenableBuilder(
      listenable: history,
      builder: (context, _) {
        final correct = entry.isCorrect;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Evaluation', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'What is really in this picture? Your answer goes into the '
              'evaluation table on the History screen.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final label in labels)
                  ChoiceChip(
                    label: Text(label),
                    selected: entry.expected == label,
                    onSelected: (on) =>
                        history.setExpected(entry, on ? label : null),
                  ),
              ],
            ),
            if (correct != null) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Icon(
                    correct
                        ? Icons.check_circle_outline
                        : Icons.cancel_outlined,
                    color: correct ? scheme.primary : scheme.error,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      correct
                          ? 'Correct'
                          : 'Wrong: the model said ${entry.top.label}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: correct ? scheme.primary : scheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
