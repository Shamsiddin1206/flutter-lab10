// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../services/classifier.dart';
import '../theme/app_theme.dart';
import '../widgets/status_view.dart';

/// Screen 1. App name, what it recognises, the classes, Get started.
/// Doubles as the loading screen while the model loads, and as the start-up
/// error screen when it cannot be loaded (T12).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    required this.classifier,
    required this.error,
    required this.onGetStarted,
  });

  /// `null` while loading or after an error.
  final Classifier? classifier;
  final ModelLoadException? error;
  final VoidCallback onGetStarted;

  static const appName = 'TM Classifier';

  @override
  Widget build(BuildContext context) {
    final err = error;
    if (err != null) {
      return Scaffold(
        body: SafeArea(
          child: StatusView(
            icon: Icons.report_gmailerrorred_outlined,
            tone: StatusTone.error,
            title: 'The model could not be loaded',
            message: err.message,
            details:
                'Expected at: ${err.expectedPath}'
                '${err.cause == null ? '' : '\n\nDetails: ${err.cause}'}',
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ready = classifier != null;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - AppSpacing.xl * 2).clamp(
                  0.0,
                  double.infinity,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.xxl),
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(AppRadii.large),
                        ),
                        child: Icon(
                          Icons.center_focus_strong_outlined,
                          size: 40,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(appName, style: theme.textTheme.displaySmall),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Show the camera one of the objects below and the app '
                        'tells you which one it sees, with a percentage for '
                        'every class. Everything runs on the phone, offline.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        ready
                            ? 'It recognises ${classifier!.labels.length} classes'
                            : 'Loading the model…',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (ready)
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            for (final label in classifier!.labels)
                              Chip(
                                avatar: Icon(
                                  Icons.label_outline,
                                  size: 18,
                                  color: scheme.primary,
                                ),
                                label: Text(label),
                              ),
                          ],
                        )
                      else
                        const LinearProgressIndicator(),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: ready ? onGetStarted : null,
                      icon: ready
                          ? const Icon(Icons.arrow_forward)
                          : const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                      label: Text(ready ? 'Get started' : 'Loading model…'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
