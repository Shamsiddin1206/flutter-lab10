// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/history.dart';
import '../theme/app_theme.dart';
import '../widgets/source_badge.dart';
import '../widgets/status_view.dart';
import 'result_screen.dart';

/// Screen 4. Every classification of this session, newest first.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.history, required this.labels});

  final HistoryStore history;
  final List<String> labels;

  Future<void> _copyTable(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final rows = history.evaluated.length;
    await Clipboard.setData(
      ClipboardData(text: history.evaluationMarkdown(labels)),
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Evaluation table with $rows attempts copied. '
          'Paste it into NOTES.md.',
        ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: const Text('Clear history?'),
        content: const Text(
          'This removes every result of this session, including your '
          'evaluation answers.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok ?? false) history.clear();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: history,
      builder: (context, _) {
        final entries = history.entries;
        return Scaffold(
          appBar: AppBar(
            title: const Text('History'),
            actions: [
              IconButton(
                tooltip: 'Copy evaluation table',
                onPressed: history.evaluated.isEmpty
                    ? null
                    : () => _copyTable(context),
                icon: const Icon(Icons.table_chart_outlined),
              ),
              IconButton(
                tooltip: 'Clear history',
                onPressed: entries.isEmpty
                    ? null
                    : () => _confirmClear(context),
                icon: const Icon(Icons.delete_sweep_outlined),
              ),
            ],
          ),
          body: entries.isEmpty
              ? const StatusView(
                  icon: Icons.history_toggle_off,
                  title: 'Nothing classified yet',
                  message:
                      'Take a photo, choose one from the gallery or '
                      'download one on the Home screen. Every result lands '
                      'here, newest first.',
                )
              : Column(
                  children: [
                    _EvaluationSummary(history: history),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                        itemCount: entries.length,
                        separatorBuilder: (_, _) => const Divider(indent: 88),
                        itemBuilder: (context, i) => _HistoryTile(
                          entry: entries[i],
                          onTap: () => Navigator.of(context).push(
                            ResultScreen.route(
                              entry: entries[i],
                              history: history,
                              labels: labels,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry, required this.onTap});

  final HistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = entry.time;
    final time =
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}';
    final correct = entry.isCorrect;

    return ListTile(
      onTap: onTap,
      minVerticalPadding: AppSpacing.md,
      leading: Thumbnail(bytes: entry.bytes),
      title: Text(
        entry.top.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${entry.top.percent}  ·  ${entry.source.label}  ·  $time',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (correct != null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Icon(
                correct ? Icons.check_circle : Icons.cancel,
                size: 20,
                color: correct ? scheme.primary : scheme.error,
              ),
            ),
          Tooltip(message: entry.source.label, child: Icon(entry.source.icon)),
        ],
      ),
    );
  }
}

class _EvaluationSummary extends StatelessWidget {
  const _EvaluationSummary({required this.history});

  final HistoryStore history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = history.evaluated;
    final correct = rows.where((e) => e.isCorrect!).length;
    final text = rows.isEmpty
        ? 'Tip: open a result and tap what it really shows to build the '
              'evaluation table.'
        : 'Evaluated ${rows.length} · correct $correct · accuracy '
              '${(correct / rows.length * 100).toStringAsFixed(1)} %';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
