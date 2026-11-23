// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/classifier.dart';
import '../theme/app_theme.dart';
import '../widgets/status_view.dart';

/// Screen 5. Labels, number of classes, input size, model file name,
/// a robustness check (T12) and the design credit (T14).
///
/// The labels are read from the shared [Classifier], not from the file again:
/// one source of truth, so the screen can never show labels that differ from
/// the ones the model is actually paired with.
class ModelScreen extends StatefulWidget {
  const ModelScreen({super.key, required this.classifier});

  final Classifier classifier;

  @override
  State<ModelScreen> createState() => _ModelScreenState();
}

class _ModelScreenState extends State<ModelScreen> {
  String? _checkResult;
  bool _checkFailedPolitely = false;

  /// T12: feed classify() the bytes of a text file (labels.txt itself).
  Future<void> _classifyTextFile() async {
    final data = await rootBundle.load(Classifier.defaultLabelsPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    String result;
    bool polite;
    try {
      final p = widget.classifier.classify(bytes);
      result = 'Unexpected: classified as ${p.first.label}';
      polite = false;
    } on FormatException catch (e) {
      result = e.message;
      polite = true;
    }
    if (!mounted) return;
    setState(() {
      _checkResult = result;
      _checkFailedPolitely = polite;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.classifier;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Model')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          _Section(
            title: 'TensorFlow Lite model',
            children: [
              _InfoRow(label: 'File', value: c.modelFileName),
              _InfoRow(label: 'Classes', value: '${c.labels.length}'),
              const _InfoRow(
                label: 'Input size',
                value:
                    '${Classifier.inputSize} × ${Classifier.inputSize} px, RGB',
              ),
              _InfoRow(
                label: 'Input tensor',
                value: '${c.inputShape}  ${c.inputType}',
              ),
              _InfoRow(label: 'Output tensor', value: '${c.outputShape}'),
              const _InfoRow(label: 'Runs', value: 'On device, offline'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _Section(
            title: 'Labels (from labels.txt)',
            children: [
              for (var i = 0; i < c.labels.length; i++)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: scheme.secondaryContainer,
                    child: Text(
                      '$i',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  title: Text(c.labels[i]),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _Section(
            title: 'Robustness check',
            children: [
              Text(
                'Sends the bytes of a text file (labels.txt) to the '
                'classifier. It must end in a readable message, not a crash.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: _classifyTextFile,
                icon: const Icon(Icons.bug_report_outlined),
                label: const Text('Classify a text file'),
              ),
              if (_checkResult != null) ...[
                const SizedBox(height: AppSpacing.md),
                if (_checkFailedPolitely)
                  ErrorBanner(message: 'Handled: $_checkResult')
                else
                  Text(_checkResult!),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const _Section(
            title: 'Design credit',
            children: [
              _InfoRow(label: 'Design', value: DesignCredit.name),
              _InfoRow(label: 'Author', value: DesignCredit.author),
              _InfoRow(label: 'Licence', value: DesignCredit.licence),
              _InfoRow(
                label: 'Link',
                value: DesignCredit.link,
                selectable: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.selectable = false,
  });

  final String label;
  final String value;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueStyle = theme.textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: selectable
                ? SelectableText(value, style: valueStyle)
                : Text(value, style: valueStyle),
          ),
        ],
      ),
    );
  }
}
